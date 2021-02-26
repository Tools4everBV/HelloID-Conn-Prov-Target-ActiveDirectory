#Initialize default properties
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json

$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

#Get Primary Domain Controller
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator

try{
    #Find AD ACcount by employeeID attribute
	$account = Get-ADUser -LdapFilter "(employeeId=$($p.externalId))" -Property sAMAccountName -Server $pdc
	
	$auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Account correlated to $($account.sAMAccountName)";
                IsError = $false;
            });
	
    $success = $true;
}
catch
{
    auditLogs.Add([PSCustomObject]@{
                Action = "CreateAccount"
                Message = "Account failed to correlate:  $_"
                IsError = $True
            });
	Write-Error $_;
}

#build up result
$result = [PSCustomObject]@{
    Success= $success;
    AccountReference= $account.SID.Value
    AuditLogs = $auditLogs
    Account = $account;
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 10