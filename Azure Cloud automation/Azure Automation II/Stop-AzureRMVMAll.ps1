<#PSScriptInfo
.AUTHOR Catherine Demesa
.COMPANYNAME 
.COPYRIGHT (c) 2023 Catherine Demesa. All rights reserved.
.TAGS Windows PowerShell Azure AzureVM
.ICONURL 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 Asynchronously Stops all or specific Azure RM VMs in an Azure Subscription
#> 

<#
.SYNOPSIS 
    Asynchronously Stops all or specific Azure RM VMs in an Azure Subscription

.DESCRIPTION
    This Script asynchronously Stops either all Azure RM VMs in an Azure Subscription, or all Azure RM VMs in one or 
    more specified Resource Groups, or one or more VMs in a specific Resource Group, or any number of Random VMs in a 
    Subscription. You can specify one or more Resource Groups to exclude, wherein all VMs in those Resource Groups will 
    not be stopped. You can specify one or more VMs to exclude, wherein all those VMs will not be stopped. The 
    choice around which VMs to stop depends on the combination and values of the parameters provided. 

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the VMs you want to Stop. Specifying just the Resource Group without 
    the "VMName" parameter will consider all VMs in that specified Resource Group. You can specify an array of 
    Resource Group names without "VMname" parameter, and all VMs withihn the specified Resource Groups in the array will
    be stopped. You can specify just a single Resource Group Name in this parameter, along with one or more VM names in 
    the "VMName" parameter, wherein all the VMs specified will be stopped in that specific Resource Group. You cannot
    specify more than one Resource Group Names when combined with the "VMName" parameter. You need to be already logged 
    into your Azure account through PowerShell before calling this script.

.PARAMETER VMName    
    Name of the VM you want to Stop. This parameter when specified alone, without the "ResourceGroupName" 
    parameter, can Include one or more VM Names to be stopped across any resource groups in the Azure Subscription. When
    specified with the "ResourceGroupName" parameter, you need to Include one or more VMs in the specified Resource
    Group only.

.PARAMETER ExcludedResourceGroupName
    Name of the Resource Group(s) containing the VMs you want excluded from being Stopped. It cannot be combined with 
    "ResourceGroupName" and "VMName" parameters. 

.PARAMETER ExcludedVMName    
    Name of the VM(s) you want excluded from being Stopped. It cannot be combined with "VMName" parameter.

.EXAMPLE
    .\Stop-AzureRMVMAll.ps1
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1,RG2,RG3
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1 -VMName VM01
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1 -VMName VM01,VM02,VM05
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -VMName VM01,VM011,VM23,VM35
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ExcludedResourceGroupName RG5,RG6,RG7
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ExcludedResourceGroupName RG5,RG6,RG7 -ExludedVMName VM5,VM6,VM7
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1 -ExcludedVMName VM5,VM6,VM7
.EXAMPLE
    .\Stop-AzureRMVMAll.ps1 -ResourceGroupName RG1,RG2,RG3 -ExcludedVMName VM5,VM6,VM7
    
.Notes
    Author: Catherine Demesa
    Creation Date: 14/Dec/2023
    Last Revision Date: 14/Jun/2024
    Development Environment: VS Code IDE
    Platform: Windows
#>
[CmdletBinding()]
param(
 
    [Parameter(Mandatory=$false)]
    [String[]]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [String[]]$VMName,

    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedVMName
)

if (!(Get-AzureRmContext).Account) {

}


# Create Stopwatch
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
# Start Stopwatch
$StopWatch.Start()

[System.Collections.ArrayList]$jobQ = @()

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('ResourceGroupName') -And !$PSBoundParameters.ContainsKey('VMName')) {

    # Grabs a full list of all the VMs across all Resource Groups in the sub plan you have
    $VMs = Get-AzureRmVm

    # Checks if one or more VMs were discovered across Subs
    if ($VMs) {
        
        # Fully iterates through all the VMs discovered within the current Sub plan you have
        foreach ($vmx in $VMs) {

            If ($PSBoundParameters.ContainsKey('ExcludedResourceGroupName'))
            {
                if ($ExcludedResourceGroupName -Contains $vmx.ResourceGroupName)
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
            
            # Grabs a quick reference to the specific VM for this Iteration run thru
            $vm = Get-AzureRmVM -ResourceGroupName $vmx.ResourceGroupName -Name $vmx.Name

            $VMBaseName = $vm.Name
            $RGBaseName = $vm.ResourceGroupName

            # Grabs a current status of the VM
            $vmstatus = Get-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -Status
                    
            # Extracts the current Power Status of the VM being used
            $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
            
            # Checks the power status of the VM, stops only if it is in a "Running"/"Starting" state
            if ($VMState) {
                if ($VMState -in "deallocated","stopped") {
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                    continue
                }
                elseif ($VMState -in "running","starting") {
                    Write-Verbose "The VM {$VMBaseName} in a Resource Group named {$RGBaseName} is currently either already Started or Starting. Stopping..."
                    $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -in "stopping","deallocating") {
                    Write-Verbose "The VM {$VMBaseName} in a Resource Group named {$RGBaseName} and is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }
            else {
                Write-Verbose "Cannot determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
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
                    if ($VMState -in "deallocated","stopped") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -in "running","starting") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is currently either already Started or Starting. Stopping..."
                        $retval = Stop-AzureRmVM -ResourceGroupName $rg -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -in "stopping","deallocating") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$rg} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$rg}. Hence, cannot stop the VM. Skipping to next VM..."
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
        Write-Verbose "You can only specify a single Resource Group Name when using both 'ResourceGroupName' and 'VMName' Parameters together."
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
        Write-Verbose "The Resource Group {$ResourceGroupName} does not exist. Aborting."
        return           
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
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                    continue
                }
                elseif ($VMState -in "running","starting") {
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                    $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -in "stopping","deallocating") {
                    Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }        
            else {
                Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
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
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -in "running","starting") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                        $retval = Stop-AzureRmVM -ResourceGroupName $RGBaseName -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -in "stopping","deallocating") {
                        Write-Verbose "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }        
                else {
                    Write-Verbose "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
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
Write-Verbose "Total Execution Time for Stopping All Target VMs: $($StopWatch.Elapsed.ToString())"

Write-Verbose "All Target VM's which were Running and not Excluded, have been stopped Successfully!"