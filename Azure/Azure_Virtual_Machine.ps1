# Azure Virtual Machine Management Script
# This script includes commands to create, configure, and manage Azure VMs.

# Login to Azure Account
# Ensure you are authenticated with Azure before running commands.
Write-Host "Logging in to Azure..."
Connect-AzAccount

# Set Variables
$resourceGroupName = "MyResourceGroup"
$location = "East US"
$vmName = "MyVM"
$image = "UbuntuLTS"
$adminUsername = "azureuser"
$password = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
$vmSize = "Standard_DS1_v2"
$subnetName = "MySubnet"
$vnetName = "MyVNet"
$publicIpName = "MyPublicIP"
$nsgName = "MyNSG"

# Step 1: Create a Resource Group
Write-Host "Creating Resource Group..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Step 2: Create a Virtual Network and Subnet
Write-Host "Creating Virtual Network and Subnet..."
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location `
  -Name $vnetName -AddressPrefix "10.0.0.0/16"

Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Step 3: Create a Public IP Address
Write-Host "Creating Public IP Address..."
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location `
  -Name $publicIpName -AllocationMethod Dynamic

# Step 4: Create a Network Security Group (NSG) and Add Rules
Write-Host "Creating Network Security Group and Adding Rules..."
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location `
  -Name $nsgName -SecurityRules @(
    New-AzNetworkSecurityRuleConfig -Name "AllowSSH" -Description "Allow SSH" `
      -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix "*" `
      -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 22
)

# Step 5: Create a Network Interface
Write-Host "Creating Network Interface..."
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location `
  -Name "$vmName-NIC" -SubnetId $subnet.Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

# Step 6: Create a Virtual Machine
Write-Host "Creating Virtual Machine..."
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize `
  | Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential (New-Object PSCredential ($adminUsername, $password)) `
  | Set-AzVMSourceImage -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "18.04-LTS" -Version "latest" `
  | Add-AzVMNetworkInterface -Id $nic.Id

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

Write-Host "Virtual Machine Created Successfully!"

# Step 7: Start, Stop, and Deallocate the VM
# Start the VM
Write-Host "Starting the Virtual Machine..."
Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

# Stop the VM
Write-Host "Stopping the Virtual Machine..."
Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

# Deallocate the VM (stop and release the resources)
Write-Host "Deallocating the Virtual Machine..."
Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Deallocate -Force

# Step 8: Delete the Virtual Machine
# Uncomment the following line to delete the VM and its associated resources.
# Write-Host "Deleting the Virtual Machine..."
# Remove-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

Write-Host "Azure Virtual Machine Script Completed."
