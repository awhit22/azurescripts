####################################################################################################################################################
# CREATE AN AZURE VM WIHT A CUSTOM VHD UPLOADED FROM LOCAL MACHINE
# Originally Created by Adam Whitlatch  Adam.Whitlatch@microsoft.com
# April 10, 2019 
# Code Snippets taken from
#    https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-create-managed-disk-from-vhd
#    https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-create-vm-from-managed-os-disks?toc=%2fpowershell%2fmodule%2ftoc.json
#    https://github.com/Azure-Samples/managed-disks-powershell-getting-started/blob/master/CreateVmFromManagedOsDisk.ps1
# 
# Azure Resources Needed
#   1: Storage Account and container
#   2: Azure Login Credentials with rights to create storage object, disk images, and VMs
#   3: Network & Security pre-configured
#   4: Resource Group pre-configured
#  
# Step 0: Create Custom VHD in Hyper-v or other Hypervisor - Conver Image to vhd format 
#         Upload Custom VHD to Azure  (Option 2:  Copy vhd from previously uploaded disk to new file (faster))    
# Step 1: Create Managed Disk from VHD
# Step 2: Create Customized VM with uploaded VHD   
#  
# 
####################################################################################################################################################



$destresourceGroup = 'rg-bt01'                                 # Provide the name of the VM Destination Resource Group - Where VM will be created
$VHDdestresourceGroup = 'rg-bt01'                              # Provide the name of your resource group where Managed Disks will be created. 
$location = 'eastus'                                           # Provide teh Azure Region for VM and Managed disk #This location should be same as the storage account where VHD file is stored  using command below:
                                                               # Get all the Azure location   #Get-AzLocation
$storageaccount = 'your storage acocunt'                       # Provide the Azure Sotrage Account
$vhdlocalPath = 'C:\temp\pfSense\pfsensefromvmdk.vhd'          # Provide the path to local Image
$vhd1remotePath = 'https://<stoageacocunt>.blob.core.windows.net/images2/pfsensefromvmdk.vhd'        # Provide the path to new vhd - include name of new VHD
$vmName = 'vm-<name>'                                          # Provide Name for new VM
$vhdName = 'pfsensefromvmdk.vhd'                               # Provide of the VHD Image
$subnet1Name = 'external'                                      # Provide subnet1 name for the new VM
$subnet2Name = 'internal'                                      # Provide subnet2 name for the new VM
$vnetName = 'vn-<name>'                                        # Provide VnetName for new VM
$nicName = 'nic-<name>-01'                                     # Provide nic1 name for new VM
$nicName2 = 'nic-<name>-02'                                    # Provide nic2 name for new VM
$nsgName = 'nsg-<name>'                                        # Provide nsg name for new VM
$vmName = 'vm-<name>'                                          # Provide VnetName for new VM
$vmSize = 'Standard_DS1_v2'                                    # Provide the size of Azure VM  
                                                               # Get all the vm sizes in a region using below script:   #e.g. Get-AzVMSize -Location westus
$subscriptionId = 'a1234z2z-75e8-4c81-bcee-125585462146'       # Provide the subscription Id where Managed Disks will be created
$diskName = 'pfSense04092019'                                  # Provide the name of the Managed Disk- Must be different for each image
$diskSize = '8'                                                # Provide the size of the disks in GB. It should be greater than the VHD file size.
$storageType = 'Standard_LRS'                                  # Provide the storage type for Managed Disk. Premium_LRS or Standard_LRS.



##############################
##                          ##
##  Step #0 - Upload Image  ##
##                          ##
##############################

# Upload SourceImage File
Add-AzVhd -Destination $vhd1remotePath -ResourceGroupName $VHDresourceGroup -LocalFilePath $vhdlocalPath

# Note: Uploading the VHD may take awhile


#####################################
##                                 ##
##  Step #1 - Create Managed Disk  ##
##                                 ##
#####################################

#Provide the resource Id of the storage account where VHD file is stored.
#e.g. /subscriptions/6472s1g8-h217-446b-b509-314e17e1efb0/resourceGroups/MDDemo/providers/Microsoft.Storage/storageAccounts/contosostorageaccount
#This is an optional parameter if you are creating managed disk in the same subscription
#$storageAccountId = '/subscriptions/yourSubscriptionId/resourceGroups/yourResourceGroupName/providers/Microsoft.Storage/storageAccounts/yourStorageAccountName'

#Set the context to the subscription Id where Managed Disk will be created
Select-AzSubscription -SubscriptionId $SubscriptionId

$diskConfig = New-AzDiskConfig -AccountType $storageType -Location $location -CreateOption Import -StorageAccountId $storageAccountId -SourceUri $vhd1remotePath

New-AzDisk -Disk $diskConfig -ResourceGroupName $VHDdestresourceGroup -DiskName $diskName


########################################
##                                    ##
##  Step #2 - Create Virtual Machine  ##
##                                    ##
########################################

#Initialize virtual machine configuration
$VirtualMachine = New-AzVMConfig -VMName $vmName -VMSize $vmSize

#Get the Managed Disk based on the resource group and the disk name
$disk =  Get-AzDisk -ResourceGroupName $VHDdestresourceGroup -DiskName $diskName

#Use the Managed Disk Resource Id to attach it to the virtual machine. Change the OS type to Windows if OS disk has Windows OS
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Linux -ManagedDiskId $disk.Id -CreateOption Attach 

#Create a public IP for the VM  
#$publicIp = New-AzureRmPublicIpAddress -Name ($VirtualMachineName.ToLower()+'_ip') -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic

#Get the virtual network where virtual machine will be hosted
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $VHDdestresourceGroup

# Create NIC in the first subnet of the virtual network 
$nic1 = New-AzureRmNetworkInterface -Name ('nic-'+ $vmName.ToLower()+'-01') -ResourceGroupName $VHDdestresourceGroup -Location $location -SubnetId $vnet.Subnets[0].Id

# Create NIC in the Second subnet of the virtual network 
$nic2 = New-AzureRmNetworkInterface -Name ('nic-'+ $vmName.ToLower()+'-02') -ResourceGroupName $VHDdestresourceGroup -Location $location -SubnetId $vnet.Subnets[1].Id

$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic1.Id
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic2.Id -Primary

#Create the virtual machine with Managed Disk
New-AzVM -VM $VirtualMachine -ResourceGroupName $destresourceGroup -Location $location

$vmList = Get-AzVM -ResourceGroupName $destresourceGroup
$vmList.Name