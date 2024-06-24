<#PSScriptInfo
.AUTHOR Catherine Demesa
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
Asynchronously Starts all or specific Azure RM VM(s) in a current Azure sub
#>

<#
.SYNOPSIS
    Asynchronously Starts all or specific Azure RM VM(s) in an Azure Sub plan

.DESCRIPTION
    This Script asynchronously Starts either all Azure RM VMs in an Azure Sub plan, or all Azure RM VMs in one or
    more specified Resource Groups etc etc. BTW, You need to be already logged into your Azure account via PowerShell before calling this.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to Start. Don't specify with VMName as a name because that will start totally everything.
    Instead, specify with specific names when calling ResourceGroupName parameter

.PARAMETER VMName
    Name of the VM you want to Start. When specified alone, without the "ResourceGroupName"
    parameter, can Include one or more VM Names to be started across any resource groups in the Azure Subscription. Be
    careful when being specific -- you might want to have specific names when calling certain VMs using this

.PARAMETER ExcludedResourceGroupName
    Name of the Resource Group(s) including the VMs you want excluded from being started. Currently, this can't be combined with
    "ResourceGroupName" and "VMName" parameters.

.PARAMETER ExcludedVMName
    Contains the name of the VM(s) you want excluded from being automatically started. Currently can't be combined with the "VMName" parameter.


.EXAMPLE
    .\Start-AzureRMVMAll.ps1
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ResourceGroupName RG1
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ResourceGroupName RG1,RG2,RG3
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ResourceGroupName RG1 -VMName VM01
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ResourceGroupName RG1 -VMName VM01,VM02,VM05
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -VMName VM01,VM011,VM23,VM35
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ExcludedResourceGroupName RG5,RG6,RG7
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ExcludedResourceGroupName RG5,RG6,RG7 -ExludedVMName VM5,VM6,VM7
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ResourceGroupName RG1 -ExcludedVMName VM5,VM6,VM7
.EXAMPLE
    .\Start-AzureRMVMAll.ps1 -ResourceGroupName RG1,RG2,RG3 -ExcludedVMName VM5,VM6,VM7

.Notes
    Author: Catherine Demesa
    Creation Date: 05/Jan/2024
    Last Revision Date: 19/Jun/2024
    Development Environment: VS Code IDE
    Platform: Windows
#>
[CmdletBinding()]
param(

    [Parameter(Mandatory = $false)]
    [String[]]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [String[]]$VMName,

    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedResourceGroupName,

    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedVMName
)

if (!(Get-AzureRmContext).Account) {
    Write-Error "You need to be logged into your Azure Subscription using PowerShell cmdlet 'Login-AzureRmAccount'"
    return
}

# Create Stopwatch and Start the Timer
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

[System.Collections.ArrayList]$jobQ = @()

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {
   # Grabs a list of all the VMs across all Resource Groups in the Subscription
   $VMs = Get-AzureRmVm

   # Script checks if one or more VMs were discovered across your sub plan
   if ($VMs) {

       # Iterates fully through all the VMs within the current sub plan
       foreach ($vmx in $VMs) {

            If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
            {
                if ($ExcludedResourceGroupName -contains $vmx.ResourceGroupName)
                {
                    Write-Verbose "Skipping VM {$($vmx.Name)} since the Resource Group {$($vmx.ResourceGroupName)} containing it is specified as Excluded..."
                    continue
                }
            }

            If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
            {
                if ($ExcludedVMName -Contains $vmx.Name)
                {
                    Write-Verbose "Skipping VM {$($vmx.Name)} since it is specified as Excluded..."
                    continue
                }
            }

           # Grabs a reference to the specific VM for this run
           $vm = Get-AzureRmVM -ResourceGroupName $vmx.ResourceGroupName -Name $vmx.Name

           $VMBaseName = $vm.Name
           $RGBaseName = $vm.ResourceGroupName

           # Grabs a current status of the VM you're messing around with 
           $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status

           # Extracts current Power State of the VM
           $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]

           # Checks Power/on status of the VM, and it starts if only it is in a "Running" / "Starting" state
           if ($VMState) {
               if ($VMState -in "deallocated","stopped") {
                   Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated/Stopped. Starting..."
                   $retval = Start-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob
                   $jobQ.Add($retval) > $null
               }
               elseif ($VMState -in "running","starting") {
                   Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Currently Starting. Skipping."
                   continue
               }
               elseif ($VMState -in "stopping","deallocating") {
                   Write-Verbose "The VM {$VMBaseName} in the current Resource Group named {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                   continue
               }
           }
           else {
               Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in the Resource Group named {$RGBaseName}. Cannot start the VM. Skipping..."
               continue
           }
       }
   }
   else
   {
       Write-Verbose "There are no VMs in the Azure Subscription."
       continue
   }
}
# Check if only Resource Group param is passed, but not the VM Name param
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {

    If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
    {
        Write-Verbose "You cannot specify Parameters 'ExcludedResourceGroupName' together with 'ResourceGroupName'"
        return
    }

    foreach ($rg in $ResourceGroupName) {

        # Get a list of all the VMs in the specific Resource Group
        $VMs = Get-AzureRmVm -ResourceGroupName $rg -ErrorAction SilentlyContinue

        if(!$?)
        {
            Write-Verbose "The Resource Group {$rg} does not exist. Skipping."
            continue
        }

        if ($VMs) {
            # Iterate through all the VMs within the specific Resource Group for this Iteration
            foreach ($vm in $VMs) {

                If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
                {
                    if ($ExcludedVMName -Contains $vm.Name)
                    {
                        Write-Verbose "Skipping VM {$($vm.Name)} from Resource Group {$rg} since it is specified as Excluded..."
                        continue
                    }
                }

                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]

                if ($VMState) {
                    if ($VMState -in "deallocated", "stopped") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is currently Deallocated/Stopped. Starting..."
                        $retval = Start-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -AsJob
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -in "running","starting") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is either already Started or Starting. Skipping."
                        continue
                    }
                    elseif ($VMState -in "stopping","deallocating") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$rg}. Hence, cannot start the VM. Skipping to next VM..."
                    continue
                }
            }
        }
        else {
            Write-Verbose "There are no Virtual Machines in Resource Group {$rg}. Skipping to next Resource Group"
            continue
        }
    }
}
# Check if both Resource Group and VM Name params are passed
Elseif ($PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {

    # You cannot specify Resource Groups more than 1 when both ResourceGroupName and VMName parameters are specified
    if ($ResourceGroupName.Count -gt 1)
    {
        Write-Verbose "You can only specify a single Resource Group Name value when using both 'ResourceGroupName' and 'VMName' parameters together."
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
    {
        Write-Verbose "You cannot specify Parameters 'ExcludedResourceGroupName' together with 'ResourceGroupName'"
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
    {
        Write-Verbose "You cannot specify Parameters 'ExcludedVMName' together with 'ResourceGroupName' and 'VMName'"
        return
    }

    # Check if Resource Group exists
    $testRG = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (!$testRG) {
        Write-Verbose "The Resource Group {$ResourceGroupName} does not exist. Skipping."
        continue
    }

    # Iterate through all VM's specified
    foreach ($vms in $VMName)
    {
        # Get the specified VM in the specific Resource Group
        $vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -Name $vms -ErrorAction SilentlyContinue

        if ($vm) {

            $VMBaseName = $vm.Name
            $RGBaseName = $vm.ResourceGroupName

            # Get current status of the VM
            $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status

            # Extract current Power State of the VM
            $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]

            if ($VMState) {
                if ($VMState -in "deallocated","stopped") {
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated/Stopped. Starting..."
                    $retval = Start-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -in "running","starting") {
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Starting. Skipping"
                    continue
                }
                elseif ($VMState -in "stopping","deallocating") {
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }
            else {
                Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot start the VM. Skipping to next VM..."
                continue
            }
        }
        else {
            Write-Error "There is no Virtual Machine named {$vms} in Resource Group {$ResourceGroupName}. Aborting..."
            return
        }
    }
}
# Check if Resource Group param is not passed, but VM Name param is passed
Elseif (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And $PSBoundParameters.ContainsKey('VMName')) {

    If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
    {
        Write-Verbose "You cannot specify Parameters 'ExcludedResourceGroupName' and 'VMName' together"
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedVMName'))
    {
        Write-Verbose "You cannot specify Parameters 'ExcludedVMName' and 'VMName' together"
        return
    }

    foreach ($vms in $VMName) {

        # Find the specific VM resource
        $vmFind = Find-AzureRmResource -ResourceNameEquals $vms

        # If the VM resource is found in the Subscription
        if ($vmFind)
        {
            # Extract the Resource Group Name of the VM
            $RGBaseName = $vmFind.ResourceGroupName

            # Get reference object of the VM
            $vm = Get-AzureRmVm -ResourceGroupName $RGBaseName -Name $vms

            if ($vm) {

                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]

                if ($VMState) {
                    if ($VMState -in "deallocated","stopped") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently Deallocated/Stopped. Starting..."
                        $retval = Start-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -in "running","starting") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is either already Started or Starting. Skipping."
                        continue
                    }
                    elseif ($VMState -in "stopping","deallocating") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot start the VM. Skipping to next VM..."
                    continue
                }
            }
            else {

                Write-Error "There is no Virtual Machine named {$vms} in the Azure Subscription. Aborting..."
                return
            }
        }
        else {
            Write-Verbose "Could not find Virtual Machine {$vms} in the Azure Subscription."
            continue
        }
    }
}

Get-Job | Wait-Job | Receive-Job > $null

# Stop the Timer
$StopWatch.Stop()

# Display the Elapsed Time
Write-Verbose "Total Execution Time for Starting All Target VMs:" + $StopWatch.Elapsed.ToString()

Write-Verbose "All Target VM's which were stopped/deallocated, have been Started Successfully!"
