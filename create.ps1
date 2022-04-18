#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

#Get Primary Domain Controller
try{
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
#endregion Initialize default properties

#region Support Functions
function Get-ConfigProperty
{
    [cmdletbinding()]
    Param (
        [object]$object,
        [string]$property
    )
    Process {
        $subItems = $property.split('.')
        $value = $object.psObject.copy()
        for($i = 0; $i -lt $subItems.count; $i++)
        {
            $value = $value."$($subItems[$i])"
        }
        return $value
    }
}
#endregion Support Functions

#region Change mapping here
    #Correlation
    $correlationPersonField = Get-ConfigProperty -object $p -property ($config.correlationPersonField -replace '\$p.','')
    $correlationAccountField = $config.correlationAccountField
#endregion Change mapping here

#region Execute
try{
    #Find AD ACcount by employeeID attribute
    $filter = "($($correlationAccountField)=$($correlationPersonField))";
    Write-Information "LDAP Filter: $($filter)";
    
	$account = Get-ADUser -LdapFilter $filter -Property sAMAccountName -Server $pdc
	
    if($account -eq $null) { throw "Failed to return a account" }

    Write-Information "Account correlated to $($account.sAMAccountName)";

	$auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Account correlated to $($account.sAMAccountName)";
                IsError = $false;
            });
	
    $success = $true;
}
catch
{
    $auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Account failed to correlate:  $_"
                IsError = $True
            });
	Write-Error $_;
}
#endregion Execute

#region build up result
$result = [PSCustomObject]@{
    Success= $success;
    AccountReference= $account.SID.Value
    AuditLogs = $auditLogs
    Account = $account;
};

Write-Output $result | ConvertTo-Json -Depth 10
#endregion build up result