<#
    .DESCRIPTION
        A runbook workflow that gets Azure VMs within a resource group, and starts them,
        using the Run As Account (Service Principal) of Azure automation.

    .NOTES
        Initially based on the Azure Automation Team script.
#>

# Parameters


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
workflow Start-AAVM {
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
            HelpMessage="Enter VM names in array notation"
        )]
        [string[]]
        $VMNames 
    )
    
    try {
        foreach -parallel ($VMName in $VMNames){
            #Get VM Object
            $VMObject = Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Status -Name $VMName
            #Get status
            $VMObject = $VMObject | Where-Object {($_.Statuses)[1].DisplayStatus -like "*deallocated*"}
    
            #Start VM
            $VMObject | Start-AzureRmVM
        }
    }
    Catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}