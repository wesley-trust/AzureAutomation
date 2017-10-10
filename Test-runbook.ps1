<#
    .DESCRIPTION
        An example runbook which gets all the ARM VMs using the Run As Account (Service Principal)

    .NOTES
        Based on the Azure Automation Team script   
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
        Mandatory=$true,
        HelpMessage="Enter VM names, comma separated"
    )]
    [string[]]
    $VMNames
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Get VM with specific name that is deallocated
try {
    foreach ($VMName in $VMNames){
        #Get VM Object
        $VMObject = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Status -Name $VMName | Where-Object PowerState -like "*deallocated*"
        
        #Start VM
        $VMObject | Start-AzureRmVM
    }
}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}