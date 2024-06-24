<#PSScriptInfo
.AUTHOR Catherine Demesa
.COMPANYNAME 
.COPYRIGHT (c) 2023 Catherine Demesa. All rights reserved.
.TAGS Windows PowerShell Azure AzureVM AzureManagedDisk AzureUnmanagedDisk AzureDataDisk AzureStorage
.ICONURL 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 This script increases the Data Disk Size for an Azure RM VM.
#> 

<#
.SYNOPSIS 
   This will increase the size of the data disk on Azure RM VM.

.DESCRIPTION
    This Script lets you increase your Data Disk size for your VM. Data Disk Size reduction is not supported by Azure. It 
    supports Data Disk resizing for Managed + Unmanaged disks. 

.PARAMETER ResourceGroupName
    The specific name of the Resource Group containing the VM, in which it has Data Disk you want to resize

.PARAMETER VMName    
    Defines the name of the VM itself

.PARAMETER DataDiskName
    This defines Name of the existing Data Disk attached to the VM

.PARAMETER NewDataDiskSize    
    Defines a custom ew Size of the disk

.EXAMPLE
    .\Expand-AzureRMVMDataDisk -ResourceGroupName "RG1" -VMName "VM01" -DataDiskName "disk1234" -NewDataDiskSize 1023 
    
.Notes
    Author: Catherine Demesa
    Creation Date: 15/Jun/2023
    Last Revision Date: 23/Jun/2023
    Development Environment: VS Code IDE
    Platform: Windows
#>
[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName,

    [Parameter(Mandatory=$true)] 
    [String]$DataDiskName,

    [Parameter(Mandatory=$true)]
    [ValidateRange(30,4095)]
    [int]$NewDataDiskSize
)

if (!(Get-AzureRmContext).Account) {
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

Write-Verbose "Getting a current VM reference..."
# Get the VM defined foreals
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    Write-Verbose "Checking if VM has any current data attached"
    if ($vm.StorageProfile.DataDisks)
    {
        foreach ($ddisk in $vm.StorageProfile.DataDisks)
        {
            Write-Verbose "Checking if VM has a data disk with a name"
            if ($ddisk.Name -eq $DataDiskName)
            {
                Write-Verbose "Checking if it is a managed data disk or unmanaged data disk..."                
                # If VM has Unmanaged Disk check it 
                if (!$ddisk.ManagedDisk)
                {   
                    Write-Verbose "The VM has Unmanaged Data Disk."

                    if ($ddisk.DiskSizeGB -ge $NewDataDiskSize)
                    {
                        Write-Error "The new size should be greater than the currentData Disk size. Disk size reduction or same Disk size allocation not supported."
                        return
                    }

                    Write-Verbose "Getting current VM Status..."
                    # check the current status of the VM
                    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

                    Write-Verbose "Checking if VM is Running State..."
                    If ($vmstatus.Statuses.Code -contains "PowerState/running")
                    {
                        Write-Verbose "Stopping VM as it is currently running..."
                        $stopVM = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
                    }

                    Write-Verbose "Changing Unmanaged Data Disk Size. One moment..."
                    
                    # allows you to change the data disk size to custom size
                    $ddisk.DiskSizeGB = $NewDataDiskSize

                    # This updates our VM
                    $resizeOps = Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $vm
                }
                else 
                {    
                    Write-Verbose "The VM has Managed the Data Disk."

                    if ($ddisk.DiskSizeGB -eq $NewDataDiskSize)
                    {
                        Write-Error "The VM Data Disk is already at the size requested. Please specify another size"
                        return
                    }

                    Write-Verbose "Getting VM Status..."
                    # Grabs the current status of the VM
                    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

                    Write-Verbose "Check if VM is running"
                    If ($vmstatus.Statuses.Code -contains "PowerState/running")
                    {
                        Write-Verbose "Stopping the VM as it is currently running"
                        $stopVM = Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force 
                    }
                    
                    Write-Verbose "Changing managed Data Disk Size..."

                    # Get Data Disk for the VM in context
                    $vmDisk = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $ddisk.Name
                    
                    # Change the Data Disk Size
                    $vmDisk.DiskSizeGB = $NewDataDiskSize

                    # Update the Disk
                    $resizeOps = Update-AzureRmDisk -ResourceGroupName $ResourceGroupName -Disk $vmDisk -DiskName $ddisk.Name
                }

                If ($stopVM)
                {
                    Write-Verbose "Restart the VM as it was stopped."
                    Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -AsJob > $null
                }

                Write-Verbose "Data Disk size change successful. Please restart your VM."
            }
        }
    }
    else {
        Write-Error "Can't find any Data Disks attached to this VM. Sorry!"
        return
    }

}
else {
    Write-Error "Cannot find the specified VM you are looking for"
    return 
}
