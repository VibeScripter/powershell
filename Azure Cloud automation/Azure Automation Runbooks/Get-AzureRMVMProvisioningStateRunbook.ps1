<#PSScriptInfo
.AUTHOR Catherine Demesa
.COMPANYNAME 
.COPYRIGHT (c) 2024 Catherine Demesa. All rights reserved.

.ICONURL 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 Gets you the current Provisions of an Azure RM VM as a Runbook from within an Azure Acc
#> 

<#
.SYNOPSIS 
    Gets you the current Provisioning State of an Azure RM VM as a Runbook from within an Azure Automation Account.

.DESCRIPTION
    This Runbook returns to you current Provisioning State of an Azure RM VM. You need to execute this Runbook through 
    a 'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER RscGrpname
    Name of the Resource Group containing the VM

.PARAMETER vmnamespace    
    Name of the VM whose Provisioning State you want to retrieve

.EXAMPLE
    .\Get-AzureRMVMProvisioningState.ps1 -RscGrpname "RG1" -vmnamespace "VM01"
    
.Notes

Possible VM Provisioning State Values (Model View):

- Creating	:Indicates the virtual Machine is being created.
- Updating	:Indicates that there is an update operation in progress on the Virtual Machine.
- Succeeded	:Indicates that the operation executed on the virtual machine succeeded.
- Deleting	:Indicates that the virtual machine is being deleted.
- Failed	:Indicates that the update operation on the Virtual Machine failed.


Author: Catherine Demesa
Creation Date: 09/Jan/2023
Last Revision Date: 22/Jun/2024
Development Environment: Azure Automation Runbook Editor and VS Code IDE
Platform: Windows
#>

param(

    [Parameter(Mandatory=$true)] 
    [String]$RscGrpname,
    
    [Parameter(Mandatory=$true)] 
    [String]$vmnamespace
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

# Get the VM looped in for script activation
$vm = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace

if ($vm)
{
    # Grabs the current status of the VM
    $vmstatus = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Status

    # Go and extract the current Provisioning State
    $provState = $vmstatus.Statuses[0].Code.Split('/')[1]

    # Go + return the Provisioning State
    return $provState.ToUpper()

}
else {
    Write-Error "Cannot find VM'"
    return 
}
