<#PSScriptInfo
.AUTHOR Catherine Demesa
.COMPANYNAME 
.COPYRIGHT (c) 2023 Catherine Demesa. All rights reserved.
.ICONURL 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 This will let you increase size allocations for an Azure RM VM as a Runbook
#> 

<#
.SYNOPSIS 
    This will let you increase size allocations for an Azure RM VM as a Runbook

.DESCRIPTION
    This Runbook lets you increase data disk sizes for Azure RM VM and blobs via Powershell. Current Azure settings don't let you manually
    change it for some reason upon creation (instead it allows you to delete/remake). This script provides at least a temp workaround

.PARAMETER RscGrpname
    Name of the Resource Group that has the VM resource itself

.PARAMETER vmnamespace    
    Name of the VM whose Data Disk.

.PARAMETER DataDisky
    Name of the existing Data Disk attached to our VM Resource.

.PARAMETER NewDataDiskSize    
    New Size of the Data Disk

.EXAMPLE
    .\Expand-AzureRMVMDataDisk -RscGrpname "RG1" -vmnamespace "VM01" -DataDisky "disk1234" -NewDataDiskSize 1023 
    
.Notes
    Author: Catherine Demesa
    Creation Date: 16/Feb/2024
    Last Revision Date: 19/Feb/2024
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$RscGrpname,
    
    [Parameter(Mandatory=$true)] 
    [String]$vmnamespace,

    [Parameter(Mandatory=$true)] 
    [String]$DataDisky,

    [Parameter(Mandatory=$true)]
    [ValidateRange(30,4095)]
    [int]$NewDataDiskSize
)

if (!(Get-AzureRmContext).Account) {
    $connectionName = "AzureRunAsConnection"
    try {
        # Gets the connection "AzureRunAsConnection"
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
    
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint > $null
    }
    catch {
        if (!$servicePrincipalConnection) {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        }
        else {
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}

Write-Output "Getting VM reference..."
# Get the VM "attached" to this
$vm = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace

if ($vm)
{
    Write-Output "Checking if VM has any Disks attached"
    if ($vm.StorageProfile.DataDisks)
    {
        foreach ($ddisk in $vm.StorageProfile.DataDisks)
        {
            Write-Output "Checking if VM has a Disk with specificname"
            if ($ddisk.Name -eq $DataDisky)
            {
                Write-Output "Check if it is a managed or unmanaged data disk..."                
                if (!$ddisk.ManagedDisk)
                {   
                    Write-Output "The VM has an unmanaged data disk."

                    if ($ddisk.DiskSizeGB -ge $NewDataDiskSize)
                    {
                        Write-Error "The new Data Disk size should be greater than existing Data Disk size. Please try again..."
                        return
                    }

                    Write-Output "Getting Current VM Status..."
                    # Get the current status of the VM
                    $vmstatus = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Status

                    Write-Output "Checking if VM is in a Running State..."
                    If ($vmstatus.Statuses.Code -contains "PowerState/running")
                    {
                        Write-Output "Stopping the VM as it is in a Running State..."
                        $stopVM = Stop-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Force
                    }

                    Write-Output "Changing Unmanaged Data Disk Size..."
                    
                    # Changes size of Disk 
                    $ddisk.DiskSizeGB = $NewDataDiskSize

                    # Updates the VM to apply Data Disk change
                    $resizeOps = Update-AzureRmVM -RscGrpname $RscGrpname -VM $vm
                }
                else 
                {    
                    Write-Output "The VM has Managed Data Disk."

                    if ($ddisk.DiskSizeGB -eq $NewDataDiskSize)
                    {
                        Write-Error "The VM Data Disk is already at the size specified"
                        return
                    }

                    Write-Output "Getting VM Status..."
                    # Gets current status of the VM
                    $vmstatus = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Status

                    Write-Output "Check if VM is in a Running State..."
                    If ($vmstatus.Statuses.Code -contains "PowerState/running")
                    {
                        Write-Output "Stopping the VM as it is in a Running State..."
                        $stopVM = Stop-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Force 
                    }
                    
                    Write-Output "Changing Managed Data Disk Size..."

                    # Gets the Data Disk for the VM
                    $vmDisk = Get-AzureRmDisk -RscGrpname $RscGrpname -DiskName $ddisk.Name
                    
                    # Changes the current Data Disk Size to the custom size
                    $vmDisk.DiskSizeGB = $NewDataDiskSize

                    # Updates the Disk
                    $resizeOps = Update-AzureRmDisk -RscGrpname $RscGrpname -Disk $vmDisk -DiskName $ddisk.Name
                }

                If ($stopVM)
                {
                    Write-Output "Restart the VM as it was stopped..."
                    Start-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -AsJob > $null
                }

                Write-Output "Data Disk size change successful. Please restart your VM."
            }
        }
    }
    else {
        Write-Error "Cannot find any Data Disks attached to the VM"
        return
    }

}
else {
    Write-Error "Cannot find specified VM"
    return 
}
