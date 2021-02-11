#Initialize default properties
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json;
$pp = $previousPerson | ConvertFrom-Json;
$pd = $personDifferences | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$success = $False;
$auditMessage = "for person " + $p.DisplayName;
Write-Verbose -Verbose ($p | ConvertTo-Json -Depth 50)
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
try{
    $account = Get-ADUser -LdapFilter "(employeeId=$($p.externalId))" -Server $pdc
    $success = $true;
    $auditMessage = "for person " + $p.DisplayName;
}
catch
{
    $auditMessage = "$($_)";
}
#build up result
$result = [PSCustomObject]@{
    Success= $success;
    AccountReference= $account.SID.Value
    AuditDetails=$auditMessage;
    Account = $account;
};
#send result back
Write-Output $result | ConvertTo-Json -Depth 10