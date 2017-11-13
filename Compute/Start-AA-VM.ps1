<#

#Script name: Start-AA-VM
#Creator: Wesley Trust
#Date: 2017-10-10
#Revision: 2
#References: Initially based on the Azure Automation Team script from the Azure portal.

.Synopsis
    A script that gets Azure VMs within a resource group, starts them or restarts if running and parameter set.
.DESCRIPTION
    A script that gets Azure VMs within a resource group, starts them or restarts if running and parameter set.
    When no VMs are specified, all VMs within the resource group are used,
    designed to run in Azure Automation using the Run As Account (Service Principal).

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

    # Started Status
    [Parameter(
        Mandatory=$false,
        HelpMessage="If true, started VMs will be restarted."
    )]
    [bool]
    $RestartRunningVM = $false

)

# Azure Automation authentication
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

#Get VMs, check variables, get status and re/start as needed.
try {

    # Get the resource group to check it exists, store in variable, if not catch exception
    $ResourceGroup = Get-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName

    # If no VMs are specified in the parameter, get Get VM names from resource group
    if (!$VMNames){
        $VMObjects = $ResourceGroup | Get-AzureRmVM
        $VMNames = ($VMObjects).Name
    }
    
    # If there are still no VMs, throw exception
    if (!$VMNames){
        throw "No VMs to start"
    }

    # Process
    foreach ($VMName in $VMNames){

        # Get VM objects
        $VMObject = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Status -Name $VMName
        
        # Get status
        $VMObjectStopped = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*deallocated*"}
        
        # Start VM
        Write-Host "Starting VM:$VMName"
        $VMObjectStopped | Start-AzureRmVM

        # If variable is true, get running VMs and restart.
        if ($RestartRunningVM){
            # Get status
            $VMObjectStarted = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*running*"}
            
            # Restart VM
            Write-Host "Restarting VM:$VMName"
            $VMObjectStarted | Restart-AzureRmVM
        }
    }
}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}