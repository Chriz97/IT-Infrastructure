# Simple Active Directory Management Script
# Note: This script requires the Active Directory module for PowerShell.
# Ensure you have the necessary permissions to manage AD objects before running.

# This script has been verified on a Windows Server 2025 Domain Controller in an Active Directory environment. (Testlab)

# Import the Active Directory module
Import-Module ActiveDirectory

# Step 1: Create a New User in the Users container
$UserName = "jdoe"
$FullName = "John Doe"
$Password = ConvertTo-SecureString "C0mpl3xP@ssw0rd!" -AsPlainText -Force  # Complex password to meet AD requirements
New-ADUser -Name $FullName -GivenName "John" -Surname "Doe" -SamAccountName $UserName `
           -UserPrincipalName "$UserName@testlab.local" -Path "CN=Users,DC=testlab,DC=local" `
           -AccountPassword $Password -Enabled $true
Write-Host "Created new user: $FullName"

# Step 2: Check if "IT Department" group exists, create it if not
$GroupName = "IT Department"
if (-not (Get-ADGroup -Filter { Name -eq $GroupName })) {
    New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path "CN=Users,DC=testlab,DC=local"
    Write-Host "Created new group: $GroupName"
}

# Add the User to the Group
Add-ADGroupMember -Identity $GroupName -Members $UserName
Write-Host "Added $FullName to group: $GroupName"

# Step 3: Reset the User Password
$NewPassword = ConvertTo-SecureString "N3wC0mpl3xP@ssw0rd!" -AsPlainText -Force
Set-ADAccountPassword -Identity $UserName -NewPassword $NewPassword -Reset
Write-Host "Password reset for user: $FullName"
