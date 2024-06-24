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
 This script will let you scale up the size any Azure RM VM from its current size to a new size within the same Family.
#> 


<#
.SYNOPSIS 
    This script lets you Scale Up any Azure RM VM from its current size to a new size within the same Family.

.DESCRIPTION
    This Runbook lets you Scale Up any Azure RM VM from its current Size to a new size of whatever you want!

.Parameter RscGrpname
    Name of the Resource Group where the target VM is located

.Parameter vmnamespace
    Name of the target VM

.Parameter SizeStep
    Scalar value is currently between 1 to 8. This has a default value of 1, which will upgrade the VM to Immediately next size 
    within same VM family within the Size Table. you can set your own parameters but this script has those current parameters as of now

.EXAMPLE
    .\Scale-AzureRMVMUp.ps1 -RscGrpname rg-100 -vmnamespace vm100 -SizeStep 2

.EXAMPLE
    .\Scale-AzureRMVMDown.ps1 -RscGrpname rg-100 -vmnamespace vm100
    
.Notes
    Author: Catherine Demesa
    Creation Date: 12/Jan/2024
    Last Revision Date: 13/Jan/2024
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    Platform: Windows
#>

param
(

    [Parameter(Mandatory = $true)]
    [string]$RscGrpname,

    [Parameter(Mandatory = $true)]
    [string]$vmnamespace,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 8)]
    [int]$SizeStep = 1

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

# Create Stopwatch and Start the Timer
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()
 
function ResizeVM ($rgName, $vmName, $newVMSize) {

    Write-Output "Scaling-Up $vmName to $newVMSize ... this will require a Reboot!"

    $vmRef = Get-AzureRmVM -RscGrpname $rgName -Name $vmName
    
    $vmRef.HardwareProfile.VmSize = $newVMSize
    
    Update-AzureRmVM -VM $vmRef -RscGrpname $rgName -AsJob > $null

    Get-Job | Wait-Job | Receive-Job > $null
}

Write-Output "Starting the VM Scaling-Up Process."

$VM = Get-AzureRmVM -RscGrpname $RscGrpname -Name $vmnamespace -ErrorAction SilentlyContinue

If ($VM) {

    $vSize = $VM.HardwareProfile.VmSize

    $vmSizeURL = "[VM-SIZE-LINK-HERE]"

    $content = (Invoke-WebRequest -URL $vmSizeURL -UseBasicParsing).Content

    $vmSizes = $content.Split("`r`n")

    $vmFamilyList = @()

    foreach ($line in $vmSizes) {
        $row = $line.split(',');

        if ($row -contains $vSize) {
            $index = $row.IndexOf($vSize)

            $count = 0

            foreach ($subLine in $vmSizes) {
                $subRow = $subLine.split(',');

                if ($count -eq 0) {
                    $vmFamily = $subRow[$index]
                }
                else {
                    if ($subRow[$index]) {
                        $vmFamilyList += $subRow[$index]
                    }
                }            
                $count++
            }
            break 
        }
    }

    $nextSizeIndex = $vmFamilyList.IndexOf($vSize) + $SizeStep

    if (!$vmFamilyList[$nextSizeIndex]) {
               
        # Stop the Timer
        $StopWatch.Stop()

        Write-Output "The VM $($VM.Name) is at the maximum allowed size for the $vmFamily family."
    }
    else {
        # Call ResizeVM function to do the resizing
        ResizeVM $RscGrpname $vmnamespace $vmFamilyList[$nextSizeIndex]
        
        Write-Output "The Scaling-Up for VM $($VM.Name) has been completed!"

        # Stop the Timer
        $StopWatch.Stop()

        # Display the Elapsed Time
        Write-Output "Total Execution Time for Scaling Up the VM: $($StopWatch.Elapsed.ToString())"
    }
}
else {
    # Stop the Timer
    $StopWatch.Stop()

    Write-Output "Could not get the VM {$vmnamespace} in the Resource Group {$RscGrpname}."
}
