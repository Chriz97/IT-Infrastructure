#Requires -Version 5.1
<#
.SYNOPSIS
    Cleans old, dangling, damaged, and duplicate managed saved objects in Kibana.
    Retains only the last N config backups stored as saved objects.
    Supports targeting a single space, multiple spaces, or all spaces.

.DESCRIPTION
    Connects to the Kibana Saved Objects API to:
      - Delete damaged saved objects (API-reported error block)
      - Delete dangling saved objects (broken references to missing objects)
      - Delete duplicate dashboards per space (keep newest by updated_at)
      - Retain only the last N config backup saved objects per type per space
      - Scope: managed objects only
      - Supports per-space processing via -Spaces parameter

.PARAMETER KibanaUrl
    Base URL of your Kibana instance. Defaults to $env:KIBANA_URL or https://kibana.mayer-it.net

.PARAMETER Username
    Kibana/Elasticsearch username. Defaults to $env:KIBANA_USER or "elastic"

.PARAMETER Password
    Kibana/Elasticsearch password. Defaults to $env:KIBANA_PASS

.PARAMETER ApiKey
    Elasticsearch API key (base64 encoded id:key). Takes priority over Username/Password.

.PARAMETER Spaces
    One or more Kibana space IDs to process. Use "default" for the default space.
    Use the special value "all" to auto-discover and process every space.
    Examples:
      -Spaces "default"
      -Spaces "default","monitoring","security"
      -Spaces "all"
    Default: "default"

.PARAMETER DryRun
    If set, no deletions are performed. All candidates are logged only.

.PARAMETER ConfigBackupsToKeep
    Number of most recent config backup saved objects to retain per type per space. Default: 4

.PARAMETER BatchSize
    Number of saved objects to retrieve per API page. Default: 1000

.PARAMETER LogFile
    Path to a log file. Defaults to ./clean_saved_objects_<timestamp>.log

.PARAMETER SkipTlsVerification
    Skip TLS certificate validation (useful for self-signed certs on internal setups).

.EXAMPLE
    # Dry run — default space only
    .\clean_saved_objects.ps1 -DryRun -SkipTlsVerification

.EXAMPLE
    # Clean a specific space
    .\clean_saved_objects.ps1 -Spaces "monitoring" -SkipTlsVerification

.EXAMPLE
    # Clean multiple specific spaces
    .\clean_saved_objects.ps1 -Spaces "default","monitoring","security" -SkipTlsVerification

.EXAMPLE
    # Clean ALL spaces (auto-discovered)
    .\clean_saved_objects.ps1 -Spaces "all" -DryRun -SkipTlsVerification

.EXAMPLE
    # Live run with API key, keep last 6 config backups
    .\clean_saved_objects.ps1 -ApiKey "base64key==" -Spaces "all" -ConfigBackupsToKeep 6

.NOTES
    Author  : Christoph Mayer / chriz
    Version : 2.0.0
    Requires: PowerShell 5.1+ or PowerShell 7+
    API Ref : https://www.elastic.co/guide/en/kibana/current/saved-objects-api.html
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]   $KibanaUrl           = ($env:KIBANA_URL  ?? "https://kibana.mayer-it.net"),
    [string]   $Username            = ($env:KIBANA_USER ?? "elastic"),
    [string]   $Password            = $env:KIBANA_PASS,
    [string]   $ApiKey              = $env:KIBANA_API_KEY,
    [string[]] $Spaces              = @("default"),
    [switch]   $DryRun,
    [int]      $ConfigBackupsToKeep = 4,
    [int]      $BatchSize           = 1000,
    [string]   $LogFile             = ".\clean_saved_objects_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [switch]   $SkipTlsVerification
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────
#  Counters
# ─────────────────────────────────────────────
$script:Stats = @{
    TotalFetched     = 0
    ManagedFound     = 0
    DamagedFound     = 0
    DanglingFound    = 0
    DuplicatesFound  = 0
    BackupsPruned    = 0
    Deleted          = 0
    Errors           = 0
    SpacesProcessed  = 0
}

# ─────────────────────────────────────────────
#  Logging
# ─────────────────────────────────────────────
function Write-Log {
    param(
        [string] $Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS","DRY")] [string] $Level = "INFO"
    )
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "Cyan"    }
        "WARN"    { "Yellow"  }
        "ERROR"   { "Red"     }
        "SUCCESS" { "Green"   }
        "DRY"     { "Magenta" }
    }
    $line = "[$ts][$Level] $Message"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# ─────────────────────────────────────────────
#  TLS bypass helper (PS5 / PS7 compatible)
# ─────────────────────────────────────────────
function Set-TlsBypass {
    if ($PSVersionTable.PSVersion.Major -ge 6) { return }
    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
        Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint svcPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) { return true; }
}
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::SecurityProtocol  =
        [System.Net.SecurityProtocolType]::Tls12 -bor
        [System.Net.SecurityProtocolType]::Tls13
}

# ─────────────────────────────────────────────
#  Build common Invoke-RestMethod parameters
# ─────────────────────────────────────────────
function Get-BaseIrmParams {
    $headers = @{
        "kbn-xsrf"     = "true"
        "Content-Type" = "application/json"
    }
    if ($script:ApiKey) {
        $headers["Authorization"] = "ApiKey $script:ApiKey"
    } elseif ($script:Username -and $script:Password) {
        $cred = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes("${script:Username}:${script:Password}"))
        $headers["Authorization"] = "Basic $cred"
    }
    $params = @{ Headers = $headers; ContentType = "application/json" }
    if ($SkipTlsVerification -and $PSVersionTable.PSVersion.Major -ge 6) {
        $params["SkipCertificateCheck"] = $true
    }
    return $params
}

# ─────────────────────────────────────────────
#  Invoke Kibana API (with retry, space-aware)
#  SpaceId = "default"  -> /api/...
#  SpaceId = "myspace"  -> /s/myspace/api/...
# ─────────────────────────────────────────────
function Invoke-KibanaApi {
    param(
        [string] $Method,
        [string] $Path,
        [string] $SpaceId    = "default",
        [object] $Body       = $null,
        [int]    $MaxRetries = 3
    )
    $spacePrefix = if ($SpaceId -eq "default") { "" } else { "/s/$SpaceId" }
    $uri         = "$script:KibanaUrl$spacePrefix$Path"

    $irmArgs = Get-BaseIrmParams
    $irmArgs["Uri"]    = $uri
    $irmArgs["Method"] = $Method
    if ($Body) {
        $irmArgs["Body"] = ($Body | ConvertTo-Json -Depth 20 -Compress)
    }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            return Invoke-RestMethod @irmArgs
        } catch {
            $httpStatus = $null
            try { $httpStatus = $_.Exception.Response.StatusCode.value__ } catch {}
            Write-Log "API call failed [$Method $uri] attempt $attempt/$MaxRetries — HTTP $httpStatus : $($_.Exception.Message)" -Level WARN
            if ($attempt -eq $MaxRetries) { throw }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

# ─────────────────────────────────────────────
#  Discover all Kibana spaces
# ─────────────────────────────────────────────
function Get-AllSpaces {
    $result = Invoke-KibanaApi -Method GET -Path "/api/spaces/space" -SpaceId "default"
    return $result | Select-Object -ExpandProperty id
}

# ─────────────────────────────────────────────
#  Fetch ALL saved objects of given types in one space (paged)
# ─────────────────────────────────────────────
function Get-AllSavedObjects {
    param(
        [string[]] $Types,
        [string]   $SpaceId = "default"
    )

    $all = [System.Collections.Generic.List[object]]::new()

    foreach ($type in $Types) {
        $page = 1
        do {
            $result  = Invoke-KibanaApi -Method GET -SpaceId $SpaceId `
                -Path "/api/saved_objects/_find?type=$type&per_page=$BatchSize&page=$page"
            $fetched = $result.saved_objects
            if ($fetched) {
                foreach ($obj in $fetched) {
                    # Tag each object with its source space for space-aware deletion
                    $obj | Add-Member -NotePropertyName "_spaceId" -NotePropertyValue $SpaceId -Force
                }
                $all.AddRange($fetched)
            }
            $page++
        } while ($result.total -gt ($page - 1) * $BatchSize)
    }
    return $all.ToArray()
}

# ─────────────────────────────────────────────
#  Is this saved object "managed"?
# ─────────────────────────────────────────────
function Test-IsManaged {
    param([object] $So)

    if ($So.PSObject.Properties["managed"] -and $So.managed -eq $true) {
        return $true
    }
    $attrs = if ($So.PSObject.Properties["attributes"]) { $So.attributes } else { $null }
    if ($null -ne $attrs -and
        $attrs.PSObject.Properties["managed"] -and
        $attrs.managed -eq $true) {
        return $true
    }
    if ($So.type -in @("fleet-agent-policy","fleet-package-policy",
                       "ingest_manager_settings","fleet-settings")) {
        return $true
    }
    if ($So.type -eq "config" -and
        $null -ne $attrs -and
        $attrs.PSObject.Properties["buildNum"]) {
        return $true
    }
    return $false
}

# ─────────────────────────────────────────────
#  Is this saved object damaged / corrupt?
# ─────────────────────────────────────────────
function Test-IsDamaged {
    param([object] $So)

    if ($So.PSObject.Properties["error"] -and $null -ne $So.error) {
        return $true
    }
    $attrs = if ($So.PSObject.Properties["attributes"]) { $So.attributes } else { $null }
    if ($null -ne $attrs -and
        $attrs.PSObject.Properties["corrupted"] -and
        $attrs.corrupted -eq $true) {
        return $true
    }
    return $false
}

# ─────────────────────────────────────────────
#  Does this saved object have dangling references?
# ─────────────────────────────────────────────
function Test-IsDangling {
    param(
        [object]   $So,
        [hashtable]$AllById
    )
    if (-not $So.PSObject.Properties["references"] -or $So.references.Count -eq 0) {
        return $false
    }
    foreach ($ref in $So.references) {
        $key = "$($ref.type)::$($ref.id)"
        if (-not $AllById.ContainsKey($key)) {
            return $true
        }
    }
    return $false
}

# ─────────────────────────────────────────────
#  Delete a single saved object (space-aware)
# ─────────────────────────────────────────────
function Remove-SavedObject {
    param(
        [string] $Type,
        [string] $Id,
        [string] $SpaceId,
        [string] $Reason
    )
    $spaceTag = if ($SpaceId -eq "default") { "" } else { " (space: $SpaceId)" }
    $label    = "[$Type/$Id]$spaceTag"

    if ($DryRun) {
        Write-Log "DRY-RUN  Would delete $label  Reason: $Reason" -Level DRY
        $script:Stats.Deleted++
        return
    }

    try {
        Invoke-KibanaApi -Method DELETE -Path "/api/saved_objects/$Type/$Id" -SpaceId $SpaceId
        Write-Log "DELETED  $label  Reason: $Reason" -Level SUCCESS
        $script:Stats.Deleted++
    } catch {
        Write-Log "FAILED to delete $label : $($_.Exception.Message)" -Level ERROR
        $script:Stats.Errors++
    }
}

# ─────────────────────────────────────────────
#  Process a single space — returns deletion list
# ─────────────────────────────────────────────
function Invoke-SpaceCleanup {
    param(
        [string]   $SpaceId,
        [string[]] $TargetTypes
    )

    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level INFO
    Write-Log " Processing space: [$SpaceId]" -Level INFO
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level INFO

    # Fetch all objects in this space
    $allObjects = Get-AllSavedObjects -Types $TargetTypes -SpaceId $SpaceId
    $script:Stats.TotalFetched += $allObjects.Count
    Write-Log "  Fetched $($allObjects.Count) saved objects" -Level INFO

    # Build lookup map for dangling reference checks
    $allById = @{}
    foreach ($obj in $allObjects) {
        $allById["$($obj.type)::$($obj.id)"] = $obj
    }

    # Filter to managed objects only
    $managedObjects = $allObjects | Where-Object { Test-IsManaged $_ }
    $script:Stats.ManagedFound += $managedObjects.Count
    Write-Log "  Managed objects: $($managedObjects.Count)" -Level INFO

    $toDelete = [System.Collections.Generic.List[hashtable]]::new()

    # ── Damaged & Dangling ─────────────────────
    foreach ($obj in $managedObjects) {
        if (Test-IsDamaged $obj) {
            $script:Stats.DamagedFound++
            $toDelete.Add(@{ Type = $obj.type; Id = $obj.id; SpaceId = $SpaceId; Reason = "damaged/corrupt" })
            Write-Log "  DAMAGED  [$($obj.type)/$($obj.id)] updated_at=$($obj.updated_at)" -Level WARN
            continue
        }
        if (Test-IsDangling -So $obj -AllById $allById) {
            $script:Stats.DanglingFound++
            $toDelete.Add(@{ Type = $obj.type; Id = $obj.id; SpaceId = $SpaceId; Reason = "dangling reference" })
            Write-Log "  DANGLING [$($obj.type)/$($obj.id)] updated_at=$($obj.updated_at)" -Level WARN
            continue
        }
    }

    # ── Duplicate dashboards ───────────────────
    # When an integration policy is updated, Kibana reinstalls its dashboards,
    # leaving stale copies with the same title. Keep the newest per title.
    Write-Log "  Checking for duplicate dashboards…" -Level INFO
    $dashboards = $managedObjects | Where-Object { $_.type -eq "dashboard" }

    if ($dashboards) {
        $titleGroups = @($dashboards | Group-Object -Property {
            $attrs = if ($_.PSObject.Properties["attributes"] -and $null -ne $_.attributes) { $_.attributes } else { $null }
            $title = if ($null -ne $attrs -and $attrs.PSObject.Properties["title"]) { $attrs.title } else { $_.id }
            $title.Trim().ToLower()
        })

        foreach ($group in $titleGroups) {
            if ($group.Count -le 1) { continue }

            $sorted = @($group.Group | Sort-Object -Property updated_at -Descending)
            $keep   = $sorted[0]
            $dupes  = $sorted | Select-Object -Skip 1

            $keepAttrs    = if ($keep.PSObject.Properties["attributes"] -and $null -ne $keep.attributes) { $keep.attributes } else { $null }
            $displayTitle = if ($null -ne $keepAttrs -and $keepAttrs.PSObject.Properties["title"]) { $keepAttrs.title } else { $keep.id }

            Write-Log "  DUPLICATE '$displayTitle' — $($group.Count) copies, keeping newest [$($keep.id)] updated=$($keep.updated_at)" -Level WARN

            foreach ($dupe in $dupes) {
                $alreadyQueued = $toDelete | Where-Object { $_.Id -eq $dupe.id -and $_.Type -eq $dupe.type }
                if ($alreadyQueued) { continue }
                $script:Stats.DuplicatesFound++
                $toDelete.Add(@{
                    Type    = $dupe.type
                    Id      = $dupe.id
                    SpaceId = $SpaceId
                    Reason  = "duplicate dashboard (older copy; title='$displayTitle')"
                })
                Write-Log "    DUPE  [dashboard/$($dupe.id)] updated_at=$($dupe.updated_at)" -Level WARN
            }
        }
    }

    # ── Config backup pruning ──────────────────
    Write-Log "  Pruning config backups (keeping last $ConfigBackupsToKeep per type)…" -Level INFO
    $configObjects = $managedObjects | Where-Object { $_.type -in @("config","config-global") }

    if ($configObjects) {
        $groups = @($configObjects | Group-Object -Property type)
        foreach ($group in $groups) {
            $sorted = @($group.Group | Sort-Object -Property updated_at -Descending)
            $prune  = @($sorted | Select-Object -Skip $ConfigBackupsToKeep)
            $keepN  = [Math]::Min($ConfigBackupsToKeep, $sorted.Count)

            Write-Log "  Config [$($group.Name)]: $($sorted.Count) entries — keeping $keepN, pruning $($prune.Count)" -Level INFO

            foreach ($obj in $prune) {
                $alreadyQueued = $toDelete | Where-Object { $_.Id -eq $obj.id -and $_.Type -eq $obj.type }
                if ($alreadyQueued) { continue }
                $script:Stats.BackupsPruned++
                $toDelete.Add(@{
                    Type    = $obj.type
                    Id      = $obj.id
                    SpaceId = $SpaceId
                    Reason  = "old config backup (outside last $ConfigBackupsToKeep)"
                })
                Write-Log "  PRUNE CONFIG [$($obj.type)/$($obj.id)] updated_at=$($obj.updated_at)" -Level WARN
            }
        }
    }

    Write-Log "  Space [$SpaceId] — queued $($toDelete.Count) object(s) for deletion" -Level INFO
    return $toDelete
}

# ══════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════

$mode = if ($DryRun) { " [DRY-RUN — no changes will be made]" } else { "" }
Write-Log "═══════════════════════════════════════════════════════════" -Level INFO
Write-Log " clean_saved_objects.ps1  v2.0.0$mode"                      -Level INFO
Write-Log " Target  : $KibanaUrl"                                       -Level INFO
Write-Log " Spaces  : $($Spaces -join ', ')"                           -Level INFO
Write-Log " Log     : $LogFile"                                         -Level INFO
Write-Log "═══════════════════════════════════════════════════════════" -Level INFO

$script:KibanaUrl = $KibanaUrl.TrimEnd("/")
$script:Username  = $Username
$script:Password  = $Password
$script:ApiKey    = $ApiKey

if ($SkipTlsVerification) { Set-TlsBypass }

# ── Step 1: Connectivity check ───────────────
Write-Log "Checking Kibana connectivity…" -Level INFO
try {
    $status = Invoke-KibanaApi -Method GET -Path "/api/status"
    Write-Log "Connected — Kibana $($status.version.number) (build $($status.version.build_number))" -Level SUCCESS
} catch {
    Write-Log "Cannot reach Kibana at $KibanaUrl : $($_.Exception.Message)" -Level ERROR
    exit 1
}

# ── Step 2: Resolve spaces ────────────────────
$resolvedSpaces = [System.Collections.Generic.List[string]]::new()

if ($Spaces -contains "all") {
    Write-Log "Discovering all Kibana spaces…" -Level INFO
    try {
        $discovered = Get-AllSpaces
        $resolvedSpaces.AddRange([string[]]$discovered)
        Write-Log "Discovered $($resolvedSpaces.Count) space(s): $($resolvedSpaces -join ', ')" -Level SUCCESS
    } catch {
        Write-Log "Failed to list spaces: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
} else {
    $resolvedSpaces.AddRange([string[]]$Spaces)
    Write-Log "Targeting $($resolvedSpaces.Count) space(s): $($resolvedSpaces -join ', ')" -Level INFO
}

# ── Step 3: Saved object types to process ────
$targetTypes = @(
    "config",
    "config-global",
    "dashboard",
    "visualization",
    "lens",
    "map",
    "search",
    "index-pattern",
    "data-view",
    "url",
    "query",
    "tag",
    "fleet-agent-policy",
    "fleet-package-policy",
    "fleet-settings",
    "ingest_manager_settings",
    "osquery-saved-query",
    "osquery-pack"
)

# ── Step 4: Process each space ────────────────
$allToDelete = [System.Collections.Generic.List[hashtable]]::new()

foreach ($spaceId in $resolvedSpaces) {
    try {
        $spaceResults = Invoke-SpaceCleanup -SpaceId $spaceId -TargetTypes $targetTypes
        if ($spaceResults) { $allToDelete.AddRange($spaceResults) }
    } catch {
        Write-Log "ERROR processing space [$spaceId]: $($_.Exception.Message)" -Level ERROR
        $script:Stats.Errors++
    } finally {
        $script:Stats.SpacesProcessed++
    }
}

# ── Step 5: Global summary ────────────────────
Write-Log "═══════════════════════════════════════════════════════════" -Level INFO
Write-Log " Summary across $($script:Stats.SpacesProcessed) space(s):"  -Level INFO
Write-Log "   Total fetched        : $($script:Stats.TotalFetched)"      -Level INFO
Write-Log "   Managed found        : $($script:Stats.ManagedFound)"      -Level INFO
Write-Log "   Damaged              : $($script:Stats.DamagedFound)"      -Level INFO
Write-Log "   Dangling             : $($script:Stats.DanglingFound)"     -Level INFO
Write-Log "   Duplicate dashboards : $($script:Stats.DuplicatesFound)"   -Level INFO
Write-Log "   Config backups       : $($script:Stats.BackupsPruned) to prune" -Level INFO
Write-Log "   Total to delete      : $($allToDelete.Count)"              -Level INFO
Write-Log "═══════════════════════════════════════════════════════════" -Level INFO

if ($allToDelete.Count -eq 0) {
    Write-Log "Nothing to clean up. Exiting." -Level SUCCESS
    exit 0
}

if (-not $DryRun) {
    $confirm = Read-Host "Proceed with deleting $($allToDelete.Count) saved objects? [y/N]"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Log "Aborted by user." -Level WARN
        exit 0
    }
}

# ── Step 6: Delete ────────────────────────────
Write-Log "Starting deletion…" -Level INFO

foreach ($item in $allToDelete) {
    Remove-SavedObject -Type $item.Type -Id $item.Id -SpaceId $item.SpaceId -Reason $item.Reason
}

# ── Step 7: Final report ──────────────────────
Write-Log "═══════════════════════════════════════════════════════════" -Level INFO
Write-Log " Final Report$mode"                                           -Level INFO
Write-Log "   Deleted              : $($script:Stats.Deleted)"          -Level INFO
Write-Log "   Errors               : $($script:Stats.Errors)"           -Level INFO
Write-Log "   Log written to       : $LogFile"                          -Level INFO
Write-Log "═══════════════════════════════════════════════════════════" -Level INFO

if ($script:Stats.Errors -gt 0) {
    Write-Log "Completed with $($script:Stats.Errors) error(s). Review the log above." -Level WARN
    exit 1
} else {
    Write-Log "Completed successfully." -Level SUCCESS
    exit 0
}
