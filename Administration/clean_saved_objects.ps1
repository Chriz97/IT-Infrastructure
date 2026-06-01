#Requires -Version 7

# ── Configuration ────────────────────────────────────────────────────────────

$KibanaUrl   = ""
$Username    = ""
$Password    = "" # Add password here

$DryRun          = $false
$KeepConfigCount = 4       # Keep newest N config objects per space
$DebugEpmRaw     = $false  # Dump raw EPM detail JSON for troubleshooting

# "" -> default space | "myid" -> specific space | "*" -> all spaces
$Space = "default"

# ── Internals ────────────────────────────────────────────────────────────────

# Core export types we can reliably track via the Saved Objects API
$ExportTypes = @("dashboard", "visualization", "lens", "map", "search", "index-pattern", "config", "tag")

$EncodedCred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
$BaseHeaders = @{
    "Authorization" = "Basic $EncodedCred"
    "kbn-xsrf"      = "true"
}

function Write-Log {
    param(
        [ValidateSet("INFO","DEBUG","WARN","ERROR")] [string]$Level,
        [string]$Message
    )
    $dryTag = if ($DryRun) { " [DRY]" } else { "" }
    $stamp  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Host "$stamp$dryTag level=$($Level.ToLower()) msg=`"$Message`""
}

function Get-ApiBase ([string]$SpaceId) {
    if ([string]::IsNullOrWhiteSpace($SpaceId) -or $SpaceId -eq "default") { return "$KibanaUrl/api" }
    return "$KibanaUrl/s/$SpaceId/api"
}

function Get-AllSpaceIds {
    try {
        $result = Invoke-RestMethod -Method GET -Uri "$KibanaUrl/api/spaces/space" -Headers $BaseHeaders -ErrorAction Stop
        return @($result | ForEach-Object { $_.id })
    } catch {
        Write-Log ERROR "Could not enumerate spaces: $_"
        return @("")
    }
}

function Get-ExportedObjects ([string]$SpaceId) {
    $label   = if ([string]::IsNullOrWhiteSpace($SpaceId)) { "default" } else { $SpaceId }
    $apiBase = Get-ApiBase $SpaceId

    Write-Log INFO "Exporting saved objects from space '$label'"

    $body = @{
        type                  = $ExportTypes
        excludeExportDetails  = $true
        includeReferencesDeep = $false
    } | ConvertTo-Json -Compress

    try {
        # Kibana returns raw NDJSON string lines
        $rawNdjson = Invoke-RestMethod -Method POST -Uri "$apiBase/saved_objects/_export" -Headers $BaseHeaders -Body $body -ContentType "application/json" -ErrorAction Stop
        
        if ([string]::IsNullOrWhiteSpace($rawNdjson)) { return @() }

        # Efficient line-by-line NDJSON parser
        $objects = $rawNdjson -split "`n" | 
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | 
            ForEach-Object { $_.Trim() | ConvertFrom-Json }

        foreach ($obj in $objects) {
            $obj | Add-Member -NotePropertyName "_spaceId" -NotePropertyValue $label -Force
        }

        Write-Log INFO "Space '$label': $($objects.Count) object(s) exported"
        return $objects
    } catch {
        Write-Log ERROR "Exception exporting space '$label': $_"
        return @()
    }
}

function Remove-KibanaObject {
    param([string]$Type, [string]$Id, [string]$SpaceId)

    Write-Log INFO "DELETE [$Type] (id: $Id, space: $SpaceId)"

    if (-not $DryRun) {
        $apiBase = Get-ApiBase $SpaceId
        try {
            Invoke-RestMethod -Method DELETE -Uri "$apiBase/saved_objects/$Type/$Id" -Headers $BaseHeaders -ErrorAction Stop | Out-Null
        } catch {
            Write-Log ERROR "Delete failed [$Type] ${Id}: $_"
        }
    }
}

function Get-EpmPackageAssets {
    param([string]$SpaceId)

    $apiBase = Get-ApiBase $SpaceId
    try {
        $listResult = Invoke-RestMethod -Method GET -Uri "$apiBase/fleet/epm/packages?prerelease=false" -Headers $BaseHeaders -ErrorAction Stop
    } catch {
        Write-Log ERROR "Could not fetch EPM package list: $_"
        return @()
    }

    $installed = @($listResult.items | Where-Object { $_.status -eq "installed" })
    $pkgList   = [System.Collections.Generic.List[object]]::new()

    foreach ($pkg in $installed) {
        $pkgKey = "$($pkg.name)@$($pkg.version)"
        try {
            $detail = Invoke-RestMethod -Method GET -Uri "$apiBase/fleet/epm/packages/$($pkg.name)/$($pkg.version)" -Headers $BaseHeaders -ErrorAction Stop
            
            if ($DebugEpmRaw -and $pkgList.Count -eq 0) {
                Write-Log DEBUG "EPM raw response for [$pkgKey]: $($detail | ConvertTo-Json -Depth 6 -Compress)"
            }

            $rawAssets = if ($detail.item.installationInfo.installed_kibana) { $detail.item.installationInfo.installed_kibana } else { @() }
            
            $pkgList.Add([PSCustomObject]@{
                Name    = $pkg.name
                Version = $pkg.version
                Key     = $pkgKey
                Assets  = $rawAssets # Contains array of @{ id="..."; type="..." }
            })
        } catch {
            Write-Log WARN "EPM [$pkgKey]: Could not fetch details — skipping: $_"
        }
    }
    return $pkgList.ToArray()
}

function Invoke-EpmReinstall {
    param([string]$Name, [string]$Version, [string]$Reason, [string]$SpaceId)

    Write-Log WARN "REINSTALL EPM [$Name@$Version] Reason: $Reason"

    if (-not $DryRun) {
        try {
            $body = @{ force = $true } | ConvertTo-Json -Compress
            $apiBase = Get-ApiBase $SpaceId
            Invoke-RestMethod -Method POST -Uri "$apiBase/fleet/epm/packages/$Name/$Version" -Headers $BaseHeaders -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Log INFO "Successfully reinstalled EPM [$Name@$Version]"
        } catch {
            Write-Log ERROR "Reinstall failed [$Name@$Version]: $_"
        }
    }
}

# ── Execution ────────────────────────────────────────────────────────────────

$spaceIds = if ($Space -eq "*") { Get-AllSpaceIds } else { @($Space) }

foreach ($sid in $spaceIds) {
    Write-Log INFO "════════════════════════════════════════════════════════════"
    Write-Log INFO "Starting Audit for Space: $sid"
    
    $exportedObjects = Get-ExportedObjects -SpaceId $sid
    if ($exportedObjects.Count -eq 0) {
        Write-Log WARN "No objects found or exported for space '$sid'."
        continue
    }

    # 1. Build a strict, high-speed Composite Key Index (type/id)
    $existingKeys = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($obj in $exportedObjects) {
        if ($obj.type -and $obj.id) {
            [void]$existingKeys.Add("$($obj.type)/$($obj.id)")
        }
    }

    # 2. Config Pruning Block
    Write-Log INFO "Pruning old config objects (keeping newest $KeepConfigCount)"
    $configObjects = @($exportedObjects | Where-Object { $_.type -eq "config" } | Sort-Object {
        $raw = $_.id -replace '[^0-9.]', ''
        try { [System.Version]$raw } catch { [System.Version]"0.0.0" }
    } -Descending)

    if ($configObjects.Count -gt $KeepConfigCount) {
        $toDelete = @($configObjects | Select-Object -Skip $KeepConfigCount)
        foreach ($cfg in $toDelete) {
            Remove-KibanaObject -Type "config" -Id $cfg.id -SpaceId $sid
        }
    }

    # 3. Targeted EPM Integration Audit
    Write-Log INFO "Auditing EPM package asset integrity..."
    $epmPackages = Get-EpmPackageAssets -SpaceId $sid

    foreach ($pkg in $epmPackages) {
        $missingAssets = [System.Collections.Generic.List[string]]::new()

        foreach ($asset in $pkg.Assets) {
            if ([string]::IsNullOrWhiteSpace($asset.id) -or [string]::IsNullOrWhiteSpace($asset.type)) { continue }

            # CRITICAL FIX: Skip checking types we didn't explicitly export to eliminate false positives
            if ($asset.type -notin $ExportTypes) { continue }

            $compositeKey = "$($asset.type)/$($asset.id)"
            if (-not $existingKeys.Contains($compositeKey)) {
                $missingAssets.Add($compositeKey)
            }
        }

        if ($missingAssets.Count -gt 0) {
            $sample = ($missingAssets | Select-Object -First 3) -join ", "
            $reason = "$($missingAssets.Count) missing asset(s) e.g., [$sample]"
            Invoke-EpmReinstall -Name $pkg.Name -Version $pkg.Version -Reason $reason -SpaceId $sid
        } else {
            Write-Log DEBUG "EPM [$( $pkg.Key )]: Perfect health status."
        }
    }
}

Write-Log INFO "Finished clean-up process execution loop."
