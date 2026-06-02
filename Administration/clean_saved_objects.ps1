#Requires -Version 7

# ── Configuration ────────────────────────────────────────────────────────────

$KibanaUrl   = ""
$Username    = ""
$Password    = "" # Add password here

$DryRun          = $true   # Default to SAFE. Flip to $false to act.
$KeepConfigCount = 4        # Keep newest N config objects per space
$DebugEpmRaw     = $false   # Dump raw EPM detail JSON for troubleshooting

# "" -> default space | "myid" -> specific space | "*" -> all spaces
$Space = "*"

# Reinstall behaviour
$ReinstallOnBrokenManaged = $true   # Reinstall package assets INTO the affected space when a managed object is broken
$DeleteOrphanDuplicates   = $false  # Delete duplicate copies (keep oldest). Off by default — review first.

# ── Internals ────────────────────────────────────────────────────────────────

# Saved object types we audit. config/config-global handled specially for pruning.
$ExportTypes = @("dashboard", "visualization", "lens", "map", "search", "index-pattern", "config", "config-global", "tag", "query", "event-annotation-group")

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
        return @("default")
    }
}

# Returns array of PSCustomObjects with: type, id, title, managed, references[], _raw, _spaceId
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
        $rawNdjson = Invoke-RestMethod -Method POST -Uri "$apiBase/saved_objects/_export" -Headers $BaseHeaders -Body $body -ContentType "application/json" -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($rawNdjson)) { return @() }

        $parsed   = [System.Collections.Generic.List[object]]::new()
        $corrupt  = 0
        $rawNdjson -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
            $line = $_.Trim()
            try {
                $o = $line | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $corrupt++
                Write-Log WARN "Space '$label': unparseable NDJSON line skipped (corruption candidate)"
                return
            }
            # Structural validation — a healthy SO must carry type + id
            if (-not $o.type -or -not $o.id) {
                $corrupt++
                Write-Log WARN "Space '$label': object missing type/id (corrupt) -> $line"
                return
            }
            $refs = if ($o.PSObject.Properties.Name -contains 'references' -and $o.references) { @($o.references) } else { @() }
            $title = $null
            if ($o.attributes -and ($o.attributes.PSObject.Properties.Name -contains 'title')) { $title = $o.attributes.title }
            $managed = $false
            if ($o.PSObject.Properties.Name -contains 'managed') { $managed = [bool]$o.managed }

            $parsed.Add([PSCustomObject]@{
                type       = [string]$o.type
                id         = [string]$o.id
                title      = $title
                managed    = $managed
                references = $refs
                _spaceId   = $label
            })
        }

        Write-Log INFO "Space '$label': $($parsed.Count) object(s) parsed, $corrupt corrupt"
        return @{ Objects = $parsed.ToArray(); CorruptCount = $corrupt }
    } catch {
        Write-Log ERROR "Exception exporting space '$label': $_"
        return @{ Objects = @(); CorruptCount = 0 }
    }
}

function Remove-KibanaObject {
    param([string]$Type, [string]$Id, [string]$SpaceId)
    Write-Log WARN "DELETE [$Type] (id: $Id, space: $SpaceId)"
    if (-not $DryRun) {
        $apiBase = Get-ApiBase $SpaceId
        try {
            Invoke-RestMethod -Method DELETE -Uri "$apiBase/saved_objects/$Type/$Id`?force=true" -Headers $BaseHeaders -ErrorAction Stop | Out-Null
        } catch {
            Write-Log ERROR "Delete failed [$Type] ${Id}: $_"
        }
    }
}

# Build a GLOBAL reverse-lookup map: "type/id" (asset) -> packageName.
# IMPORTANT: installed_kibana returns the SAME global id set regardless of the
# /s/{space} prefix used (the space context is ignored for the asset list), so this
# map is built ONCE. The ids it contains are the package-namespaced canonical ids
# (e.g. "system-<uuid>"). When objects are copied between spaces via Copy-to-Spaces,
# Kibana regenerates them with bare uuids that are NOT in this map even though they
# remain managed:true. We therefore ALSO build a package-owned TITLE set (keyed
# type::title) so those copies can be recognised by their stable title rather than id.

$script:GlobalPackageList = $null   # cached array of installed @{Name;Version}
$script:AssetIdMap        = $null   # "type/id" -> @{Name;Version}
$script:OwnedTitleSet     = $null   # HashSet of "type::title" for package-owned assets

function Get-InstalledPackageList {
    if ($null -ne $script:GlobalPackageList) { return $script:GlobalPackageList }
    try {
        $listResult = Invoke-RestMethod -Method GET -Uri "$KibanaUrl/api/fleet/epm/packages?prerelease=false" -Headers $BaseHeaders -ErrorAction Stop
        $script:GlobalPackageList = @($listResult.items | Where-Object { $_.status -eq "installed" } | ForEach-Object {
            [PSCustomObject]@{ Name = $_.name; Version = $_.version }
        })
        Write-Log INFO "Fetched global package list: $($script:GlobalPackageList.Count) installed package(s)"
    } catch {
        Write-Log ERROR "Could not fetch EPM package list: $_"
        $script:GlobalPackageList = @()
    }
    return $script:GlobalPackageList
}

# Global id map (built once). assetKey "type/id" -> @{Name;Version}
function Get-AssetToPackageMap {
    if ($null -ne $script:AssetIdMap) { return $script:AssetIdMap }
    $map = @{}
    foreach ($pkg in (Get-InstalledPackageList)) {
        try {
            $detail = Invoke-RestMethod -Method GET -Uri "$KibanaUrl/api/fleet/epm/packages/$($pkg.Name)/$($pkg.Version)" -Headers $BaseHeaders -ErrorAction Stop
            if ($DebugEpmRaw) {
                Write-Log DEBUG "EPM raw [$($pkg.Name)@$($pkg.Version)]: $($detail | ConvertTo-Json -Depth 6 -Compress)"
            }
            $assets = if ($detail.item.installationInfo.installed_kibana) { $detail.item.installationInfo.installed_kibana } else { @() }
            foreach ($a in $assets) {
                if ([string]::IsNullOrWhiteSpace($a.id) -or [string]::IsNullOrWhiteSpace($a.type)) { continue }
                $key = "$($a.type)/$($a.id)"
                if (-not $map.ContainsKey($key)) {
                    $map[$key] = [PSCustomObject]@{ Name = $pkg.Name; Version = $pkg.Version }
                }
            }
        } catch {
            Write-Log WARN "EPM [$($pkg.Name)@$($pkg.Version)]: could not fetch details — skipping: $_"
        }
    }
    $script:AssetIdMap = $map
    Write-Log INFO "Built global asset->package map: $($map.Count) managed asset key(s)"
    return $script:AssetIdMap
}

# Package-owned TITLE set (built once, from the DEFAULT space where canonical ids resolve).
# installed_kibana carries no titles, so we recover them by exporting the default space and
# keeping only the objects whose ids ARE package-owned. Copied objects in other spaces share
# these titles even though their (regenerated) ids are not in the id map.
function Get-OwnedTitleSet {
    if ($null -ne $script:OwnedTitleSet) { return $script:OwnedTitleSet }
    $set    = [System.Collections.Generic.HashSet[string]]::new()
    $idMap  = Get-AssetToPackageMap
    $export = Get-ExportedObjects -SpaceId "default"
    foreach ($o in @($export.Objects)) {
        if (-not $o.title) { continue }
        if ($idMap.ContainsKey("$($o.type)/$($o.id)")) {
            [void]$set.Add("$($o.type)::$($o.title)")
        }
    }
    $script:OwnedTitleSet = $set
    Write-Log INFO "Built package-owned title set: $($set.Count) distinct title(s) from default space"
    return $script:OwnedTitleSet
}

# Reinstall a package's Kibana assets INTO a specific space (space-scoped repair).
function Invoke-EpmReinstallIntoSpace {
    param([string]$Name, [string]$Version, [string]$Reason, [string]$SpaceId)

    $label = if ([string]::IsNullOrWhiteSpace($SpaceId)) { "default" } else { $SpaceId }
    Write-Log WARN "REINSTALL kibana_assets [$Name@$Version] into space '$label'. Reason: $Reason"

    if (-not $DryRun) {
        $apiBase = Get-ApiBase $SpaceId
        try {
            # Space-scoped Kibana-asset (re)install. force=true to overwrite existing.
            $body = @{ force = $true } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method POST -Uri "$apiBase/fleet/epm/packages/$Name/$Version/kibana_assets" -Headers $BaseHeaders -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Log INFO "Reinstalled kibana_assets [$Name@$Version] into '$label'"
        } catch {
            Write-Log ERROR "Reinstall failed [$Name@$Version] into '$label': $_"
        }
    }
}

# ── Execution ────────────────────────────────────────────────────────────────

$spaceIds = if ($Space -eq "*") { Get-AllSpaceIds } else { @($Space) }

# Built once, reused for every space (installed_kibana is global; titles recovered from default).
$assetToPackage = Get-AssetToPackageMap
$ownedTitles    = Get-OwnedTitleSet

foreach ($sid in $spaceIds) {
    $label = if ([string]::IsNullOrWhiteSpace($sid)) { "default" } else { $sid }
    Write-Log INFO "════════════════════════════════════════════════════════════"
    Write-Log INFO "Auditing space: $label"

    $export = Get-ExportedObjects -SpaceId $sid
    $objects = @($export.Objects)
    if ($objects.Count -eq 0 -and $export.CorruptCount -eq 0) {
        Write-Log WARN "No objects found for space '$label'."
        continue
    }

    # Index everything PRESENT IN THIS SPACE by composite key.
    $present = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($o in $objects) { [void]$present.Add("$($o.type)/$($o.id)") }

    # Packages we must reinstall into THIS space (dedup by name@version).
    $pkgsToRepair = @{}

    # ── 1. Config pruning (space-local) ──────────────────────────────────────
    Write-Log INFO "Pruning old config objects (keeping newest $KeepConfigCount)"
    $configObjects = @($objects | Where-Object { $_.type -eq "config" } | Sort-Object {
        $raw = $_.id -replace '[^0-9.]', ''
        try { [System.Version]$raw } catch { [System.Version]"0.0.0" }
    } -Descending)
    if ($configObjects.Count -gt $KeepConfigCount) {
        foreach ($cfg in @($configObjects | Select-Object -Skip $KeepConfigCount)) {
            Remove-KibanaObject -Type "config" -Id $cfg.id -SpaceId $sid
        }
    }

    # ── 2. Dangling references (space-local) ─────────────────────────────────
    # A reference must resolve to an object present IN THE SAME SPACE.
    Write-Log INFO "Checking for dangling references..."
    $missingTags = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($o in $objects) {
        foreach ($ref in $o.references) {
            if ([string]::IsNullOrWhiteSpace($ref.type) -or [string]::IsNullOrWhiteSpace($ref.id)) { continue }
            $refKey = "$($ref.type)/$($ref.id)"
            if ($present.Contains($refKey)) { continue }

            # Managed Fleet/security tags carry the space name in their id (e.g. fleet-managed-<space>).
            # These go missing when dashboards are copied between spaces without their tags. A package
            # reinstall does NOT recreate them, so classify as a tag-recreate hint, not package breakage.
            $isManagedTag = ($ref.type -eq 'tag') -and ($ref.id -match '^(fleet-managed|security-solution|managed)\b')
            if ($isManagedTag) {
                [void]$missingTags.Add($refKey)
                continue
            }

            Write-Log WARN "Dangling ref in [$($o.type)/$($o.id)] '$($o.title)' -> missing [$refKey]"
            $srcKey = "$($o.type)/$($o.id)"
            if ($o.managed -and $assetToPackage.ContainsKey($srcKey)) {
                $pk = $assetToPackage[$srcKey]
                $pkgsToRepair["$($pk.Name)@$($pk.Version)"] = [PSCustomObject]@{ Name=$pk.Name; Version=$pk.Version; Reason="dangling ref from $srcKey -> $refKey" }
            }
            if ($assetToPackage.ContainsKey($refKey)) {
                $pk = $assetToPackage[$refKey]
                $pkgsToRepair["$($pk.Name)@$($pk.Version)"] = [PSCustomObject]@{ Name=$pk.Name; Version=$pk.Version; Reason="missing managed asset $refKey referenced in space '$label'" }
            }
        }
    }
    if ($missingTags.Count -gt 0) {
        Write-Log INFO "Space '$label': $($missingTags.Count) missing managed tag(s) referenced by copied dashboards: $(($missingTags) -join ', '). Recreate these tags in the space or re-copy with references — package reinstall will not restore them."
    }

    # ── 3. Duplicate detection (space-local) ─────────────────────────────────
    # Same type/id twice = index corruption; same type+title = copy collision.
    Write-Log INFO "Checking for duplicates..."
    $byKey   = $objects | Group-Object { "$($_.type)/$($_.id)" } | Where-Object { $_.Count -gt 1 }
    foreach ($g in $byKey) {
        Write-Log WARN "Duplicate composite key in space '$label': $($g.Name) appears $($g.Count) times (corruption)"
    }
    $byTitle = $objects | Where-Object { $_.title } | Group-Object { "$($_.type)::$($_.title)" } | Where-Object { $_.Count -gt 1 }
    foreach ($g in $byTitle) {
        $managedInGroup = @($g.Group | Where-Object { $_.managed })

        # Ownership is resolved by TITLE, not id. installed_kibana holds package-namespaced
        # ids (system-<uuid>); Copy-to-Spaces regenerates copies with bare uuids that share
        # the title but never match the id map. A managed object whose title is in the
        # package-owned title set is a legitimate package asset (canonical or a copy of one).
        $titleOwned   = $ownedTitles.Contains($g.Name)
        $ownedManaged = @($managedInGroup | Where-Object {
            $assetToPackage.ContainsKey("$($_.type)/$($_.id)") -or $titleOwned
        })
        $unownedManaged = @($managedInGroup | Where-Object {
            -not ($assetToPackage.ContainsKey("$($_.type)/$($_.id)") -or $titleOwned)
        })

        # BENIGN: every copy is a package-owned asset (by id or by title). Includes both the
        # manifest dupe case (two distinct package assets sharing a title) and the cross-space
        # copy case (regenerated-id copies of a package asset). Nothing to fix.
        if ($g.Group.Count -eq $ownedManaged.Count) {
            Write-Log INFO "Duplicate title in space '$label': '$($g.Name)' x$($g.Count) — package-owned assets (benign, ignoring)"
            continue
        }

        Write-Log WARN "Duplicate title in space '$label': '$($g.Name)' x$($g.Count) ($($managedInGroup.Count) managed, $($ownedManaged.Count) package-owned)"

        # REAL COPY COLLISION: a managed copy whose title is NOT package-owned sits alongside
        # one that is — a genuine stale orphan. Delete the orphan(s) and reinstall the canonical
        # asset. (Only fires when title ownership is mixed within the group, which is rare.)
        if ($ownedManaged.Count -ge 1 -and $unownedManaged.Count -ge 1) {
            foreach ($o in $unownedManaged) {
                Write-Log WARN "Stale managed duplicate (not package-owned by id or title) -> deleting [$($o.type)/$($o.id)] '$($o.title)'"
                Remove-KibanaObject -Type $o.type -Id $o.id -SpaceId $sid
            }
            # Prefer an id-owned canonical for accurate package attribution; fall back to title.
            $idOwned = @($ownedManaged | Where-Object { $assetToPackage.ContainsKey("$($_.type)/$($_.id)") })
            if ($idOwned.Count -ge 1) {
                $pk = $assetToPackage["$($idOwned[0].type)/$($idOwned[0].id)"]
                $pkgsToRepair["$($pk.Name)@$($pk.Version)"] = [PSCustomObject]@{ Name=$pk.Name; Version=$pk.Version; Reason="removed stale duplicate of '$($g.Name)', reinstalling canonical asset" }
            } else {
                Write-Log INFO "Removed orphan copy of '$($g.Name)'; canonical is title-owned only, no id-level package attribution for reinstall."
            }
        }
        elseif ($ownedManaged.Count -eq 0 -and $managedInGroup.Count -gt 1) {
            # Managed copies, none owned by id OR title — not a known package asset. Don't guess.
            Write-Log WARN "Duplicate '$($g.Name)': managed copies but not package-owned by id or title — cannot auto-pick canonical. Reporting only."
        }

        $canonical = $ownedManaged

        # Non-managed duplicates (user copies) — delete extras only when explicitly enabled.
        if ($DeleteOrphanDuplicates) {
            $userCopies = @($g.Group | Where-Object { -not $_.managed })
            # If a managed canonical exists, all user copies are deletable; else keep the oldest one.
            $skip = if ($canonical.Count -ge 1) { 0 } else { 1 }
            foreach ($d in @($userCopies | Select-Object -Skip $skip)) {
                Write-Log WARN "Deleting non-managed duplicate [$($d.type)/$($d.id)] '$($d.title)'"
                Remove-KibanaObject -Type $d.type -Id $d.id -SpaceId $sid
            }
        }
    }

    # ── 4. Corruption-driven repair ──────────────────────────────────────────
    if ($export.CorruptCount -gt 0) {
        Write-Log WARN "Space '$label' had $($export.CorruptCount) corrupt object(s). Managed packages will be reinstalled to restore their assets."
        # We can't read a corrupt object's id, so we conservatively repair every package
        # that owns at least one asset IN THIS SPACE. This only reinstalls assets — it does
        # not touch unrelated user objects, and it won't reinstall packages absent from
        # this space (the per-space map excludes them).
        # (Comment this block out if you prefer corruption to be report-only.)
        $distinctPkgs = $assetToPackage.Values | Sort-Object Name,Version -Unique
        foreach ($pk in $distinctPkgs) {
            $pkgsToRepair["$($pk.Name)@$($pk.Version)"] = [PSCustomObject]@{ Name=$pk.Name; Version=$pk.Version; Reason="corrupt object(s) present in space '$label'" }
        }
    }

    # ── 5. Execute space-scoped reinstalls ───────────────────────────────────
    if ($ReinstallOnBrokenManaged -and $pkgsToRepair.Count -gt 0) {
        Write-Log INFO "Space '$label': $($pkgsToRepair.Count) package(s) flagged for asset reinstall into this space."
        foreach ($entry in $pkgsToRepair.Values) {
            Invoke-EpmReinstallIntoSpace -Name $entry.Name -Version $entry.Version -Reason $entry.Reason -SpaceId $sid
        }
    } else {
        Write-Log INFO "Space '$label': clean — no package reinstall needed."
    }
}

Write-Log INFO "Finished clean-up process execution loop."
