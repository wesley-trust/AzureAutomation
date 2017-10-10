<#
    .DESCRIPTION
        An example runbook which gets all the ARM VMs using the Run As Account (Service Principal)

    .NOTES
        Based on the Azure Automation Team script   
#>

# Parameters
Param(
    [Parameter(Mandatory)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory)]
    [string]
    $VMName
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
    $VMs = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Status -Name $VMName
}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#If no VMs are returned throw exception
if (!$VMs){
    throw "No VMs to be started."
}

#Else start VMs
Else {
    foreach ($VM in $VMs) {
        $VM | Start-AzureRmVM
    }
}