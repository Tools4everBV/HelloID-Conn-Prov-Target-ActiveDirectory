#Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$a = $accountReference | ConvertFrom-Json
$ma = $managerAccountReference | ConvertFrom-Json
$success = $false
$calc_org_unit = ((Get-ADDomain).DNSRoot + "/Student Accounts/Active/{0}/{1}" `
        -f $p.PrimaryContract.Department.ExternalID `
            ,$p.custom.GradYear)
$default_org_unit = (Get-ADDomain).DNSRoot + "/Student Accounts"
$organizationalUnit = Get-ADOrganizationalUnit -Filter * -Property canonicalName | ?{$_.canonicalName -eq $calc_org_unit}
if($organizationalUnit -ne $null)
{
    $success = $True
    Write-Verbose -Verbose "Found OU: $calc_org_unit"
}
else # Check if Default OU Exists
{
    Write-Verbose -Verbose "Did not find OU: $calc_org_unit"
    $organizationalUnit = Get-ADOrganizationalUnit -Filter * -Property canonicalName | ?{$_.canonicalName -eq ($default_org_unit)}
    if($organizationalUnit -ne $null)
    {
        Write-Verbose -Verbose ("Using Default OU: {0}" -f $organizationalUnit.canonicalName)
        $success = $True
    }
    else
    {
        Write-Verbose -Verbose ("Default OU Not Found: {0}" -f $default_org_unit)
    }
}
if($dryRun -eq $True) {
    Write-Verbose -Verbose "Dry run for determining OU"
}
#build up result
$result = [PSCustomObject]@{
    Success = $success
    OrganizationalUnit = $organizationalUnit
};
#send result back
Write-Output $result | ConvertTo-Json -Depth 2
