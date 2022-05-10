#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

#Get Primary Domain Controller
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Execute
try{
    $sAMAccountName = $p.accounts.MicrosoftActiveDirectory.sAMAccountName 
    Write-Information "Identity: $($sAMAccountName)";
    
	$account = Get-ADUser -Identity $sAMAccountName -Property sAMAccountName -Server $pdc
	
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
    AuditLogs = $auditLogs;
    Account = $account;
};

Write-Output $result | ConvertTo-Json -Depth 10
#endregion build up result