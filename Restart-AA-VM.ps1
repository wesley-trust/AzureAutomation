<#

#Script name: Start-AA-VM
#Creator: Wesley Trust
#Date: 2017-10-10
#Revision: 2
#References: Initially based on the Azure Automation Team script from the Azure portal.

.Synopsis
    A script that gets Azure VMs within a resource group, and starts them.
.DESCRIPTION
    A script that gets Azure VMs within a resource group, and starts them,
    when no VMs are specified, all VMs within the resource group are used,
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
    $Started = $true,

    # Stopped Status
    [Parameter(
        Mandatory=$false,
        HelpMessage="If true, stopped VMs will be started."
    )]
    [bool]
    $Stopped = $false
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

#Get VMs, check variables, get status and re/start as needed.
try {
    foreach ($VMName in $VMNames){
        
        # Get VM objects
        $VMObject = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Status -Name $VMName
        
        # If started variable is true, get running VMs to restart.
        if ($Started){
            # Get status
            $VMObjectStarted = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*running*"}
            
            # Restart VM
            Write-Host "Restarting VM:$VMName"
            $VMObjectStarted | Restart-AzureRmVM
        }
        # If stopped variable is true, get stopped VMs to start.
        if ($Stopped){
            #Get status
            $VMObjectStopped = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*deallocated*"}

            #Start VM
            Write-Host "Starting VM:$VMName"
            $VMObjectStopped | Start-AzureRmVM
        }
    }
}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}