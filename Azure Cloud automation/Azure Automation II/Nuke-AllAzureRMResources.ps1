<#PSScriptInfo
.AUTHOR Catherine Demesa
.COMPANYNAME 
.COPYRIGHT (c) 2023 Catherine Demesa. All rights reserved.
.TAGS Windows PowerShell Azure AzureVM
.ICONURI 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 Allows asynchronous destructiob of all Azure RM resources in an Azure sub
#> 

<#
.SYNOPSIS 
    This script will allow asynchronous destruction of all Azure RM resources in a single Azure sub

.DESCRIPTION
    This script lets you destroy/delete all of your Azure RM resources in an Azure sub asynchronously. Make sure you're currently
    logged into your Azure account via PowerShell CLI before calling this script.

.EXAMPLE
    .\Nuke-AzureRMAllResources.ps1
    
.Notes
    Author: Catherine Demesa
    Creation Date: 01/01/2024
    Last Revision Date: 23/Jun/2024
    Development Environment: VS Code IDE
    Platform: Windows
#>
[CmdletBinding()]
param
()

if (!(Get-AzureRmContext).Account) {
    Write-Error "You need to be logged into your Azure Sub via PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

# Gets/Fetches a list of all the Resource Groups in the Azure Sub that are currently active
$RGs = Get-AzureRmResourceGroup 

[System.Collections.ArrayList] $Job = @()

# Checks if there are Resource Groups in the current Subscription
if ($RGs) {        
    # Iterates through all the Resource Groups in the current Sub      
    foreach ($rg in $RGs) 
    {
        $RGBaseName = $rg.ResourceGroupName

        # Allows the asynch removal of the Resource Group using PS Jobs
        $retVal = Start-Job -ScriptBlock {Remove-AzureRmResourceGroup -Name $args[0] -Force} -ArgumentList $RGBaseName
        
        # Add each Job to an array
        $Job.Add($retVal)

        Write-Verbose "Removing Resource Group $RGBaseName..."

        # Waits a bit for a pre-defined time to throttle/speed up the job requests
        Start-Sleep 10
    }

    # Removes all completed jobs in the queue
    Get-Job | Wait-Job | Remove-Job

    Write-Verbose "Fully deleted all of the Azure RM resource from the Azure Sub. Any Azure Classic resources, if there, were not touched..."
}
else {
    Write-Error "There are no currently active Azure Resource Groups in the Azure Sub. Aborting..."
    return $null
}