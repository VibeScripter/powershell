
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
 Gets you the current Power State of an Azure RM VM as a Runbook from within an Azure Automation Account.
#> 

<#
.SYNOPSIS 
    Gets you the current Power State of an Azure RM VM as a Runbook from within an Azure Automation Account.

.DESCRIPTION
    This Runbook returns to you the current Power State of an Azure RM VM. You need to execute this Runbook through a 
    'Azure Run As account (service principal)' Identity from an Azure Automation account.

.PARAMETER RscGrpname
    Name of the Resource Group containing the VM

.PARAMETER vmnamespace    
    Name of the VM whose Power State you want to retrieve

.EXAMPLE
    .\Get-AzureRMVMPowerStateRB.ps1 -RscGrpname "RG1" -vmnamespace "VM01"
    
.Notes

Possible VM Power State Values (Instance View):

Starting     :Indicates the VM is being started
Running      :Indicates that the VM is being started / currently active
Stopping     :Indicates that the VM is fully stopped, no billables applied
Stopped      : Indicates that the VM is fully stopped -- however, charges still incur over time
Deallocating : Indicates that the VM is being deallocated
Deallocated  : Indicates that the VM is removed from Hyper-V but still active
--           : Indicates that the power % is unknown


Author: Catherine Demesa
Creation Date: 10/Dec/2022
Last Revision Date: 27/Jan/2023
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

# Get the VM in context
$vm = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace

if ($vm)
{
    # Get current status of the VM
    $vmstatus = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -Status

    # Extract current Power State of the VM
    $powerState = $vmstatus.Statuses[1].Code.Split('/')[1]

    # Return the Power State
    return $powerState.ToUpper()
}
else {
    Write-Error "Cannot find VM'"
    return 
}
