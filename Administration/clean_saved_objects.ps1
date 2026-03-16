#Requires -Version 5.1
<#
.SYNOPSIS
    Kibana Saved Objects Cleanup — kibana.mayer-it.net

.DESCRIPTION
    Fetches saved objects via POST /api/saved_objects/_export (NDJSON) and:

    STEP 1 — Duplicate Removal
        Finds same type+title appearing more than once.
        Keeps the *managed* copy (integration/fleet-installed).
        If NO managed copy exists -> all copies are user-created -> skipped.

    STEP 2 — Config (Advanced Settings) Pruning
        Keeps the $KeepConfigCount newest 'config' objects (created during upgrades).

    STEP 3 — Dangling Reference Detection
        Finds objects whose references point to IDs that no longer exist.
        Managed objects and dashboards are protected unless explicitly enabled.

    Run with $DryRun = $true (default) to preview. Set $false to apply.
#>

# ══════════════════════════════════════════════════════════════════
#  CONFIGURATION  <- edit here
# ══════════════════════════════════════════════════════════════════

$KibanaUrl   = "https://...."
$Username    = "elastic"
$Password    = ""

$DryRun                   = $true   # <- $false to apply changes
$KeepConfigCount          = 4       # keep newest N config objects per space
$DeleteDanglingDashboards = $false  # set $true to also delete dashboards with broken refs

# Titles to never delete, regardless of type or duplicate status.
# Supports wildcards, e.g. "metrics-*", "Nginx *"
$ExcludeTitles = @(
    "metrics-*"
)

# Space filtering:
#   ""       -> default space  (no /s/{id} prefix)
#   "myid"   -> that specific space only
#   "*"      -> ALL spaces (enumerates via /api/spaces/space and loops each)
$Space = ""

# ══════════════════════════════════════════════════════════════════
#  INTERNALS — do not edit below
# ══════════════════════════════════════════════════════════════════

$ExportTypes = @(
    "dashboard"
    "visualization"
    "lens"
    "map"
    "search"
    "index-pattern"
    "config"
    "tag"
)

$DuplicateCheckTypes = @(
    "dashboard"
    "visualization"
    "lens"
    "map"
    "search"
    "index-pattern"
)

# ── Auth headers ──────────────────────────────────────────────────
$EncodedCred = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes("${Username}:${Password}")
)
$BaseHeaders = @{
    "Authorization" = "Basic $EncodedCred"
    "kbn-xsrf"      = "true"
    "Content-Type"  = "application/json"
}

# ── Counters ──────────────────────────────────────────────────────
$script:TotalSkipped = 0

# ── Logging ───────────────────────────────────────────────────────
function Write-Log {
    param(
        [ValidateSet("INFO","SKIP","ACTION","WARN","ERROR","OK")]
        [string]$Level,
        [string]$Message
    )
    $dryTag = if ($DryRun) { " [DRY]" } else { "" }
    $color  = switch ($Level) {
        "INFO"   { "Cyan"       }
        "SKIP"   { "DarkGray"   }
        "ACTION" { "Yellow"     }
        "WARN"   { "DarkYellow" }
        "OK"     { "Green"      }
        "ERROR"  { "Red"        }
    }
    $stamp = Get-Date -Format "HH:mm:ss"
    Write-Host "  $stamp$dryTag [$Level] $Message" -ForegroundColor $color
}

function Write-Section ([string]$Title) {
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "   $Title"                                        -ForegroundColor White
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor DarkCyan
}

# ── Exclusion check ───────────────────────────────────────────────
function Test-Excluded ([string]$Title) {
    foreach ($pattern in $ExcludeTitles) {
        if ($Title -like $pattern) { return $true }
    }
    return $false
}

# ── Build the base API URL for a given space ID ───────────────────
function Get-ApiBase ([string]$SpaceId) {
    if ($SpaceId -eq "" -or $SpaceId -eq "default") {
        return "$KibanaUrl/api"
    }
    return "$KibanaUrl/s/$SpaceId/api"
}

# ── List all space IDs via /api/spaces/space ──────────────────────
function Get-AllSpaceIds {
    try {
        $result = Invoke-RestMethod `
            -Method      GET `
            -Uri         "$KibanaUrl/api/spaces/space" `
            -Headers     $BaseHeaders `
            -ErrorAction Stop
        return @($result | ForEach-Object { $_.id })
    } catch {
        Write-Log ERROR "Could not enumerate spaces: $_"
        return @("")   # fall back to default space
    }
}

# ── NDJSON parser ─────────────────────────────────────────────────
# Kibana's export API emits pretty-printed JSON (multiple lines per object).
# Splitting naively on \n produces broken fragments — only the first object's
# id would be seen, hence the "1 unique ID" bug.
# Fix: track brace depth; accumulate lines until depth returns to zero.
function ConvertFrom-NdJson ([string]$Content) {
    $objects = [System.Collections.Generic.List[object]]::new()
    $buffer  = [System.Text.StringBuilder]::new()
    $depth   = 0
    $inStr   = $false
    $escape  = $false

    foreach ($line in ($Content -split "`n")) {
        $trimmed = $line.TrimEnd("`r")   # strip CR for Windows-style line endings
        if ($trimmed.Trim() -eq "") { continue }

        # Count brace depth, skipping chars inside string literals
        foreach ($ch in $trimmed.ToCharArray()) {
            if ($escape)         { $escape = $false; continue }
            if ($ch -eq '\')     { $escape = $true;  continue }
            if ($ch -eq '"')     { $inStr  = -not $inStr; continue }
            if ($inStr)          { continue }
            if ($ch -eq '{')     { $depth++ }
            elseif ($ch -eq '}') { $depth-- }
        }

        [void]$buffer.AppendLine($trimmed)

        if ($depth -eq 0 -and $buffer.Length -gt 2) {
            $json = $buffer.ToString().Trim()
            try {
                $obj = $json | ConvertFrom-Json -ErrorAction Stop
                $objects.Add($obj)
            } catch {
                Write-Log WARN "Skipped unparseable object: $($json.Substring(0, [Math]::Min(80,$json.Length)))..."
            }
            [void]$buffer.Clear()
        }
    }

    return $objects.ToArray()
}

# ── Export objects for one space ──────────────────────────────────
function Get-ExportedObjects ([string]$SpaceId) {
    $label   = if ($SpaceId -eq "") { "default" } else { $SpaceId }
    $apiBase = Get-ApiBase $SpaceId

    Write-Log INFO "Exporting from space: '$label' ..."

    $body = @{
        type                  = $ExportTypes
        excludeExportDetails  = $true
        includeReferencesDeep = $false
    } | ConvertTo-Json -Compress

    try {
        # Use HttpClient directly — Invoke-WebRequest's .Content and .RawContentBytes
        # are both unreliable for application/x-ndjson on Linux (unknown content-type
        # causes the body to be null or a decimal byte string).
        $handler  = [System.Net.Http.HttpClientHandler]::new()
        $client   = [System.Net.Http.HttpClient]::new($handler)

        $request  = [System.Net.Http.HttpRequestMessage]::new(
                        [System.Net.Http.HttpMethod]::Post,
                        "$apiBase/saved_objects/_export")

        foreach ($kv in $BaseHeaders.GetEnumerator()) {
            if ($kv.Key -eq "Content-Type") { continue }   # set on content below
            $request.Headers.TryAddWithoutValidation($kv.Key, $kv.Value) | Out-Null
        }

        $request.Content = [System.Net.Http.StringContent]::new(
                                $body,
                                [System.Text.Encoding]::UTF8,
                                "application/json")

        $httpResponse = $client.SendAsync($request).GetAwaiter().GetResult()
        $rawText      = $httpResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $client.Dispose()

        if (-not $httpResponse.IsSuccessStatusCode) {
            Write-Log ERROR "Export failed for space '$label' (HTTP $([int]$httpResponse.StatusCode)): $rawText"
            return @()
        }

        $objects = ConvertFrom-NdJson -Content $rawText

        # Tag each object with its space for scoped grouping and deletes
        foreach ($obj in $objects) {
            $obj | Add-Member -NotePropertyName "_spaceId" -NotePropertyValue $label -Force
        }

        Write-Log INFO "  -> $($objects.Count) object(s) from space '$label'"
        return $objects

    } catch {
        $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "unknown" }
        return @()
    }
}

# ── Delete one saved object ───────────────────────────────────────
function Remove-KibanaObject {
    param([string]$Type, [string]$Id, [string]$Label, [string]$SpaceId)

    Write-Log ACTION "DELETE [$Type] $Label  (id: $Id, space: $SpaceId)"

    if (-not $DryRun) {
        $apiBase = Get-ApiBase $SpaceId
        try {
            Invoke-RestMethod `
                -Method      DELETE `
                -Uri         "$apiBase/saved_objects/$Type/$Id" `
                -Headers     $BaseHeaders `
                -ErrorAction Stop | Out-Null
            Write-Log OK "    Removed"
        } catch {
            $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "unknown" }
            Write-Log ERROR "    Failed (HTTP $status): $_"
        }
    }
}

# ══════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   Kibana Saved Objects Cleanup               ║" -ForegroundColor Cyan
Write-Host "  ║   $KibanaUrl"                                   -ForegroundColor Cyan
$spaceLabel = switch ($Space) { "" { "default" } "*" { "ALL spaces" } default { $Space } }
Write-Host "  ║   Space: $spaceLabel"                           -ForegroundColor Cyan
if ($DryRun) {
Write-Host "  ║   *** DRY RUN  — no changes will be made ***  ║" -ForegroundColor Yellow
} else {
Write-Host "  ║   *** LIVE MODE — changes WILL be applied *** ║" -ForegroundColor Red
}
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan

# ── Resolve space list ────────────────────────────────────────────
Write-Section "Fetching saved objects"

$spaceIds = if ($Space -eq "*") {
    Write-Log INFO "Enumerating all spaces..."
    Get-AllSpaceIds
} else {
    @($Space)
}

Write-Log INFO "Spaces to process: $(($spaceIds | ForEach-Object { if ($_ -eq '') { 'default' } else { $_ } }) -join ', ')"

# ── Fetch from all targeted spaces ───────────────────────────────
$allObjects = [System.Collections.Generic.List[object]]::new()
foreach ($sid in $spaceIds) {
    $exported = Get-ExportedObjects -SpaceId $sid
    if ($exported.Count -gt 0) {
        $allObjects.AddRange([object[]]$exported)
    }
}

if ($allObjects.Count -eq 0) {
    Write-Log ERROR "No objects returned — check credentials, URL, and space name. Exiting."
    exit 1
}

Write-Log INFO "Total objects across targeted space(s): $($allObjects.Count)"

# Build reference-check index of all known IDs
$existingIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($obj in $allObjects) { [void]$existingIds.Add($obj.id) }
Write-Log INFO "Reference index built — $($existingIds.Count) unique IDs"

$configObjects = @($allObjects | Where-Object { $_.type -eq "config" })
$otherObjects  = @($allObjects | Where-Object { $_.type -ne "config" })

# ── STEP 1: Duplicate removal ─────────────────────────────────────
Write-Section "STEP 1 — Duplicate Objects (keep managed, remove unmanaged)"

$step1Removed = 0

# Group by space+type to keep duplicate detection scoped per space
$bySpaceAndType = $otherObjects | Group-Object { "$($_._spaceId)|$($_.type)" }

foreach ($stGroup in $bySpaceAndType) {
    $parts = $stGroup.Name -split '\|'
    $sid   = $parts[0]
    $type  = $parts[1]

    if ($type -notin $DuplicateCheckTypes) { continue }

    $titleGroups = $stGroup.Group |
        Group-Object { if ($_.attributes.title) { $_.attributes.title.Trim().ToLower() } else { "" } }

    foreach ($tg in $titleGroups) {
        if ($tg.Count -le 1) { continue }

        $title     = $tg.Group[0].attributes.title

        if (Test-Excluded $title) {
            $script:TotalSkipped++
            Write-Log SKIP "[$type][$sid] '$title' — matches exclusion list -> skipped"
            continue
        }
        $managed   = @($tg.Group | Where-Object { $_.managed -eq $true })
        $unmanaged = @($tg.Group | Where-Object { $_.managed -ne $true })

        if ($managed.Count -eq 0) {
            $script:TotalSkipped++
            Write-Log SKIP "[$type][$sid] '$title' — $($tg.Count) copies, none managed -> protected (user-created)"
            continue
        }

        # Multiple managed copies only — keep the newest, delete the older ones
        if ($unmanaged.Count -eq 0) {
            $sortedManaged = @($managed | Sort-Object {
                try { [datetime]$_.updated_at } catch { [datetime]::MinValue }
            } -Descending)

            $keepObj    = $sortedManaged[0]
            $dropManaged = @($sortedManaged | Select-Object -Skip 1)

            Write-Log INFO "[$type][$sid] '$title' — $($managed.Count) managed copies, keeping newest (updated: $($keepObj.updated_at))"

            foreach ($obj in $dropManaged) {
                Remove-KibanaObject -Type $type -Id $obj.id -Label "'$title' (older managed, updated: $($obj.updated_at))" -SpaceId $sid
                $step1Removed++
            }
            continue
        }

        Write-Log INFO "[$type][$sid] '$title' — $($managed.Count) managed + $($unmanaged.Count) unmanaged duplicate(s)"

        foreach ($obj in $unmanaged) {
            Remove-KibanaObject -Type $type -Id $obj.id -Label "'$title'" -SpaceId $sid
            $step1Removed++
        }
    }
}

Write-Log OK "Step 1 complete — duplicates flagged for removal: $step1Removed"

# ── STEP 2: Config pruning ────────────────────────────────────────
Write-Section "STEP 2 — Config Objects (Advanced Settings) — keep newest $KeepConfigCount per space"

$step2Removed = 0
$configBySpace = $configObjects | Group-Object { $_._spaceId }

foreach ($spaceGroup in $configBySpace) {
    $sid     = $spaceGroup.Name
    $configs = @($spaceGroup.Group)

    Write-Log INFO "Space '$sid': $($configs.Count) config object(s) found"

    if ($configs.Count -le $KeepConfigCount) {
        Write-Log SKIP "  Only $($configs.Count) — at or below threshold of $KeepConfigCount, nothing to remove"
        continue
    }

    # Sort descending by semantic version in the object ID (e.g. "9.2.4")
    $sorted = $configs | Sort-Object {
        $raw = $_.id -replace '[^0-9.]', ''
        try { [System.Version]$raw } catch { [System.Version]"0.0.0" }
    } -Descending

    $toKeep   = @($sorted | Select-Object -First $KeepConfigCount)
    $toDelete = @($sorted | Select-Object -Skip  $KeepConfigCount)

    Write-Log INFO   "  Keeping  : $(($toKeep   | ForEach-Object { $_.id }) -join ', ')"
    Write-Log ACTION "  Removing : $(($toDelete | ForEach-Object { $_.id }) -join ', ')"

    foreach ($cfg in $toDelete) {
        Remove-KibanaObject -Type "config" -Id $cfg.id -Label $cfg.id -SpaceId $sid
        $step2Removed++
    }
}

Write-Log OK "Step 2 complete — config objects flagged for removal: $step2Removed"

# ── STEP 3: Dangling reference detection ──────────────────────────
Write-Section "STEP 3 — Dangling Reference Detection"

$step3Removed = 0

foreach ($obj in $otherObjects) {
    if (-not $obj.references -or $obj.references.Count -eq 0) { continue }

    $brokenRefs = @($obj.references | Where-Object { -not $existingIds.Contains($_.id) })
    if ($brokenRefs.Count -eq 0) { continue }

    $title       = if ($obj.attributes.title) { $obj.attributes.title } else { $obj.id }
    $isManaged   = $obj.managed -eq $true
    $isDashboard = $obj.type -eq "dashboard"
    $sid         = $obj._spaceId
    $brokenList  = ($brokenRefs | ForEach-Object { "$($_.type)/$($_.id)" }) -join ", "

    if ($isManaged) {
        Write-Log WARN "[$($obj.type)][$sid] '$title' managed + $($brokenRefs.Count) broken ref(s) -> skipped"
        $script:TotalSkipped++
        continue
    }

    if ($isDashboard -and -not $DeleteDanglingDashboards) {
        Write-Log WARN "[dashboard][$sid] '$title' has $($brokenRefs.Count) broken ref(s) -> skipped (set DeleteDanglingDashboards=true to enable)"
        $script:TotalSkipped++
        continue
    }

    Write-Log ACTION "[$($obj.type)][$sid] '$title' — $($brokenRefs.Count) broken ref(s): $brokenList"
    Remove-KibanaObject -Type $obj.type -Id $obj.id -Label "'$title' (dangling)" -SpaceId $sid
    $step3Removed++
}

Write-Log OK "Step 3 complete — dangling objects flagged for removal: $step3Removed"

# ── SUMMARY ───────────────────────────────────────────────────────
Write-Section "SUMMARY"

$totalFlagged = $step1Removed + $step2Removed + $step3Removed

Write-Host ""
Write-Host ("  {0,-35} {1}" -f "Space(s) processed:",          $spaceLabel)          -ForegroundColor White
Write-Host ("  {0,-35} {1}" -f "Total objects fetched:",        $allObjects.Count)    -ForegroundColor White
Write-Host ""
Write-Host ("  {0,-35} {1}" -f "Duplicate objects removed:",   $step1Removed)        -ForegroundColor White
Write-Host ("  {0,-35} {1}" -f "Config objects removed:",      $step2Removed)        -ForegroundColor White
Write-Host ("  {0,-35} {1}" -f "Dangling objects removed:",    $step3Removed)        -ForegroundColor White
Write-Host ("  {0,-35} {1}" -f "Objects protected (skipped):", $script:TotalSkipped) -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Host "  WARNING  DRY RUN — 0 objects actually deleted." -ForegroundColor Yellow
    Write-Host "     Would have removed: $totalFlagged object(s)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To apply, open the script and set:" -ForegroundColor Cyan
    Write-Host '     $DryRun = $false' -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "  Done. $totalFlagged object(s) deleted." -ForegroundColor Green
    Write-Host ""
}
