<#
    .DESCRIPTION
        A script that gets Azure VMs within a resource group, and stops them,
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
    $VMNames 
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

#Get VMs with deallocated status and stops
try {
    foreach ($VMName in $VMNames){
        $VMObject = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Status -Name $VMName
        
        #Get status
        $VMObject = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*running*"}

        #Start VM
        Write-Host "Stopping VM:$VMName"
        $VMObject | Stop-AzureRmVM -Force
    }
}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}