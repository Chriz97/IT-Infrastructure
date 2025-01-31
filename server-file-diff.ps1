###############################################################################
# Define the paths to the old and new Apache installations
###############################################################################
$oldApachePath = "C:\Users\Christoph\Pictures\httpd-2.4.63-250122-win64-VS17"
$newApachePath = "C:\Users\Christoph\Documents\httpd-2.4.63-250122-win64-VS17"

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
        $folderDiff | Format-Table -AutoSize
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
    $oldConfigFiles = Get-ChildItem -Path $oldApachePath -Recurse -Filter "*.conf" -Attributes !Hidden -File
    $newConfigFiles = Get-ChildItem -Path $newApachePath -Recurse -Filter "*.conf" -Attributes !Hidden -File

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

Write-Host "`nComparison complete."
