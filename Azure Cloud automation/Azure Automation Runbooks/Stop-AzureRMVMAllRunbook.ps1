<#PSScriptInfo
.AUTHOR Catherine Demesa
.COPYRIGHT (c) 2024 Catherine Demesa. All rights reserved.
.ICONURL 
.EXTERNALMODULEDEPENDENCIES AzureRM
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES 
.RELEASENOTES
#>

<# 
.DESCRIPTION 
 Asynchronously stops all (...or specific) Azure RM VMs within an Azure Subscription account
#> 

<#
.SYNOPSIS 
    Asynchronously Stops all or specific Azure RM VMs in an Azure Subscription as a Runbook from within an Azure 
    Automation Account

.DESCRIPTION
    This Runbook/script asynchronously will stop either all Azure RM VMs in an Azure Subscription, or all Azure RM VMs in one or 
    more specified Resource Groups // one or more VMs in a specific Group, or any # of Random VMs in a 
    Subscription. You can specify one or more Resource Groups to exclude

.PARAMETER RscGrpname
    Name of the Resource Group containing the VMs you want to Stop. Specifying just the Resource Group without 
    the "vmnamespace" parameter will consider all VMs in that specified Resource Group. :)

.PARAMETER vmnamespace    
    Name of the VM you want to Stop. This parameter when specified alone, without the "RscGrpname" 
    parameter, can Include one or more VM Names to be stopped across any resource groups in the Azure Subscription.

.PARAMETER ExcludedRscGrpname
    Name of the Resource Group(s) containing the VMs you want excluded from being Stopped. It cannot be combined with 
    "RscGrpname" and "vmnamespace" parameters. 

.PARAMETER Excludedvmnamespace    
    This will include the name of the VM(s) you want excluded from being stopped/cancelled. It cannot be combined with "vmnamespace" parameter.

.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -RscGrpname RG1
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -RscGrpname RG1,RG2,RG3
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -RscGrpname RG1 -vmnamespace VM01
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -RscGrpname RG1 -vmnamespace VM01,VM02,VM05
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -vmnamespace VM01,VM011,VM23,VM35
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -ExcludedRscGrpname RG5,RG6,RG7
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -ExcludedRscGrpname RG5,RG6,RG7 -Exludedvmnamespace VM5,VM6,VM7
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -RscGrpname RG1 -Excludedvmnamespace VM5,VM6,VM7
.EXAMPLE
    .\Stop-AzureRMVMAllRunbook.ps1 -RscGrpname RG1,RG2,RG3 -Excludedvmnamespace VM5,VM6,VM7
    
.Notes
    Author: Catherine Demesa
    Creation Date: 11/Feb/2024
    Last Revision Date: 15/Feb/2024
    Development Environment: Azure Automation Runbook Editor and VS Code IDE
    Platform: Windows
#>

param(
 
    [Parameter(Mandatory=$false)]
    [String[]]$RscGrpname,
    
    [Parameter(Mandatory=$false)]
    [String[]]$vmnamespace,

    [Parameter(Mandatory=$false)]
    [String[]]$ExcludedRscGrpname,
    
    [Parameter(Mandatory=$false)]
    [String[]]$Excludedvmnamespace
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


# Create Stopwatch
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
# Start Stopwatch
$StopWatch.Start()

[System.Collections.ArrayList]$jobQ = @()

# Check if both Resource Groups and VM Name params are not passed
If (!$PSBoundParameters.ContainsKey('RscGrpname') -And !$PSBoundParameters.ContainsKey('vmnamespace')) {

    # Get a list of all the VMs across all Resource Groups in the Subscription
    $VMs = Get-AzureRmVm

    # Check if one or more VMs were discovered across Subscription
    if ($VMs) {
        
        # Iterate through all the VMs discovered within the Subscription
        foreach ($vmx in $VMs) {

            If ($PSBoundParameters.ContainsKey('ExcludedRscGrpname'))
            {
                if ($ExcludedRscGrpname -Contains $vmx.RscGrpname)
                {
                    Write-Output "Skipping VM {$($vmx.Name)} since the Resource Group {$($vmx.RscGrpname)} containing it is specified as Excluded..."
                    continue
                }
            }

            If ($PSBoundParameters.ContainsKey('Excludedvmnamespace'))
            {
                if ($Excludedvmnamespace -Contains $vmx.Name)
                {
                    Write-Output "Skipping VM {$($vmx.Name)} since it is specified as Excluded..."
                    continue
                }
            }
            
            # Get reference to the specific VM for this Iteration
            $vm = Get-AzureRmVM -RscGrpname $vmx.RscGrpname -Name $vmx.Name

            $VMBaseName = $vm.Name
            $RGBaseName = $vm.RscGrpname

            # Get current status of the VM
            $vmstatus = Get-AzureRmVM -RscGrpname $RGBaseName -Name $VMBaseName -Status
                    
            # Extract current Power State of the VM
            $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
            
            # Check PowerState Level of the VM, and stop it only if it is in a "Running" or "Starting" state
            if ($VMState) {
                if ($VMState -in "deallocated","stopped") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                    continue
                }
                elseif ($VMState -in "running","starting") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                    $retval = Stop-AzureRmVM -RscGrpname $RGBaseName -Name $VMBaseName -AsJob -Force
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -in "stopping","deallocating") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }
            else {
                Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
                continue
            }
        }
    }
    else 
    {
        Write-Output "There are no VMs in the Azure Subscription."
        continue
    }
}
# Check if only Resource Group param is passed, but not the VM Name param
Elseif ($PSBoundParameters.ContainsKey('RscGrpname') -And !$PSBoundParameters.ContainsKey('vmnamespace')) {

    If ($PSBoundParameters.ContainsKey('ExcludedRscGrpname'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedRscGrpname' together with 'RscGrpname'"
        return
    }

    foreach ($rg in $RscGrpname) {

        # Get a list of all the VMs in the specific Resource Group
        $VMs = Get-AzureRmVm -RscGrpname $rg -ErrorAction SilentlyContinue

        if(!$?)
        {
            Write-Output "The Resource Group {$rg} does not exist. Skipping."
            continue             
        }
        
        if ($VMs) {
            # Iterate through all the VMs within the specific Resource Group for this Iteration
            foreach ($vm in $VMs) {
    
                If ($PSBoundParameters.ContainsKey('Excludedvmnamespace'))
                {
                    if ($Excludedvmnamespace -Contains $vm.Name)
                    {
                        Write-Output "Skipping VM {$($vm.Name)} from Resource Group {$rg} since it is specified as Excluded..."
                        continue
                    }
                }

                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -RscGrpname $rg -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
                
                if ($VMState) {
                    if ($VMState -in "deallocated","stopped") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -in "running","starting") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is currently either already Started or Starting. Stopping..."
                        $retval = Stop-AzureRmVM -RscGrpname $rg -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -in "stopping","deallocating") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$rg} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }
                else {
                    Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$rg}. Hence, cannot stop the VM. Skipping to next VM..."
                    continue
                }
            }
        }
        else {
            Write-Output "There are no Virtual Machines in Resource Group {$rg}. Skipping to next Resource Group"
            continue
        }
    }
}
# Check if both Resource Group and VM Name params are passed
Elseif ($PSBoundParameters.ContainsKey('RscGrpname') -And $PSBoundParameters.ContainsKey('vmnamespace')) {
    
    # You cannot specify Resource Groups more than 1 when both RscGrpname and vmnamespace parameters are specified
    if ($RscGrpname.Count -gt 1)
    {
        Write-Output "You can only specify a single Resource Group Name when using both 'RscGrpname' and 'vmnamespace' Parameters together."
        return
    }

    If ($PSBoundParameters.ContainsKey('ExcludedRscGrpname'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedRscGrpname' together with 'RscGrpname'"
        return
    }

    If ($PSBoundParameters.ContainsKey('Excludedvmnamespace'))
    {
        Write-Output "You cannot specify Parameters 'Excludedvmnamespace' together with 'RscGrpname' and 'vmnamespace'"
        return
    }

    # Check if Resource Group exists
    $testRG = Get-AzureRmResourceGroup -Name $RscGrpname -ErrorAction SilentlyContinue

    if (!$testRG) {
        Write-Output "The Resource Group {$RscGrpname} does not exist. Aborting."
        return           
    }

    # Iterate through all VM's specified
    foreach ($vms in $vmnamespace)
    {
        # Get the specified VM in the specific Resource Group
        $vm = Get-AzureRmVm -RscGrpname $RscGrpname -Name $vms -ErrorAction SilentlyContinue

        if ($vm) {
            
            $VMBaseName = $vm.Name
            $RGBaseName = $vm.RscGrpname

            # Get current status of the VM
            $vmstatus = Get-AzureRmVM -RscGrpname $RGBaseName -Name $VMBaseName -Status

            # Extract current Power State of the VM
            $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]

            if ($VMState) {
                if ($VMState -in "deallocated","stopped") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                    continue
                }
                elseif ($VMState -in "running","starting") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                    $retval = Stop-AzureRmVM -RscGrpname $RGBaseName -Name $VMBaseName -AsJob -Force
                    $jobQ.Add($retval) > $null
                }
                elseif ($VMState -in "stopping","deallocating") {
                    Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                    continue
                }
            }        
            else {
                Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
                continue
            }
        }
        else {
            Write-Error "There is no Virtual Machine named {$vms} in Resource Group {$RscGrpname}. Aborting..."
            return
        }
    }
}
# Check if Resource Group param is not passed, but VM Name param is passed
Elseif (!$PSBoundParameters.ContainsKey('RscGrpname') -And $PSBoundParameters.ContainsKey('vmnamespace')) {
    
    If ($PSBoundParameters.ContainsKey('ExcludedRscGrpname'))
    {
        Write-Output "You cannot specify Parameters 'ExcludedRscGrpname' and 'vmnamespace' together"
        return
    }

    If ($PSBoundParameters.ContainsKey('Excludedvmnamespace'))
    {
        Write-Output "You cannot specify Parameters 'Excludedvmnamespace' and 'vmnamespace' together"
        return
    }

    foreach ($vms in $vmnamespace) {
       
        # Find the specific VM resource
        $vmFind = Find-AzureRmResource -ResourceNameEquals $vms

        # If the VM resource is found in the Subscription
        if ($vmFind)
        {
            # Extract the Resource Group Name of the VM
            $RGBaseName = $vmFind.RscGrpname
           
            # Get reference object of the VM
            $vm = Get-AzureRmVm -RscGrpname $RGBaseName -Name $vms
            
            if ($vm) {

                $VMBaseName = $vm.Name

                # Get current status of the VM
                $vmstatus = Get-AzureRmVM -RscGrpname $RGBaseName -Name $VMBaseName -Status

                # Extract current Power State of the VM
                $VMState = $vmstatus.Statuses[1].Code.Split('/')[1]
                    
                if ($VMState) {
                    if ($VMState -in "deallocated","stopped") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently already Deallocated/Stopped. Skipping."
                        continue
                    }
                    elseif ($VMState -in "running","starting") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is currently either already Started or Starting. Stopping..."
                        $retval = Stop-AzureRmVM -RscGrpname $RGBaseName -Name $VMBaseName -AsJob -Force
                        $jobQ.Add($retval) > $null
                    }
                    elseif ($VMState -in "stopping","deallocating") {
                        Write-Output "The VM {$VMBaseName} in Resource Group {$RGBaseName} is in a transient state of Stopping or Deallocating. Skipping."
                        continue
                    }
                }        
                else {
                    Write-Output "Unable to determine PowerState of the VM {$VMBaseName} in Resource Group {$RGBaseName}. Hence, cannot stop the VM. Skipping to next VM..."
                    continue
                }
            }
            else {
                
                Write-Error "There is no Virtual Machine named {$vms} in the Azure Subscription. Aborting..."
                return
            }
        }
        else {
            Write-Output "Could not find Virtual Machine {$vms} in the Azure Subscription."
            continue
        }
    }
}

Get-Job | Wait-Job | Receive-Job > $null

# Stop the Timer
$StopWatch.Stop()

# Display the Elapsed Time
Write-Output "Total Execution Time for Stopping All Target VMs: $($StopWatch.Elapsed.ToString())"

Write-Output "All Target VM's which were Running and not Excluded, have been stopped Successfully!"
