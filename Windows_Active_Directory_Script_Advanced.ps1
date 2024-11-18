# Advanced Active Directory Management Script
# Note: This script requires the Active Directory module for PowerShell.
# Ensure you have the necessary permissions to manage AD objects before running.

# This script has been verified on a Windows Server 2025 Domain Controller in an Active Directory environment (Testlab).

# Import the Active Directory module
Import-Module ActiveDirectory

# Step 1: Create a New Organizational Unit (OU) if it doesn't exist
$OUName = "IT Department"
$OUPath = "OU=$OUName,DC=testlab,DC=local"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$OUName'")) {
    New-ADOrganizationalUnit -Name $OUName -Path "DC=testlab,DC=local"
    Write-Host "Created new Organizational Unit: $OUName"
} else {
    Write-Host "Organizational Unit '$OUName' already exists."
}

# Step 2: Create a New User in the "IT Department" OU
$UserName = "adoe"
$FullName = "Alice Doe"
$Password = ConvertTo-SecureString "C0mpl3xP@ssw0rd!" -AsPlainText -Force  # Complex password to meet AD requirements
New-ADUser -Name $FullName -GivenName "Alice" -Surname "Doe" -SamAccountName $UserName `
           -UserPrincipalName "$UserName@testlab.local" -Path $OUPath `
           -AccountPassword $Password -Enabled $true
Write-Host "Created new user: $FullName in OU: $OUName"

# Step 3: Add the User to an Existing Group
$GroupName = "Admins"
if (Get-ADGroup -Filter { Name -eq $GroupName }) {
    Add-ADGroupMember -Identity $GroupName -Members $UserName
    Write-Host "Added $FullName to group: $GroupName"
} else {
    Write-Host "Group '$GroupName' does not exist. Please create it first."
}

# Step 4: List Members of a Group
Write-Host "Listing members of group '$GroupName':"
Get-ADGroupMember -Identity $GroupName | ForEach-Object {
    Write-Host $_.Name
}

# Step 5: Disable an Inactive User Account
$InactiveUser = "jdoe"
Disable-ADAccount -Identity $InactiveUser
Write-Host "Disabled user account: $InactiveUser"

# Step 6: Remove a User from a Group
$UserToRemove = "adoe"
Remove-ADGroupMember -Identity $GroupName -Members $UserToRemove -Confirm:$false
Write-Host "Removed $FullName from group: $GroupName"

# Step 7: Delete a User Account
$UserToDelete = "adoe"
Remove-ADUser -Identity $UserToDelete -Confirm:$false
Write-Host "Deleted user account: $UserToDelete"
