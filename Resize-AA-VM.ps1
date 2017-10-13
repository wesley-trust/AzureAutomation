<#
    .DESCRIPTION
        A script that gets Azure VMs within a resource group, and resizes them,
        using the Run As Account (Service Principal) of Azure automation.

    .NOTES
        Initially based on the Azure Automation Team script.
#>

# Parameters
Param(
    # Resource group
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the resource group that all VMs belong to"
    )]
    [string]
    $ResourceGroupName,
    
    # VM Names
    [Parameter(
        Mandatory=$false,
        HelpMessage="Enter VM names in array notation"
    )]
    [string[]]
    $VMNames,

    # VM Size
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter VM size"
    )]
    [string]
    $VMSize
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $ServicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName         

    Write-Host "Authenticating with Azure"
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $ConnectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

if (!$VMNames){
    $VMObjects = Get-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName | Get-AzureRmVM
    $VMNames = ($VMObjects).Name
}

#Get VM object, supported sizes, set size, update VM
try {
    foreach ($VMName in $VMNames){
        
        # Get VM Object
        $VMObject = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VMName

        # If the VM is not already the intended size
        if ($VMObject.HardwareProfile.VmSize -ne $VMSize){

            # Get supported sizes in location of VM
            $SupportedVMSize = Get-AzureRmVMSize -Location $VMObject.Location

            # Invalid size
            if ($SupportedVMSize.name -notcontains $VMSize){
                throw "VM size is invalid or not available in that location."
            }

            # Get supported sizes for VM
            $SupportedVMSize = Get-AzureRmVMSize -ResourceGroupName $ResourceGroupName -VMName $VMName

            # If the VM size is not supported
            if ($SupportedVMSize.name -notcontains $VMSize){

                # Get running status
                $VMStatus = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*running*"}

                # If the VM is running
                if ($VMStatus){

                    # Deallocated VM
                    Write-Host "Stopping VM:$VMName"
                    $VMObject | Stop-AzureRmVM -Force

                    # Get new supported sizes for VM
                    $SupportedVMSize = Get-AzureRmVMSize -ResourceGroupName $ResourceGroupName -VMName $VMName

                    # If the VM size is still not supported
                    if ($SupportedVMSize.name -notcontains $VMSize){
                    
                        # Restart VM
                        Write-Host "Starting VM:$VMName"
                        $VMObject | Start-AzureRmVM
                    }          
                }

                # Unsupported size
                throw "Unsupported size."
            }
                    
            # Set new VM size
            $VMObject.HardwareProfile.VmSize = $VMSize

            # Update VM
            Write-Host "Updating VM:$VMName"
            Update-AzureRmVM -VM $VMObject -ResourceGroupName $ResourceGroupName
        }
        Else {
            throw "VM cannot be resized as it is already the intended size."
        }      
    }
}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}