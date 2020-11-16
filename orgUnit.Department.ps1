#Initialize default properties
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$a = $accountReference | ConvertFrom-Json;
$ma = $managerAccountReference | ConvertFrom-Json;

switch($p.PrimaryContract.Department.ExternalId)
{
    "102" { $LocationPath = "domain.local/Students/Elementary" }
    default { $LocationPath = "lwsd.wednet.edu/Students/Unassigned" }
}

Write-Verbose -Verbose "Mapped Location: $($LocationPath)"

try
{
    $OUResult = (Get-ADOrganizationalUnit -Filter * -Properties CanonicalName,ObjectGUID,Name).Where({$_.CanonicalName -eq $LocationPath})
    $organizationalUnit = $OUResult[0] | Select CanonicalName, Name, ObjectGUID
    
    $success = $True;

}
catch
{
    Write-Verbose -Verbose "Failed to retrieve OU $($_)";
    $success = $False;
}

#build up result
$result = [PSCustomObject]@{
	Success = $success;
	OrganizationalUnit = $organizationalUnit;
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 2
