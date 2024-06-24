<#
.SYNOPSIS 
    Gets you the current Provisioning State of an Azure RM VM.

.DESCRIPTION
    This script returns to you current Provisioning State of an Azure RM VM. Make sure you are logged in to Azure cloud first
    before running this

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VM

.PARAMETER VMName    
    Name of the VM you want to call/retrieve

.EXAMPLE
    .\Get-AzureRMVMProvisioningState.ps1 -ResourceGroupName "RG1" -VMName "VM01"
    
.Notes

Possible VM Provisioning State Values:

- Creating	:Indicates VM is currently being created.
- Updating	:Indicates there is an update operation in progress for the VM.
- Succeeded	:Indicates that the operation executed on the VM succeeded.
- Deleting	:Indicates deletion of VM.
- Failed	:Indicates that the update operation for the VM is unsuccessful.


Author: Catherine Demesa
Creation Date: 27/Dec/2023
Last Revision Date: 15/Jun/2024
Development Environment: VS Code IDE
Platform: Windows
#>
[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)] 
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)] 
    [String]$VMName
)

if (!(Get-AzureRmContext).Account){
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

# Get the VM 
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName

if ($vm)
{
    # Get current status of the VM
    $vmstatus = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

    # Extract current Provisioning State of VM
    $provState = $vmstatus.Statuses[0].Code.Split('/')[1]

    # Return the Provisioning State status
    return $provState.ToUpper()

}
else {
    Write-Error "Cannot find VM'"
    return 
}