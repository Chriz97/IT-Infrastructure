az login
az group create --name MyResourceGroup --location eastus
az vm create --resource-group MyResourceGroup --name MyVirtualMachine --image UbuntuLTS
