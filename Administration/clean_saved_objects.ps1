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

# ── Orphaned-dashboard cleanup ────────────────────────────────────────────────
# Delete managed DASHBOARDS whose owning integration package has been uninstalled.
# This ONLY ever targets type=dashboard — never index-patterns, tags, or data views.
$DeleteOrphanDashboards = $true

# A managed dashboard id looks like "<pkg>-<uuid>". We only treat <pkg> as a real package
# if it appears in this set. It is seeded from the CURRENTLY-installed packages at runtime,
# plus any names you list here for packages that may have been uninstalled (so their leftover
# dashboards can still be recognised). Add names of integrations you have ever installed.
$ExtraKnownPackageNames = @(
    # e.g. "apache", "mysql", "redis", "docker", "kubernetes", "aws", "azure"
)

# ── Stale-asset enforcement (installed package, asset removed in newer version) ──
# For packages listed here ONLY: delete managed DASHBOARDS whose id is "<pkg>-<uuid>" where
# <pkg> IS currently installed but the id is NOT in that package's current installed_kibana.
# This handles a dashboard that a newer package version no longer ships. Use this for packages
# whose manifest YOU control (e.g. custom internal packages). Leave empty to disable.
# Example: $EnforceManifestPackages = @("nginx", "my_custom_pkg")
$EnforceManifestPackages = @(
    # "my_custom_pkg"
)

# Reserved id namespaces that are NOT packages and must never be parsed as one. These are
# Kibana/Fleet/security-solution internal tag and data-view prefixes. Even though they contain
# hyphens, they are explicitly excluded from being treated as "<pkg>-...".
$ReservedNamespaces = @("fleet-managed", "fleet-pkg", "fleet-default", "security-solution", "logs", "metrics", "synthetics", "apm", "traces", "profiling")

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
            $updatedAt = $null
            if ($o.PSObject.Properties.Name -contains 'updated_at') { $updatedAt = [string]$o.updated_at }

            $parsed.Add([PSCustomObject]@{
                type       = [string]$o.type
                id         = [string]$o.id
                title      = $title
                managed    = $managed
                references = $refs
                updated_at = $updatedAt
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

# _export does not reliably include updated_at, so enrich a set of objects of one type
# in a space with their updated_at via _find. Mutates the passed objects in place.
function Add-UpdatedAt {
    param([object[]]$Objects, [string]$Type, [string]$SpaceId)
    $apiBase = Get-ApiBase $SpaceId
    $stamps  = @{}   # id -> updated_at
    $page = 1
    do {
        try {
            $resp = Invoke-RestMethod -Method GET -Headers $BaseHeaders -ErrorAction Stop `
                -Uri "$apiBase/saved_objects/_find?type=$Type&per_page=1000&page=$page&fields=title"
        } catch {
            Write-Log WARN "Could not fetch updated_at for type '$Type' in space '$SpaceId': $_"
            return
        }
        foreach ($so in @($resp.saved_objects)) {
            if ($so.id -and $so.updated_at) { $stamps[[string]$so.id] = [string]$so.updated_at }
        }
        $total = [int]$resp.total
        $page++
    } while (($page - 1) * 1000 -lt $total)

    foreach ($o in $Objects) {
        if ($o.type -eq $Type -and $stamps.ContainsKey($o.id)) { $o.updated_at = $stamps[$o.id] }
    }
}

# Resolve the owning package NAME from a managed object's id prefix (e.g. "system-<uuid>"
# -> "system"). Returns $null if no installed package name prefixes the id. Used to decide
# whether a managed object's package still exists.
function Resolve-PackageNameFromId {
    param([string]$Id, [string[]]$InstalledNames)
    foreach ($name in $InstalledNames) {
        if ($Id -like "$name-*") { return $name }
    }
    return $null
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

# Current DASHBOARD ids shipped by a given installed package, derived from the global asset
# map (installed_kibana). Returns a HashSet of dashboard ids, or $null if the package ships
# ZERO dashboards in its manifest — which we treat as "do not enforce" because an empty
# result is indistinguishable from a failed/partial manifest read, and enforcing against it
# would delete every dashboard for that package. Cached per package.
$script:PkgDashIdCache = @{}
function Get-PackageDashboardIds {
    param([string]$PackageName)
    if ($script:PkgDashIdCache.ContainsKey($PackageName)) { return $script:PkgDashIdCache[$PackageName] }

    $idMap = Get-AssetToPackageMap
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($key in $idMap.Keys) {
        if ($key -notlike "dashboard/*") { continue }
        if ($idMap[$key].Name -ne $PackageName) { continue }
        [void]$set.Add($key.Substring("dashboard/".Length))
    }

    if ($set.Count -eq 0) {
        Write-Log WARN "Manifest-enforce: package '$PackageName' reports ZERO dashboard assets — skipping enforcement (empty/partial manifest is unsafe to enforce against)."
        $script:PkgDashIdCache[$PackageName] = $null
        return $null
    }
    $script:PkgDashIdCache[$PackageName] = $set
    Write-Log INFO "Manifest-enforce: package '$PackageName' currently ships $($set.Count) dashboard(s)."
    return $set
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

# SAFETY: orphan-deletion compares managed objects against the installed package set.
# If that set is empty we cannot reliably tell "package gone" from "fetch failed", and a
# transient error would make EVERY managed object look orphaned. Hard-abort instead.
$installedNames = @((Get-InstalledPackageList) | ForEach-Object { $_.Name })
if ($installedNames.Count -eq 0) {
    Write-Log ERROR "Installed package list is empty — refusing to run orphan/duplicate deletion (cannot distinguish 'package gone' from a failed fetch). Aborting."
    exit 1
}

# Real package names = currently installed + operator-supplied extras (for uninstalled
# packages whose leftover dashboards we still want to recognise), MINUS reserved namespaces.
# Only ids whose <pkg> token is in this set are ever eligible for orphan deletion, which is
# what prevents reserved prefixes (fleet-*, security-solution-*) and base data views
# (logs-*, metrics-*) from being misread as packages.
$KnownPackageNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($n in $installedNames)         { [void]$KnownPackageNames.Add($n) }
foreach ($n in $ExtraKnownPackageNames) { if ($n) { [void]$KnownPackageNames.Add($n) } }
foreach ($n in $ReservedNamespaces)     { [void]$KnownPackageNames.Remove($n) }
Write-Log INFO "Orphan-dashboard package name set: $($KnownPackageNames.Count) name(s); reserved namespaces excluded."

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

    # Enrich dashboards with updated_at (needed to keep the OLDEST managed duplicate).
    Add-UpdatedAt -Objects $objects -Type "dashboard" -SpaceId $sid

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

        # ── DUPLICATE MANAGED DASHBOARDS: keep the OLDEST, delete the newer copies. ──
        # Applies only to dashboards with >1 managed copy of the same title. We keep the
        # copy with the earliest updated_at (the original) and remove newer duplicates.
        $managedDash = @($managedInGroup | Where-Object { $_.type -eq 'dashboard' })
        if ($managedDash.Count -gt 1) {
            # Sort oldest-first by updated_at; objects lacking a timestamp sort last (kept only if nothing else).
            $sorted = @($managedDash | Sort-Object {
                if ([string]::IsNullOrWhiteSpace($_.updated_at)) { [datetime]::MaxValue }
                else { try { [datetime]::Parse($_.updated_at, $null, [System.Globalization.DateTimeStyles]::RoundtripKind) } catch { [datetime]::MaxValue } }
            })
            $keep   = $sorted[0]
            $remove = @($sorted | Select-Object -Skip 1)
            Write-Log WARN "Duplicate managed dashboard '$($g.Name)' x$($managedDash.Count) in space '$label' — keeping oldest [$($keep.id)] ($($keep.updated_at)), deleting $($remove.Count) newer."
            foreach ($d in $remove) {
                Write-Log WARN "Deleting newer managed dashboard duplicate [$($d.type)/$($d.id)] '$($d.title)' (updated $($d.updated_at))"
                Remove-KibanaObject -Type $d.type -Id $d.id -SpaceId $sid
            }
            continue   # dashboard dupes are fully handled here; skip generic logic for this group
        }

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
        # one that is — a genuine stale orphan. Per requirement, destructive cleanup is limited
        # to DASHBOARDS; for any other type (search, index-pattern, tag, ...) we report only and
        # never delete, since those objects are frequently referenced by dashboards.
        if ($ownedManaged.Count -ge 1 -and $unownedManaged.Count -ge 1) {
            foreach ($o in $unownedManaged) {
                if ($o.type -eq 'dashboard') {
                    Write-Log WARN "Stale managed dashboard duplicate (not package-owned) -> deleting [$($o.type)/$($o.id)] '$($o.title)'"
                    Remove-KibanaObject -Type $o.type -Id $o.id -SpaceId $sid
                } else {
                    Write-Log WARN "Stale managed duplicate [$($o.type)/$($o.id)] '$($o.title)' — non-dashboard type, reporting only (not deleted)."
                }
            }
            # Prefer an id-owned canonical for accurate package attribution; fall back to title.
            $idOwned = @($ownedManaged | Where-Object { $assetToPackage.ContainsKey("$($_.type)/$($_.id)") })
            if ($idOwned.Count -ge 1) {
                $pk = $assetToPackage["$($idOwned[0].type)/$($idOwned[0].id)"]
                $pkgsToRepair["$($pk.Name)@$($pk.Version)"] = [PSCustomObject]@{ Name=$pk.Name; Version=$pk.Version; Reason="removed stale duplicate of '$($g.Name)', reinstalling canonical asset" }
            } else {
                Write-Log INFO "Handled duplicate of '$($g.Name)'; canonical is title-owned only, no id-level package attribution for reinstall."
            }
        }
        elseif ($ownedManaged.Count -eq 0 -and $managedInGroup.Count -gt 1) {
            # Managed copies, none owned by id OR title — not a known package asset. Don't guess.
            Write-Log WARN "Duplicate '$($g.Name)': managed copies but not package-owned by id or title — cannot auto-pick canonical. Reporting only."
        }

        $canonical = $ownedManaged

        # Non-managed (user-created) duplicates — only ever delete DASHBOARDS, and only when
        # explicitly enabled. Other types are left untouched regardless of the toggle.
        if ($DeleteOrphanDuplicates) {
            $userDashCopies = @($g.Group | Where-Object { -not $_.managed -and $_.type -eq 'dashboard' })
            # If a managed canonical exists, all user dashboard copies are deletable; else keep the oldest one.
            $skip = if ($canonical.Count -ge 1) { 0 } else { 1 }
            foreach ($d in @($userDashCopies | Select-Object -Skip $skip)) {
                Write-Log WARN "Deleting non-managed duplicate [$($d.type)/$($d.id)] '$($d.title)'"
                Remove-KibanaObject -Type $d.type -Id $d.id -SpaceId $sid
            }
        }
    }

    # ── 3b. Orphaned integration DASHBOARDS (package uninstalled) ────────────
    # Delete a saved object ONLY when ALL of these hold:
    #   • it is a dashboard (we never delete index-patterns, tags, data views, etc.)
    #   • it is managed
    #   • its id is "<pkg>-<uuid>" where <pkg> is a REAL package name (one that has
    #     appeared as an installed package at some point, tracked in $KnownPackageNames)
    #   • that package <pkg> is NOT in the currently-installed set
    #   • its title is not still package-owned (i.e. not a live copy)
    #
    # The earlier id-prefix-split approach was unsafe: it invented packages from reserved
    # namespaces ("fleet-managed" -> "fleet", "security-solution" -> "security") and would
    # have deleted base data views (logs-*, metrics-*). Scoping to dashboards + matching
    # against real package names + an explicit reserved-namespace denylist removes that risk.
    Write-Log INFO "Checking for orphaned integration dashboards (uninstalled packages)..."

    $uuidRegex = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    foreach ($o in @($objects | Where-Object { $_.type -eq 'dashboard' -and $_.managed })) {
        if (-not $DeleteOrphanDashboards) { break }
        if ($o.id -match $uuidRegex) { continue }   # bare uuid copy — not package-namespaced

        # id must be "<pkg>-<uuid>"; extract the candidate package name and the uuid tail.
        if ($o.id -notmatch "^(?<pkg>[a-z0-9_]+)-(?<uuid>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$") { continue }
        $pkg = $Matches['pkg']

        # Must be a package name we have actually observed as installed (now or earlier in
        # this run). This is what rejects "fleet", "security", "logs", "metrics" — none of
        # which are real packages — instead of trusting an arbitrary id prefix.
        if (-not $KnownPackageNames.Contains($pkg)) { continue }

        # If that package is still installed, the dashboard is not orphaned.
        if ($installedNames -contains $pkg) { continue }

        # If the title still maps to a live package asset, it's a copy, not an orphan.
        if ($ownedTitles.Contains("dashboard::$($o.title)")) {
            Write-Log INFO "Skipping dashboard [$($o.id)] '$($o.title)': package '$pkg' not installed but title still package-owned (likely a copy)."
            continue
        }

        Write-Log WARN "Orphaned dashboard in space '$label': [$($o.id)] '$($o.title)' — package '$pkg' is not installed. Deleting."
        Remove-KibanaObject -Type "dashboard" -Id $o.id -SpaceId $sid
    }

    # ── 3c. Stale assets of INSTALLED opted-in packages (removed in newer version) ──
    # For each package in $EnforceManifestPackages that IS installed: delete managed dashboards
    # whose id is "<pkg>-<uuid>" but is NOT in that package's current installed_kibana — i.e. a
    # dashboard a newer package version dropped. Strictly opt-in (you control these manifests).
    # Get-PackageDashboardIds returns $null for an empty/partial manifest, which disables
    # enforcement for that package (never delete everything on a bad read).
    if ($EnforceManifestPackages.Count -gt 0) {
        Write-Log INFO "Checking manifest enforcement for: $($EnforceManifestPackages -join ', ')"
        foreach ($enfPkg in $EnforceManifestPackages) {
            if ($installedNames -notcontains $enfPkg) {
                Write-Log INFO "Manifest-enforce: '$enfPkg' is not installed — handled by orphan rule, skipping enforcement."
                continue
            }
            $currentIds = Get-PackageDashboardIds -PackageName $enfPkg
            if ($null -eq $currentIds) { continue }   # empty/partial manifest guard tripped

            $prefix = "$enfPkg-"
            foreach ($o in @($objects | Where-Object { $_.type -eq 'dashboard' -and $_.managed })) {
                if (-not $o.id.StartsWith($prefix)) { continue }
                # id is owned by this package's namespace; is it still in the current manifest?
                if ($currentIds.Contains($o.id)) { continue }   # still shipped — keep

                # Stale: package-namespaced for an installed package but absent from its manifest.
                Write-Log WARN "Stale dashboard in space '$label': [$($o.id)] '$($o.title)' — no longer shipped by installed package '$enfPkg'. Deleting."
                Remove-KibanaObject -Type "dashboard" -Id $o.id -SpaceId $sid
            }
        }
    }

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
