#Requires -Version 5.1

# ── Configuration ────────────────────────────────────────────────────────────

$KibanaUrl   = "https://...."
$Username    = "elastic"
$Password    = ""

$DryRun                   = $true
$KeepConfigCount          = 4       # keep newest N config objects per space
$DeleteDanglingDashboards = $false  # delete dashboards with broken refs (user objects — off by default)
$DeleteUserDanglingObjects = $false # delete user-created viz/lens/map/search with broken refs (off by default)
$DeleteOrphanedTags       = $false  # delete tag objects not referenced by anything (off by default)
$DebugEpmRaw              = $false  # dump raw EPM detail JSON for one package (troubleshooting)
$TraceManagedDashboards   = $false  # trace why each managed dashboard is kept/flagged in Step 4a

$ExcludeTitles = @(
    "metrics-*"
)

# ""  -> default space | "myid" -> specific space | "*" -> all spaces
$Space = ""

# ── Internals ────────────────────────────────────────────────────────────────

$ExportTypes         = @("dashboard","visualization","lens","map","search","index-pattern","config","tag","alert")
$DuplicateCheckTypes = @("dashboard","visualization","lens","map","search","index-pattern")

$EncodedCred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
$BaseHeaders = @{
    "Authorization" = "Basic $EncodedCred"
    "kbn-xsrf"      = "true"
    "Content-Type"  = "application/json"
}

$script:TotalSkipped = 0

function Write-Log {
    param(
        [ValidateSet("INFO","DEBUG","WARN","ERROR")]
        [string]$Level,
        [string]$Message
    )
    $dryTag = if ($DryRun) { " [DRY]" } else { "" }
    $stamp  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Host "$stamp$dryTag level=$($Level.ToLower()) msg=`"$Message`""
}

function Test-Excluded ([string]$Title) {
    foreach ($pattern in $ExcludeTitles) {
        if ($Title -like $pattern) { return $true }
    }
    return $false
}

function Get-ApiBase ([string]$SpaceId) {
    if ($SpaceId -eq "" -or $SpaceId -eq "default") { return "$KibanaUrl/api" }
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

function ConvertFrom-NdJson ([string]$Content) {
    $objects = [System.Collections.Generic.List[object]]::new()
    $buffer  = [System.Text.StringBuilder]::new()
    $depth   = 0
    $inStr   = $false
    $escape  = $false

    foreach ($line in ($Content -split "`n")) {
        $trimmed = $line.TrimEnd("`r")
        if ($trimmed.Trim() -eq "") { continue }

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
                $objects.Add(($json | ConvertFrom-Json -ErrorAction Stop))
            } catch {
                Write-Log WARN "Skipped unparseable NDJSON object: $($json.Substring(0,[Math]::Min(80,$json.Length)))..."
            }
            [void]$buffer.Clear()
        }
    }

    return $objects.ToArray()
}

function Get-ExportedObjects ([string]$SpaceId) {
    $label   = if ($SpaceId -eq "") { "default" } else { $SpaceId }
    $apiBase = Get-ApiBase $SpaceId

    Write-Log INFO "Exporting from space '$label'"

    $body = @{
        type                  = $ExportTypes
        excludeExportDetails  = $true
        includeReferencesDeep = $false
    } | ConvertTo-Json -Compress

    try {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        $client  = [System.Net.Http.HttpClient]::new($handler)

        $request = [System.Net.Http.HttpRequestMessage]::new(
            [System.Net.Http.HttpMethod]::Post,
            "$apiBase/saved_objects/_export")

        foreach ($kv in $BaseHeaders.GetEnumerator()) {
            if ($kv.Key -eq "Content-Type") { continue }
            $request.Headers.TryAddWithoutValidation($kv.Key, $kv.Value) | Out-Null
        }

        $request.Content = [System.Net.Http.StringContent]::new(
            $body, [System.Text.Encoding]::UTF8, "application/json")

        $httpResponse = $client.SendAsync($request).GetAwaiter().GetResult()
        $rawText      = $httpResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $client.Dispose()

        if (-not $httpResponse.IsSuccessStatusCode) {
            Write-Log ERROR "Export failed for space '$label' (HTTP $([int]$httpResponse.StatusCode)): $rawText"
            return @()
        }

        $objects = ConvertFrom-NdJson -Content $rawText
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
    param([string]$Type, [string]$Id, [string]$Label, [string]$SpaceId)

    Write-Log INFO "DELETE [$Type] $Label (id: $Id, space: $SpaceId)"

    if (-not $DryRun) {
        $apiBase = Get-ApiBase $SpaceId
        try {
            Invoke-RestMethod -Method DELETE -Uri "$apiBase/saved_objects/$Type/$Id?force=true" -Headers $BaseHeaders -ErrorAction Stop | Out-Null
            Write-Log DEBUG "Deleted [$Type] $Id"
        } catch {
            $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "unknown" }
            Write-Log ERROR "Delete failed [$Type] $Id (HTTP $status): $_"
        }
    }
}

# Returns a tuple: (assetMap hashtable, package array)
# assetMap:  pkgKey -> HashSet[string] of expected saved object IDs
# packages:  PSCustomObject[] with Name, Version, Title, AssetIds, AlertIds
function Get-EpmPackageAssets {
    param([string]$SpaceId)

    $apiBase = Get-ApiBase $SpaceId
    $label   = if ($SpaceId -eq "" -or $SpaceId -eq "default") { "default" } else { $SpaceId }
    Write-Log INFO "Fetching installed EPM packages for space '$label'"

    try {
        $listResult = Invoke-RestMethod `
            -Method      GET `
            -Uri         "$apiBase/fleet/epm/packages?prerelease=false" `
            -Headers     $BaseHeaders `
            -ErrorAction Stop
    } catch {
        Write-Log ERROR "Could not fetch EPM package list: $_"
        return $null, @()
    }

    $installed = @($listResult.items | Where-Object { $_.status -eq "installed" })
    Write-Log INFO "EPM: $($installed.Count) installed package(s) found"

    $assetMap = @{}
    $pkgList  = [System.Collections.Generic.List[object]]::new()

    foreach ($pkg in $installed) {
        $pkgKey = "$($pkg.name)@$($pkg.version)"

        try {
            $detail = Invoke-RestMethod `
                -Method      GET `
                -Uri         "$apiBase/fleet/epm/packages/$($pkg.name)/$($pkg.version)" `
                -Headers     $BaseHeaders `
                -ErrorAction Stop

            $assetIds = [System.Collections.Generic.HashSet[string]]::new()

            # Dump raw response for the first package when troubleshooting
            if ($DebugEpmRaw -and $pkgList.Count -eq 0) {
                Write-Log DEBUG "EPM raw response for [$pkgKey]: $($detail | ConvertTo-Json -Depth 6 -Compress)"
            }

            # item.installationInfo.installed_kibana is the authoritative list of
            # what Fleet actually wrote into Kibana — array of { id, type } objects.
            $rawAssets = if ($detail.item.installationInfo.installed_kibana) {
                             $detail.item.installationInfo.installed_kibana
                         } else { @() }

            # WORKAROUND: Extract active manifest asset IDs to detect obsolete tracking records
            $currentManifestIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            if ($detail.item.assets) {
                foreach ($asset in $detail.item.assets) {
                    if ($asset.id) { 
                        [void]$currentManifestIds.Add($asset.id) 
                    } elseif ($asset.path) {
                        # Fallback parsing leaf filename from path if asset ID is omitted
                        $idFromPath = (Split-Path $asset.path -Leaf) -replace '\.json$', ''
                        [void]$currentManifestIds.Add($idFromPath)
                    }
                }
            }

            # Separate alert-type assets: they exist in installed_kibana but are not
            # exportable via the saved objects API, so we cannot check them via existingIds.
            $alertIds = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($asset in $rawAssets) {
                if ($asset.id) {
                    # If package manifest is populated but does not include this ID, it represents an obsolete asset
                    if ($currentManifestIds.Count -gt 0 -and -not $currentManifestIds.Contains($asset.id)) {
                        Write-Log DEBUG "EPM [$pkgKey]: Asset '$($asset.id)' ($($asset.type)) found in installation history but missing from current manifest. Excluding from protection list."
                        continue
                    }
                    [void]$assetIds.Add($asset.id)
                    if ($asset.type -eq "alert") { [void]$alertIds.Add($asset.id) }
                }
            }

            $assetMap[$pkgKey] = $assetIds
            $pkgList.Add([PSCustomObject]@{
                Key             = $pkgKey
                Name            = $pkg.name
                Version         = $pkg.version
                Title           = $pkg.title
                AssetIds        = $assetIds
                AlertIds        = $alertIds
                Resolved        = $true
                InstalledSpaceId = if ($detail.item.installationInfo.installed_kibana_space_id) {
                                       $detail.item.installationInfo.installed_kibana_space_id
                                   } else { "default" }
            })

            Write-Log DEBUG "EPM [$pkgKey]: $($assetIds.Count) saved object asset(s)"

        } catch {
            # Record the package as unresolved so orphan detection can stay safe
            $pkgList.Add([PSCustomObject]@{
                Key             = $pkgKey
                Name            = $pkg.name
                Version         = $pkg.version
                Title           = $pkg.title
                AssetIds        = [System.Collections.Generic.HashSet[string]]::new()
                AlertIds        = [System.Collections.Generic.HashSet[string]]::new()
                Resolved        = $false
                InstalledSpaceId = "default"
            })
            Write-Log WARN "EPM [$pkgKey]: could not fetch package details — orphan deletion suppressed: $_"
        }
    }

    return $assetMap, $pkgList.ToArray()
}

function Invoke-EpmReinstall {
    param([string]$Name, [string]$Version, [string]$Reason, [string]$SpaceId)

    Write-Log INFO "REINSTALL EPM [$Name@$Version] reason=$Reason"

    if (-not $DryRun) {
        try {
            $body = @{ force = $true } | ConvertTo-Json -Compress
            $reinstallBase = Get-ApiBase $SpaceId
            Invoke-RestMethod `
                -Method      POST `
                -Uri         "$reinstallBase/fleet/epm/packages/$Name/$Version" `
                -Headers     $BaseHeaders `
                -Body        $body `
                -ErrorAction Stop | Out-Null
            Write-Log DEBUG "Reinstalled EPM [$Name@$Version]"
        } catch {
            $status = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "unknown" }
            Write-Log ERROR "Reinstall failed [$Name@$Version] (HTTP $status): $_"
        }
    }
}

# ── Main ─────────────────────────────────────────────────────────────────────

$spaceLabel = switch ($Space) { "" { "default" } "*" { "ALL" } default { $Space } }
Write-Log INFO "Starting Kibana cleanup | url=$KibanaUrl space=$spaceLabel dryRun=$DryRun"

$spaceIds = if ($Space -eq "*") {
    Write-Log INFO "Enumerating all spaces"
    Get-AllSpaceIds
} else {
    @($Space)
}

$allObjects = [System.Collections.Generic.List[object]]::new()
foreach ($sid in $spaceIds) {
    $exported = Get-ExportedObjects -SpaceId $sid
    if ($exported.Count -gt 0) { $allObjects.AddRange([object[]]$exported) }
}

if ($allObjects.Count -eq 0) {
    Write-Log ERROR "No objects returned — check credentials, URL, and space name. Exiting."
    exit 1
}

Write-Log INFO "Total objects fetched: $($allObjects.Count)"

$existingIds = [System.Collections.Generic.HashSet[string]]::new()
foreach ($obj in $allObjects) { [void]$existingIds.Add($obj.id) }
Write-Log DEBUG "Reference index built: $($existingIds.Count) unique IDs"

$configObjects = @($allObjects | Where-Object { $_.type -eq "config" })
$otherObjects  = @($allObjects | Where-Object { $_.type -ne "config" })

# ── Step 1: Duplicate removal ─────────────────────────────────────────────────

Write-Log INFO "Step 1: Duplicate removal"
$step1Removed = 0

$bySpaceAndType = $otherObjects | Group-Object { "$($_._spaceId)|$($_.type)" }

foreach ($stGroup in $bySpaceAndType) {
    $parts = $stGroup.Name -split '\|'
    $sid   = $parts[0]
    $type  = $parts[1]

    if ($type -notin $DuplicateCheckTypes) { continue }

    $titleGroups = $stGroup.Group | Group-Object {
        if ($_.attributes.title) { $_.attributes.title.Trim().ToLower() } else { "" }
    }

    foreach ($tg in $titleGroups) {
        if ($tg.Count -le 1) { continue }

        $title   = $tg.Group[0].attributes.title
        $managed   = @($tg.Group | Where-Object { $_.managed -eq $true })
        $unmanaged = @($tg.Group | Where-Object { $_.managed -ne $true })

        if (Test-Excluded $title) {
            $script:TotalSkipped++
            Write-Log DEBUG "Excluded [$type][$sid] '$title'"
            continue
        }

        if ($managed.Count -eq 0) {
            $script:TotalSkipped++
            Write-Log DEBUG "Protected [$type][$sid] '$title' — $($tg.Count) copies, all user-created"
            continue
        }

        if ($unmanaged.Count -eq 0) {
            $sorted      = @($managed | Sort-Object { try { [datetime]$_.updated_at } catch { [datetime]::MinValue } } -Descending)
            $dropManaged = @($sorted | Select-Object -Skip 1)
            Write-Log INFO "[$type][$sid] '$title' — $($managed.Count) managed copies, removing older"
            foreach ($obj in $dropManaged) {
                Remove-KibanaObject -Type $type -Id $obj.id -Label "'$title' (older managed)" -SpaceId $sid
                $step1Removed++
            }
            continue
        }

        Write-Log INFO "[$type][$sid] '$title' — removing $($unmanaged.Count) unmanaged duplicate(s)"
        foreach ($obj in $unmanaged) {
            Remove-KibanaObject -Type $obj.type -Id $obj.id -Label "'$title'" -SpaceId $sid
            $step1Removed++
        }
    }
}

Write-Log INFO "Step 1 complete: $step1Removed duplicate(s) flagged"

# ── Step 2: Config pruning ────────────────────────────────────────────────────

Write-Log INFO "Step 2: Config pruning (keep newest $KeepConfigCount per space)"
$step2Removed = 0

foreach ($spaceGroup in ($configObjects | Group-Object { $_._spaceId })) {
    $sid     = $spaceGroup.Name
    $configs = @($spaceGroup.Group)

    if ($configs.Count -le $KeepConfigCount) {
        Write-Log DEBUG "Space '$sid': $($configs.Count) config object(s) — within threshold, nothing to remove"
        continue
    }

    $sorted   = $configs | Sort-Object {
        $raw = $_.id -replace '[^0-9.]', ''
        try { [System.Version]$raw } catch { [System.Version]"0.0.0" }
    } -Descending

    $toKeep   = @($sorted | Select-Object -First $KeepConfigCount)
    $toDelete = @($sorted | Select-Object -Skip  $KeepConfigCount)

    Write-Log INFO "Space '$sid': keeping $(($toKeep | ForEach-Object { $_.id }) -join ', '), removing $(($toDelete | ForEach-Object { $_.id }) -join ', ')"

    foreach ($cfg in $toDelete) {
        Remove-KibanaObject -Type "config" -Id $cfg.id -Label $cfg.id -SpaceId $sid
        $step2Removed++
    }
}

Write-Log INFO "Step 2 complete: $step2Removed config object(s) flagged"

# ── Step 3: Dangling reference detection ──────────────────────────────────────

Write-Log INFO "Step 3: Dangling reference detection"
$step3Removed = 0

foreach ($obj in $otherObjects) {
    if (-not $obj.references -or $obj.references.Count -eq 0) { continue }

    $brokenRefs = @($obj.references | Where-Object { -not $existingIds.Contains($_.id) })
    if ($brokenRefs.Count -eq 0) { continue }

    $title      = if ($obj.attributes.title) { $obj.attributes.title } else { $obj.id }
    $sid        = $obj._spaceId
    $brokenList = ($brokenRefs | ForEach-Object { "$($_.type)/$($_.id)" }) -join ", "

    if ($obj.managed -eq $true) {
        # Deliberately not deleting: Step 4 reinstall will regenerate these
        Write-Log WARN "[$($obj.type)][$sid] '$title' managed with $($brokenRefs.Count) broken ref(s) — deferred to EPM reinstall (Step 4)"
        $script:TotalSkipped++
        continue
    }

    # User-created objects: protected by default — require explicit opt-in per type
    if ($obj.type -eq "dashboard" -and -not $DeleteDanglingDashboards) {
        Write-Log WARN "[dashboard][$sid] '$title' has $($brokenRefs.Count) broken ref(s) — skipped (set DeleteDanglingDashboards=true to enable)"
        $script:TotalSkipped++
        continue
    }

    if ($obj.type -ne "dashboard" -and -not $DeleteUserDanglingObjects) {
        Write-Log WARN "[$($obj.type)][$sid] '$title' has $($brokenRefs.Count) broken ref(s) — skipped (set DeleteUserDanglingObjects=true to enable)"
        $script:TotalSkipped++
        continue
    }

    Write-Log INFO "[$($obj.type)][$sid] '$title' — $($brokenRefs.Count) broken ref(s): $brokenList"
    Remove-KibanaObject -Type $obj.type -Id $obj.id -Label "'$title' (dangling)" -SpaceId $sid
    $step3Removed++
}

Write-Log INFO "Step 3 complete: $step3Removed dangling object(s) flagged"

# ── Step 4: EPM Integration Audit ────────────────────────────────────────────
#
#   4a — Orphaned managed objects:
#        managed=true objects whose ID is not in any installed package's asset list.
#        These were left behind when a package was uninstalled or replaced.
#
#   4b — Missing package assets:
#        Installed packages with expected saved objects absent from existingIds.
#        Resolved by a forced reinstall so Fleet regenerates the missing assets.

Write-Log INFO "Step 4: EPM integration audit"
$step4Removed     = 0
$step4Reinstalled = 0

foreach ($currentSpaceId in $spaceIds) {

$epmAssetMap, $epmPackages = Get-EpmPackageAssets -SpaceId $currentSpaceId

# Scope otherObjects to the current space for Steps 4a/4b
$currentSpaceLabel = if ($currentSpaceId -eq "") { "default" } else { $currentSpaceId }
$spaceObjects = @($otherObjects | Where-Object { $_._spaceId -eq $currentSpaceLabel })

if ($null -eq $epmAssetMap) {
    Write-Log WARN "EPM data unavailable for space '$currentSpaceId' — skipping"
} else {
    # Flat set of ALL asset IDs across all installed packages
    # Only count asset IDs from packages actually installed in THIS space.
    # A package installed in another space lists IDs that don't apply here, and
    # including them would let stale objects (e.g. a dashboard dropped from a newer
    # package version) wrongly match and survive cleanup.
    $allEpmAssetIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($pkg in $epmPackages) {
        if ($pkg.InstalledSpaceId -ne $currentSpaceLabel) { continue }
        foreach ($id in $pkg.AssetIds) { [void]$allEpmAssetIds.Add($id) }
    }
    Write-Log DEBUG "EPM: $($allEpmAssetIds.Count) asset ID(s) owned by packages installed in '$currentSpaceLabel'"

    # If any package failed its detail fetch, its real asset IDs are unknown.
    # Deleting "orphans" in that state risks removing objects that actually belong
    # to the unresolved package, so 4a is skipped for safety this space.
    $unresolved = @($epmPackages | Where-Object { -not $_.Resolved })
    $orphanCheckSafe = $unresolved.Count -eq 0

    if (-not $orphanCheckSafe) {
        Write-Log WARN "Orphan deletion skipped for '$currentSpaceLabel' — $($unresolved.Count) package(s) failed to resolve: $(($unresolved | ForEach-Object { $_.Key }) -join ', ')"
    }

    # 4a: Orphaned managed objects
    foreach ($obj in @($spaceObjects | Where-Object { $_.managed -eq $true })) {
        if (-not $orphanCheckSafe) { break }

        if ($TraceManagedDashboards -and $obj.type -eq "dashboard") {
            $inSet     = $allEpmAssetIds.Contains($obj.id)
            $nsList    = if ($obj.namespaces) { $obj.namespaces -join ',' } else { '<none>' }
            $ownerPkgs = @($epmPackages | Where-Object { $_.AssetIds.Contains($obj.id) } | ForEach-Object { $_.Key }) -join ', '
            Write-Log DEBUG "TRACE dashboard id=$($obj.id) managed=$($obj.managed) namespaces=[$nsList] originId=$($obj.originId) inCurrentSpaceAssetSet=$inSet ownedBy=[$ownerPkgs]"
        }

        if ($allEpmAssetIds.Count -eq 0 -or $allEpmAssetIds.Contains($obj.id)) { continue }

        $title = if ($obj.attributes.title) { $obj.attributes.title } else { $obj.id }
        $sid   = $obj._spaceId

        # Fleet stores package tags (fleet-pkg-*) outside of installed_kibana — never delete them
        if ($obj.id -like "fleet-pkg-*") {
            Write-Log DEBUG "Skipping Fleet package tag '$($obj.id)' [$sid] — managed outside EPM asset list"
            $script:TotalSkipped++
            continue
        }

        if (Test-Excluded $title) {
            $script:TotalSkipped++
            Write-Log DEBUG "Excluded orphaned managed [$($obj.type)][$sid] '$title'"
            continue
        }

        Write-Log INFO "Orphaned managed [$($obj.type)][$sid] '$title' — not owned by any installed package"
        Remove-KibanaObject -Type $obj.type -Id $obj.id -Label "'$title' (orphaned managed)" -SpaceId $sid
        $step4Removed++
    }

    # 4b: Missing package assets -> reinstall
    foreach ($pkg in $epmPackages) {
        if ($pkg.AssetIds.Count -eq 0) {
            Write-Log DEBUG "EPM [$($pkg.Key)]: no asset manifest available — skipping completeness check"
            continue
        }

        # Only check completeness for packages installed in the current space.
        # A package installed in 'default' has asset IDs that only exist there;
        # checking them against another space's objects would always show them missing.
        if ($pkg.InstalledSpaceId -ne $currentSpaceLabel) {
            Write-Log DEBUG "EPM [$($pkg.Key)]: installed in '$($pkg.InstalledSpaceId)', not '$currentSpaceLabel' — skipping completeness check"
            continue
        }

        # Exclude alert-type assets from the completeness check — alerts are in
        # installed_kibana but not exportable via the saved objects API, so they
        # will never appear in existingIds regardless of whether they actually exist.
        $exportableAssetIds = @($pkg.AssetIds | Where-Object { -not $pkg.AlertIds.Contains($_) })
        $missingIds = @($exportableAssetIds | Where-Object { -not $existingIds.Contains($_) })

        if ($missingIds.Count -eq 0) {
            Write-Log DEBUG "EPM [$($pkg.Key)]: all $($pkg.AssetIds.Count) asset(s) present"
        } else {
            $preview = ($missingIds | Select-Object -First 5) -join ", "
            $suffix  = if ($missingIds.Count -gt 5) { " (and $($missingIds.Count - 5) more)" } else { "" }
            Write-Log WARN "EPM [$($pkg.Key)]: $($missingIds.Count)/$($pkg.AssetIds.Count) asset(s) missing — $preview$suffix"
            Invoke-EpmReinstall -Name $pkg.Name -Version $pkg.Version -Reason "$($missingIds.Count) missing asset(s)" -SpaceId $currentSpaceId
            $step4Reinstalled++
        }
    }
}

} # end per-space EPM loop

Write-Log INFO "Step 4 complete: orphanedManaged=$step4Removed epmReinstalled=$step4Reinstalled"

# ── Step 5: Orphaned tag cleanup ─────────────────────────────────────────────
#
#   Tag objects not referenced by any other saved object are useless and
#   accumulate when tagged objects are deleted without cleanup.

Write-Log INFO "Step 5: Orphaned tag cleanup (enabled=$DeleteOrphanedTags)"
$step5Removed = 0

if ($DeleteOrphanedTags) {
    Write-Log WARN "DeleteOrphanedTags=true — user-created unreferenced tags will be removed" 
    $referencedTagIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($obj in $allObjects) {
        if (-not $obj.references) { continue }
        foreach ($ref in $obj.references) {
            if ($ref.type -eq "tag") { [void]$referencedTagIds.Add($ref.id) }
        }
    }

    $tagObjects = @($allObjects | Where-Object { $_.type -eq "tag" })
    Write-Log DEBUG "Tags: $($tagObjects.Count) total, $($referencedTagIds.Count) referenced"

    foreach ($tag in $tagObjects) {
        if ($referencedTagIds.Contains($tag.id)) { continue }

        $tagName = if ($tag.attributes.name) { $tag.attributes.name } else { $tag.id }
        $sid     = $tag._spaceId

        if ($tag.managed -eq $true) {
            Write-Log DEBUG "Skipping managed orphaned tag '$tagName' [$sid]"
            $script:TotalSkipped++
            continue
        }

        Write-Log INFO "Orphaned tag '$tagName' (id: $($tag.id), space: $sid)"
        Remove-KibanaObject -Type "tag" -Id $tag.id -Label "'$tagName' (orphaned tag)" -SpaceId $sid
        $step5Removed++
    }
}

Write-Log INFO "Step 5 complete: $step5Removed orphaned tag(s) flagged"

# ── Summary ───────────────────────────────────────────────────────────────────

$totalDeleted = $step1Removed + $step2Removed + $step3Removed + $step4Removed + $step5Removed
Write-Log INFO "Summary | duplicates=$step1Removed configs=$step2Removed dangling=$step3Removed orphanedManaged=$step4Removed epmReinstalled=$step4Reinstalled orphanedTags=$step5Removed skipped=$($script:TotalSkipped) totalDeleted=$totalDeleted dryRun=$DryRun"
