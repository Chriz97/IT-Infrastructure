# Simple Active Directory Management Script
# Note: This script requires the Active Directory module for PowerShell.
# Ensure you have the necessary permissions to manage AD objects before running.

# This script has been verified on a Windows Server 2025 Domain Controller in an Active Directory environment. (Testlab)

# Import the Active Directory module
Import-Module ActiveDirectory

# Define Users and Departments
$Users = @(
    @{ UserName = "jdoe"; FullName = "John Doe"; GivenName = "John"; Surname = "Doe"; Departments = @("IT Department") },
    @{ UserName = "asmith"; FullName = "Alice Smith"; GivenName = "Alice"; Surname = "Smith"; Departments = @("IT Department", "IT Project Management") },
    @{ UserName = "bwilliams"; FullName = "Bob Williams"; GivenName = "Bob"; Surname = "Williams"; Departments = @("IT Department") },
    @{ UserName = "cmartin"; FullName = "Cindy Martin"; GivenName = "Cindy"; Surname = "Martin"; Departments = @("IT Project Management") }
)

# Create groups if they do not exist
$Groups = @("IT Department", "IT Project Management")
foreach ($Group in $Groups) {
    if (-not (Get-ADGroup -Filter { Name -eq $Group })) {
        New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security -Path "CN=Users,DC=testlab,DC=local"
        Write-Host "Created new group: $Group"
    }
}

# Create Users and Assign Groups
foreach ($User in $Users) {
    $UserName = $User.UserName
    $FullName = $User.FullName
    $GivenName = $User.GivenName
    $Surname = $User.Surname
    $Departments = $User.Departments

    # Generate a secure default password
    $Password = ConvertTo-SecureString "C0mpl3xP@ssw0rd!" -AsPlainText -Force

    # Create the user
    if (-not (Get-ADUser -Filter { SamAccountName -eq $UserName })) {
        New-ADUser -Name $FullName -GivenName $GivenName -Surname $Surname -SamAccountName $UserName `
                   -UserPrincipalName "$UserName@testlab.local" -Path "CN=Users,DC=testlab,DC=local" `
                   -AccountPassword $Password -Enabled $true
        Write-Host "Created new user: $FullName"
    } else {
        Write-Host "User $FullName already exists. Skipping creation."
    }

    # Add the user to specified groups
    foreach ($Department in $Departments) {
        Add-ADGroupMember -Identity $Department -Members $UserName
        Write-Host "Added $FullName to group: $Department"
    }

    # Reset the user password to a new secure one
    $NewPassword = ConvertTo-SecureString "N3wC0mpl3xP@ssw0rd!" -AsPlainText -Force
    Set-ADAccountPassword -Identity $UserName -NewPassword $NewPassword -Reset
    Write-Host "Password reset for user: $FullName"
}
