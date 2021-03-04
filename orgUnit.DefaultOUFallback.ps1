#region Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$a = $accountReference | ConvertFrom-Json
$ma = $managerAccountReference | ConvertFrom-Json
$success = $false

#Get Primary Domain Controller
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Change mapping here
$CalcOrgUnit = ((Get-ADDomain).DNSRoot + "/Student Accounts/Active/{0}/{1}" `
        -f $p.PrimaryContract.Department.ExternalID `
            ,$p.custom.GradYear)
			
$defaultOrgUnit = (Get-ADDomain).DNSRoot + "/Student Accounts"
#endregion Change mapping here

#region Execute
$organizationalUnit = Get-ADOrganizationalUnit -Filter * -Property canonicalName -Server $pdc | ?{$_.canonicalName -eq $CalcOrgUnit}
if($organizationalUnit -ne $null)
{
    $success = $True
    Write-Verbose -Verbose "Found OU: $CalcOrgUnit"
}
else # Check if Default OU Exists
{
    Write-Verbose -Verbose "Did not find OU: $CalcOrgUnit"
    $organizationalUnit = Get-ADOrganizationalUnit -Filter * -Property canonicalName -Server $pdc | ?{$_.canonicalName -eq ($defaultOrgUnit)}
    if($organizationalUnit -ne $null)
    {
        Write-Verbose -Verbose ("Using Default OU: {0}" -f $organizationalUnit.canonicalName)
        $success = $True
    }
    else
    {
        Write-Verbose -Verbose ("Default OU Not Found: {0}" -f $defaultOrgUnit)
    }
}
if($dryRun -eq $True) {
    Write-Verbose -Verbose "Dry run for determining OU"
}
#endregion Execute

#region build up result
$result = [PSCustomObject]@{
    Success = $success
    OrganizationalUnit = $organizationalUnit
};

Write-Output $result | ConvertTo-Json -Depth 2
#endregion build up result
