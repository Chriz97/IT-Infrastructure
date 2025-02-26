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
###############################################################################
# 8) Compare EXE Files (*.exe) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing EXE files... ==="

try {
    $oldExeFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.exe" -Attributes !Hidden -File
    $newExeFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.exe" -Attributes !Hidden -File

    $exeDiff = @()

    foreach ($oldFile in $oldExeFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newExeFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $exeDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $exeDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newExeFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldExeFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $exeDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($exeDiff) {
        Write-Host "`n=== EXE file differences found ==="
        foreach ($diff in $exeDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No EXE file differences found."
    }
}
catch {
    Write-Warning "Error accessing the EXE files. Check paths and permissions."
}
###############################################################################
# 9) Compare Shell Script Files (*.sh) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing Shell Script files... ==="

try {
    $oldShFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.sh" -Attributes !Hidden -File
    $newShFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.sh" -Attributes !Hidden -File

    $shDiff = @()

    foreach ($oldFile in $oldShFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newShFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $shDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $shDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newShFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldShFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $shDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($shDiff) {
        Write-Host "`n=== Shell Script file differences found ==="
        foreach ($diff in $shDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No Shell Script file differences found."
    }
}
catch {
    Write-Warning "Error accessing the Shell Script files. Check paths and permissions."
}
###############################################################################
# 10) Compare SO Files (*.so) using SHA256 Hash
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
# 12) Compare HTML Files (*.html) using SHA256 Hash
###############################################################################
Write-Host "`n=== Comparing HTML files... ==="

try {
    $oldHtmlFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.html" -Attributes !Hidden -File
    $newHtmlFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.html" -Attributes !Hidden -File

    $htmlDiff = @()

    foreach ($oldFile in $oldHtmlFiles) {
        $relativePath = Get-RelativePath $oldFile.FullName $oldApachePath
        $newFile = $newHtmlFiles | Where-Object { (Get-RelativePath $_.FullName $newApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $newFile) {
            $htmlDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in old installation"
            }
        }
        else {
            $oldHash = Get-FileHash -Algorithm SHA256 -Path $oldFile.FullName | Select-Object -ExpandProperty Hash
            $newHash = Get-FileHash -Algorithm SHA256 -Path $newFile.FullName | Select-Object -ExpandProperty Hash

            if ($oldHash -ne $newHash) {
                $htmlDiff += [pscustomobject]@{
                    FileName   = $relativePath
                    Difference = "Content differs"
                    OldSHA256  = $oldHash
                    NewSHA256  = $newHash
                }
            }
        }
    }

    foreach ($newFile in $newHtmlFiles) {
        $relativePath = Get-RelativePath $newFile.FullName $newApachePath
        $oldFile = $oldHtmlFiles | Where-Object { (Get-RelativePath $_.FullName $oldApachePath) -eq $relativePath } | Select-Object -First 1

        if ($null -eq $oldFile) {
            $htmlDiff += [pscustomobject]@{
                FileName   = $relativePath
                Difference = "File only exists in new installation"
            }
        }
    }

    if ($htmlDiff) {
        Write-Host "`n=== HTML file differences found ==="
        foreach ($diff in $htmlDiff) {
            if ($diff.PSObject.Properties.Name -contains "OldSHA256") {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
                Write-Host "    Old SHA256: $($diff.OldSHA256)"
                Write-Host "    New SHA256: $($diff.NewSHA256)"
            } else {
                Write-Host "$($diff.FileName) - $($diff.Difference)"
            }
        }
    } else {
        Write-Host "No HTML file differences found."
    }
}
catch {
    Write-Warning "Error accessing the HTML files. Check paths and permissions."
}
###############################################################################
# 13) Compare Header Files (*.h) using SHA256 Hash
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
