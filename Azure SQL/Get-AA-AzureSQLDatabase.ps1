<#

#Script name: Get-AA-AzureSQLDatabase
#Creator: Wesley Trust
#Date: 2017-11-13
#Revision: 1
#References: Initially based on the Azure Automation Team script from the Azure portal.

.Synopsis
    A script that gets SQL databases on a specific server, excluding any specified pools.
.DESCRIPTION
    A script that gets SQL databases on a specific server, excluding any specified pools,
    when no SQL pools are specified, all databases on the server are returned (excluding master),
    includes error checking for whether the SQL server exists,
    designed to run in Azure Automation using the Run As Account (Service Principal).

#>

# Parameters
Param(
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the resource group that all VMs belong to"
    )]
    [string]
    $ResourceGroupName,
    
    # SQL Server
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the SQL Server to check"
    )]
    [string]
    $SQLServer,

    # SQL Pools
    [Parameter(
        Mandatory=$false,
        HelpMessage="Enter the SQL Elastic Pools to check (if any)"
    )]
    [string[]]
    $SQLPools,

    # SQL Pool Exclusion
    [Parameter(
        Mandatory=$false,
        HelpMessage="Specify whether to exclude database from specified pools"
    )]
    [bool]
    $SQLPoolExclusion = $true,

    # Email Username
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the email server username"
    )]
    [string]
    $EmailUsername,

    # Email password
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the email server password"
    )]
    [string]
    $PlainTextPass,

    # SMTP Server
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the SMTP Server"
    )]
    [string]
    $SMTPServer,

    # Email To
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the recipient email address"
    )]
    [string]
    $ToAddress,

    # Email From
    [Parameter(
        Mandatory=$true,
        HelpMessage="Enter the sender email address"
    )]
    [string]
    $FromAddress

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

try {

    # Get SQL Server from resource, causes exception if group, or server do not exist.
    Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SQLServer

    # Get all databases from SQL server
    $SQLDatabases = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SQLServer

    # If SQL Pool exclusion is true
    if ($SQLPoolExclusion){

        # For each pool, exclude the SQL Pool databases
        foreach ($SQLPool in $SQLPools){
            $SQLDatabases = $SQLDatabases | Where-Object {$_.elasticpoolname -ne $SQLPool}
        }
    }

    #Exclude master database
    $SQLDatabases = $SQLDatabases | Where-Object {$_.DatabaseName -notmatch "Master"}

    # If there are databases
    if ($SQLDatabases){

        # Set subject and body
        $Subject =  "Databases not in an Elastic Pool on SQL Server $SQLServer"
        $Body = $SQLDatabases.DatabaseName
        $Body = [string]::join("<br/>",$body)

        
        # Build Email Credential
        $EmailPassword = ConvertTo-SecureString $PlainTextPass -AsPlainText -Force
        $EmailCredential = New-Object System.Management.Automation.PSCredential ($EmailUsername, $EmailPassword)
        
        # Send email
        Send-MailMessage `
            -Credential $EmailCredential `
            -SmtpServer $SMTPServer `
            -To $ToAddress `
            -From $FromAddress `
            -Subject $Subject `
            -BodyAsHtml `
            -Body $Body
    }
    Else {
        Write-Output "No databases found."
    }

}
Catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}