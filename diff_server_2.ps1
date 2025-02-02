###############################################################################
# Define the paths to the old and new Apache installations
###############################################################################
$oldApachePath = "C:\Users\Christoph\Documents\PHP Test\httpd_old"
$newApachePath = "C:\Users\Christoph\Documents\PHP Test\httpd_new"

###############################################################################
# Function: Compare-FileContent using Hashing (SHA256)
###############################################################################
function Compare-FileContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OldFile,

        [Parameter(Mandatory=$true)]
        [string]$NewFile
    )

    # Compute SHA256 hashes for more reliable comparison
    $oldHash = Get-FileHash -Algorithm SHA256 -Path $OldFile | Select-Object -ExpandProperty Hash
    $newHash = Get-FileHash -Algorithm SHA256 -Path $NewFile | Select-Object -ExpandProperty Hash

    if ($oldHash -ne $newHash) {
        return $true  # Content differs
    } else {
        return $false  # No difference
    }
}

###############################################################################
# Function: Get-RelativePath (Ensures consistent path comparison)
###############################################################################
function Get-RelativePath {
    param(
        [string]$FullPath,
        [string]$BasePath
    )
    return $FullPath.Substring($BasePath.Length).TrimStart("\")
}

###############################################################################
# 1) Compare Folder Structure
###############################################################################
Write-Host "`n=== Comparing folder structures... ==="

try {
    $oldItems = Get-ChildItem -Path $oldApachePath -Recurse -Attributes !Hidden -File
    $newItems = Get-ChildItem -Path $newApachePath -Recurse -Attributes !Hidden -File

    $oldRelativePaths = $oldItems | ForEach-Object { Get-RelativePath $_.FullName $oldApachePath }
    $newRelativePaths = $newItems | ForEach-Object { Get-RelativePath $_.FullName $newApachePath }

    $folderDiff = Compare-Object -ReferenceObject $oldRelativePaths -DifferenceObject $newRelativePaths

    if ($folderDiff) {
        Write-Host "Folder differences found:"
        $folderDiff | ForEach-Object {
    	if ($_.SideIndicator -eq '=>') {
        	Write-Host "New file added in the new installation: $($_.InputObject)"
    	} elseif ($_.SideIndicator -eq '<=') {
       		Write-Host "File removed from the old installation: $($_.InputObject)"
    }
}
    } else {
        Write-Host "No folder differences found."
    }
}
catch {
    Write-Warning "Error accessing the directories. Check paths and permissions."
}

###############################################################################
# 2) Compare Configuration Files (*.conf)
###############################################################################
Write-Host "`n=== Comparing configuration files... ==="

try {
    $oldConfigFiles = Get-ChildItem -Path $oldApachePath -Recurse -Include "*.conf", "*.cnf" -Attributes !Hidden -File
    $newConfigFiles = Get-ChildItem -Path $newApachePath -Recurse -Include "*.conf", "*.cnf" -Attributes !Hidden -File


    $configDiff = @()

    foreach ($oldFile in $oldConfigFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath

        $newFile = $newConfigFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $configDiff += [pscustomobject]@{
                FileName    = $relativePath
                Difference  = "File only exists in old installation"
            }
        }
        else {
            if (Compare-FileContent -OldFile $oldFile.FullName -NewFile $newFile.FullName) {
                $configDiff += [pscustomobject]@{
                    FileName    = $relativePath
                    Difference  = 'Content differs'
                }
            }
        }
    }

    foreach ($newFile in $newConfigFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldConfigFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $configDiff += [pscustomobject]@{
                FileName    = $relativePath
                Difference  = "File only exists in new installation"
            }
        }
    }

    if ($configDiff) {
        Write-Host "Configuration file differences found:"
        $configDiff | Format-Table -AutoSize
    } else {
        Write-Host "No configuration file differences found."
    }
}
catch {
    Write-Warning "Error accessing the configuration files. Check paths and permissions."
}

###############################################################################
# 3) Compare PHP Files (*.php)
###############################################################################
Write-Host "`n=== Comparing PHP files... ==="

try {
    $oldPhpFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.php" -Attributes !Hidden -File
    $newPhpFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.php" -Attributes !Hidden -File

    $phpDiff = @()

    foreach ($oldFile in $oldPhpFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newPhpFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $phpDiff += [pscustomobject]@{
                FileName    = $relativePath
                Difference  = "File only exists in old installation"
            }
        }
        else {
            if (Compare-FileContent -OldFile $oldFile.FullName -NewFile $newFile.FullName) {
                $phpDiff += [pscustomobject]@{
                    FileName    = $relativePath
                    Difference  = "Content differs"
                }
            }
        }
    }

    foreach ($newFile in $newPhpFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldPhpFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $phpDiff += [pscustomobject]@{
                FileName    = $relativePath
                Difference  = "File only exists in new installation"
            }
        }
    }

    if ($phpDiff) {
        Write-Host "PHP file differences found:"
        $phpDiff | Format-Table -AutoSize
    } else {
        Write-Host "No PHP file differences found."
    }
}
catch {
    Write-Warning "Error accessing the PHP files. Check paths and permissions."
}

###############################################################################
# 4) Compare INI Files (*.ini)
###############################################################################
Write-Host "`n=== Comparing INI files... ==="

try {
    $oldIniFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.ini" -Attributes !Hidden -File
    $newIniFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.ini" -Attributes !Hidden -File

    $iniDiff = @()

    foreach ($oldFile in $oldIniFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newIniFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $iniDiff += [pscustomobject]@{
                FileName    = $relativePath
                Difference  = "File only exists in old installation"
            }
        }
        else {
            if (Compare-FileContent -OldFile $oldFile.FullName -NewFile $newFile.FullName) {
                $iniDiff += [pscustomobject]@{
                    FileName    = $relativePath
                    Difference  = "Content differs"
                }
            }
        }
    }

    if ($iniDiff) {
        Write-Host "INI file differences found:"
        $iniDiff | Format-Table -AutoSize
    } else {
        Write-Host "No INI file differences found."
    }
}
catch {
    Write-Warning "Error accessing the INI files. Check paths and permissions."
}

###############################################################################
# 5) Compare DLL Files (*.dll) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing DLL files... ==="

try {
    $oldDllFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.dll" -Attributes !Hidden -File
    $newDllFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.dll" -Attributes !Hidden -File

    $dllDiff = @()

    foreach ($oldFile in $oldDllFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newDllFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $dllDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $dllDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newDllFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldDllFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $dllDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($dllDiff) {
        Write-Host "`n=== DLL file differences found ==="
        foreach ($diff in $dllDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No DLL file differences found."
    }
}
catch {
    Write-Warning "Error accessing the DLL files. Check paths and permissions."
}
###############################################################################
# 6) Compare LIB Files (*.lib) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing LIB files... ==="

try {
    $oldLibFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.lib" -Attributes !Hidden -File
    $newLibFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.lib" -Attributes !Hidden -File

    $libDiff = @()

    foreach ($oldFile in $oldLibFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newLibFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $libDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $libDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newLibFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldLibFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $libDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($libDiff) {
        Write-Host "`n=== LIB file differences found ==="
        foreach ($diff in $libDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No LIB file differences found."
    }
}
catch {
    Write-Warning "Error accessing the LIB files. Check paths and permissions."
}
###############################################################################
# 7) Compare BAT Files (*.bat) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing BAT files... ==="

try {
    $oldBatFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.bat" -Attributes !Hidden -File
    $newBatFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.bat" -Attributes !Hidden -File

    $batDiff = @()

    foreach ($oldFile in $oldBatFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newBatFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $batDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $batDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newBatFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldBatFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $batDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($batDiff) {
        Write-Host "`n=== BAT file differences found ==="
        foreach ($diff in $batDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No BAT file differences found."
    }
}
catch {
    Write-Warning "Error accessing the BAT files. Check paths and permissions."
}
################################################################################
# 9) Compare SO Files (*.so) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing SO files... ==="

try {
    $oldSoFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.so" -Attributes !Hidden -File
    $newSoFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.so" -Attributes !Hidden -File

    $soDiff = @()

    foreach ($oldFile in $oldSoFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newSoFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $soDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $soDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newSoFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldSoFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $soDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($soDiff) {
        Write-Host "`n=== SO file differences found ==="
        foreach ($diff in $soDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No SO file differences found."
    }
}
catch {
    Write-Warning "Error accessing the SO files. Check paths and permissions."
}
###############################################################################
# 10) Compare YAML Files (*.yaml and *.yml) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing YAML files... ==="

try {
    $oldYamlFiles = Get-ChildItem -Path $oldApachePath -Recurse -Include "*.yaml", "*.yml" -Attributes !Hidden -File
    $newYamlFiles = Get-ChildItem -Path $newApachePath -Recurse -Include "*.yaml", "*.yml" -Attributes !Hidden -File

    $yamlDiff = @()

    foreach ($oldFile in $oldYamlFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newYamlFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $yamlDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $yamlDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newYamlFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldYamlFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $yamlDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($yamlDiff) {
        Write-Host "`n=== YAML file differences found ==="
        foreach ($diff in $yamlDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No YAML file differences found."
    }
}
catch {
    Write-Warning "Error accessing the YAML files. Check paths and permissions."
}

###############################################################################
# 11) Compare VAR Files (*.var) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing VAR files... ==="

try {
    $oldVarFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.var" -Attributes !Hidden -File
    $newVarFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.var" -Attributes !Hidden -File

    $varDiff = @()

    foreach ($oldFile in $oldVarFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newVarFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $varDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $varDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newVarFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldVarFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $varDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($varDiff) {
        Write-Host "`n=== VAR file differences found ==="
        foreach ($diff in $varDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No VAR file differences found."
    }
}
catch {
    Write-Warning "Error accessing the VAR files. Check paths and permissions."
}
###############################################################################
# 12) Compare Header Files (*.h) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing Header files... ==="

try {
    $oldHeaderFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.h" -Attributes !Hidden -File
    $newHeaderFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.h" -Attributes !Hidden -File

    $headerDiff = @()

    foreach ($oldFile in $oldHeaderFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newHeaderFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $headerDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $headerDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newHeaderFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldHeaderFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $headerDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($headerDiff) {
        Write-Host "`n=== Header file differences found ==="
        foreach ($diff in $headerDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No Header file differences found."
    }
}
catch {
    Write-Warning "Error accessing the Header files. Check paths and permissions."
}

Write-Host "`nComparison complete."
###############################################################################
# Ask for Confirmation Before Copying
###############################################################################
Write-Host "`n=== Copying missing and modified files to the new installation... ==="

# Prompt user for confirmation
$response = Read-Host "Do you want to proceed with copying missing and modified files? (yes/no)"
if ($response -ne "yes") {
    Write-Host "Copying aborted by the user."
    return  # Exit the script or skip copying
}

Write-Host "Proceeding with copying files..."
###############################################################################
# Copy Missing or Modified Files to New Installation
###############################################################################
Write-Host "`n=== Copying missing and modified files to the new installation... ==="

function Copy-File {
    param(
        [string]$Source,
        [string]$Destination
    )
    try {
        Copy-Item -Path $Source -Destination $Destination -Force
        Write-Host "Copied: $Source -> $Destination"
    }
    catch {
        Write-Warning "Failed to copy: $Source -> $Destination"
    }
}

# Copy missing folders/files
foreach ($diff in $folderDiff) {
    if ($diff.SideIndicator -eq "<=") {
        $sourcePath = Join-Path -Path $oldApachePath -ChildPath $diff.InputObject
        $destinationPath = Join-Path -Path $newApachePath -ChildPath $diff.InputObject

        # Create directory if needed
        $destinationDir = Split-Path -Path $destinationPath -Parent
        if (-not (Test-Path -Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir | Out-Null
        }

        # Copy missing file or folder
        Copy-File -Source $sourcePath -Destination $destinationPath
    }
}

# Overwrite modified YAML files
foreach ($diff in $yamlDiff) {
    if ($diff.Difference -eq "Content differs" -or $diff.Difference -eq "File only exists in old installation") {
        $sourcePath = Join-Path -Path $oldApachePath -ChildPath $diff.FileName
        $destinationPath = Join-Path -Path $newApachePath -ChildPath $diff.FileName

        # Create directory if needed
        $destinationDir = Split-Path -Path $destinationPath -Parent
        if (-not (Test-Path -Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir | Out-Null
        }

        # Copy YAML file
        Copy-File -Source $sourcePath -Destination $destinationPath
    }
}
# Overwrite modified config and ini files
$configAndIniDiffs = $configDiff + $iniDiff
foreach ($diff in $configAndIniDiffs) {
    if ($diff.Difference -eq "Content differs") {
        $sourcePath = Join-Path -Path $oldApachePath -ChildPath $diff.FileName
        $destinationPath = Join-Path -Path $newApachePath -ChildPath $diff.FileName

        # Overwrite file
        Copy-File -Source $sourcePath -Destination $destinationPath
    }
}

Write-Host "`n=== Copying complete. ==="
