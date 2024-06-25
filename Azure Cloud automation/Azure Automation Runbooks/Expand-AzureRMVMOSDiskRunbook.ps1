<#PSScriptInfo
.VERSION 1.1.0
.GUID db10bd5a-4fb3-4058-8c46-d2044aeb258e
.AUTHOR Catherine Demesa
.COMPANYNAME 
.COPYRIGHT (c) 2023 Catherine Demesa. All rights reserved.
.ICONURI 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#> 

<#
.DESCRIPTION 
Lets you Increase the OS Disk Size for an Azure RM VM as a Runbook from within an Azure Automation Account.
#>

<#
.SYNOPSIS 
    Lets you Increase the OS Disk Size for an Azure RM VM as a Runbook from within an Azure Automation Account.

.DESCRIPTION
    This Runbook lets you Increase the OS Disk size for a VM. OS Disk Size reduction is not supported by Azure. It 
    supports OS Disk resizing for both Managed and Unmanaged disks. You need to execute this Runbook through a 
    'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER RscGrpname
    Name of the Resource Group containing the VM, whose OS Disk you want to resize

.PARAMETER vmnamespace    
    Name of the VM whose OS Disk you want to resize

.PARAMETER NewOSDiskSize    
    New Size of OS Disk

.EXAMPLE
    .\Expand-AzureRMVMOSDisk -RscGrpname "RG1" -vmnamespace "VM01" -NewOSDiskSize 1023 
    
.Notes
    Author: Catherine Demesa
    Creation Date: 23/Dec/2023
    Last Revision Date: 1/Jan/2024
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$RscGrpname,
    
    [Parameter(Mandatory=$true)] 
    [String]$vmnamespace,

    [Parameter(Mandatory=$true)]
    [ValidateRange(30,2048)]
    [int]$NewOSDiskSize
)

if (!(Get-AzureRmContext).Account) {
    $connectionName = "AzureRunAsConnection"
    try {
        # Get the connection "AzureRunAsConnection "
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
# Get the VM in context
$vm = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace

if ($vm)
{
    if ($vm.StorageProfile.OSDisk.DiskSizeGB -ge $NewOSDiskSize)
    {
        Write-Error "The new OS Disk size should be greater than existing OS Disk size. Disk size reduction or same Disk size allocation not supported."
        return
    }

    Write-Output "Checking if the VM has a Managed disk or Unmanaged disk..."
    # If VM has Unamanged Disk 
    if (!$vm.StorageProfile.OsDisk.ManagedDisk)
    {   
        Write-Output "The VM has Unmanaged OS Disk."

        Write-Output "Getting VM Status..."
        # Get current status of the VM
        $vmstatus = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Status
    
        Write-Output "Checking if VM is in a running..."
        If ($vmstatus.Statuses.Code -contains "PowerState/running")
        {
            Write-Output "Stopping the VM as it is in a running..."
            $stopVM = Stop-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Force
        }

        Write-Output "Changing Unmanaged OS Disk Size..."
        
        # Change the OS Disk Size 
        $vm.StorageProfile.OSDisk.DiskSizeGB = $NewOSDiskSize

        # Update the VM to apply OS Disk change
        $resizeOps = Update-AzureRmVM -RscGrpname $RscGrpname -VM $vm
    }
    else 
    {    
        Write-Output "The VM Has Managed OS Disk."

        Write-Output "Getting VM Status..."
        # Get current status of the VM
        $vmstatus = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Status
    
        Write-Output "Checking if VM is in a running..."
        If ($vmstatus.Statuses.Code -contains "PowerState/running")
        {
            Write-Output "Stopping the VM as it is in a running..."
            $stopVM = Stop-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Force
        }
        
        Write-Output "Changing Managed OS Disk Size..."

        # Get OS Disk for the VM in context
        $vmDisk = Get-AzureRmDisk -RscGrpname $RscGrpname -DiskName $vm.StorageProfile.OSDisk.Name
        
        # Change the OS Disk Size
        $vmDisk.DiskSizeGB = $NewOSDiskSize

        # Update the Disk
        $resizeOps = Update-AzureRmDisk -RscGrpname $RscGrpname -Disk $vmDisk -DiskName $vmDisk.Name
    }

    If ($stopVM)
    {
        Write-Output "Restart the VM as it was stopped from a running..."
        Start-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -AsJob > $null
    }

    Write-Output "OS Disk size change successful."

}
else {
    Write-Error "Cannot find VM'"
    return 
}
