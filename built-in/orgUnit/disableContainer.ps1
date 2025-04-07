# Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$a = $accountReference | ConvertFrom-Json
$ma = $managerAccountReference | ConvertFrom-Json

# The entitlementContext contains the configuration
# - configuration: The configuration that is set in the Custom PowerShell configuration
$eRef = $entitlementContext | ConvertFrom-Json

$success = $false

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Calculate AD OU based on department
# example.com/Disabled Users/Dept1 - Dept1 & Dept1Team
# example.com/Disabled Users/Dept2 - Dept2 & Dept2Team
# example.com/Disabled Users/Dept3 - Dept3 & Dept3Team
# example.com/Disabled Users/Default - Everything else
Write-Verbose "Department: '$($p.PrimaryContract.Department.ExternalId)'"
switch ($p.PrimaryContract.Department.ExternalId) {
    { $_ -in "Dept1", "Dept1Team" } {
        $ouDistinguishedName = 'OU=Dept1,OU=Disabled Users,DC=example,DC=com'
    }
    { $_ -in "Dept2", "Dept2Team" } {
        $ouDistinguishedName = 'OU=Dept2,OU=Disabled Users,DC=example,DC=com'
    }
    { $_ -in "Dept3", "Dept3Team" } {
        $ouDistinguishedName = 'OU=Dept3,OU=Disabled Users,DC=example,DC=com'
    }
    default {
        $ouDistinguishedName = 'OU=Default,OU=Disabled Users,DC=example,DC=com'
    }
}
Write-Verbose "ouDistinguishedName: '$($ouDistinguishedName)'"

try {
    Write-Verbose "Querying AD OU [$ouDistinguishedName]"

    $adOU = Get-ADOrganizationalUnit -Identity $ouDistinguishedName -Properties canonicalName, name, objectGuid
    if ($null -ne $adOU) {
        $organizationalUnit = [PSCustomObject]@{
            canonicalName = $adOU.canonicalName
            name          = $adOU.distinguishedName
            objectGuid    = $adOU.objectGuid
        }
    }
    else {
        throw "No AD OU found with Distinguished Name [$ouDistinguishedName]"
    }

    $success = $true
    Write-Verbose "Successfully queried AD OU [$ouDistinguishedName]"
}
catch {
    $success = $false

    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    throw "Could not query AD OU with Distinguished Name [$ouDistinguishedName]. Error: $($ex.Exception.Message)"
}

# Build up result
$result = [PSCustomObject]@{
    Success            = $success
    OrganizationalUnit = $organizationalUnit
};

# Send result back
Write-Output $result | ConvertTo-Json -Depth 2