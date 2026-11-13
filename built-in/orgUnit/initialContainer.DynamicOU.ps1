# Initial container - Dynamic OU (based on department)
# Used for: Administration > Organizational unit configuration > "Initial container" (use PowerShell)
#
# Determines the OU in which the AD account must be placed when it is created, based on the department of the primary contract.
# The result is returned as OrganizationalUnit (canonicalName, name, objectGuid) for the HelloID AD OU entitlement.
#
# - The OU per department is configured in the switch at the top of the script.
# - A department that is not configured in the switch uses the default OU.
# - To base the OU on something else, change the value in the switch, for example the location: $p.Location.Name

#Initialize default properties
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;
$ma = $managerAccountReference | ConvertFrom-Json;

# The entitlementContext contains the configuration
# - configuration: The configuration that is set in the Custom PowerShell configuration
$eRef = $entitlementContext | ConvertFrom-Json

$success = $false

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Define OU based on department
# enyoi.local/Users/Dept1 - Dept1 & Dept1Team
# enyoi.local/Users/Dept2 - Dept2 & Dept2Team
# enyoi.local/Users/Dept3 - Dept3 & Dept3Team
# enyoi.local/Users/Default - Everything else
$departmentExternalId = $p.PrimaryContract.Department.ExternalId
switch ($departmentExternalId) {
    { $_ -in "Dept1", "Dept1Team" } {
        $ouDistinguishedName = 'OU=Dept1,OU=Users,DC=enyoi,DC=local'
    }
    { $_ -in "Dept2", "Dept2Team" } {
        $ouDistinguishedName = 'OU=Dept2,OU=Users,DC=enyoi,DC=local'
    }
    { $_ -in "Dept3", "Dept3Team" } {
        $ouDistinguishedName = 'OU=Dept3,OU=Users,DC=enyoi,DC=local'
    }
    default {
        $ouDistinguishedName = 'OU=Default,OU=Users,DC=enyoi,DC=local'
    }
}

try {
    $actionMessage = "determining the OU based on department [$departmentExternalId]"
    Write-Information "Successfully determined the OU based on department [$departmentExternalId]: [$ouDistinguishedName]"

    # Get AD OU
    $actionMessage = "querying AD OU with distinguished name [$ouDistinguishedName]"
    $adOU = Get-ADOrganizationalUnit -Identity $ouDistinguishedName -Properties canonicalName, name, objectGuid
    if ($null -eq $adOU) {
        throw "No AD OU found with distinguished name [$ouDistinguishedName]"
    }

    $organizationalUnit = [PSCustomObject]@{
        canonicalName = $adOU.canonicalName
        name          = $adOU.distinguishedName
        objectGuid    = $adOU.objectGuid
    }
    Write-Information "Successfully queried AD OU with distinguished name [$ouDistinguishedName]"

    $success = $true
}
catch {
    $success = $false

    $ex = $PSItem

    $errorMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage

    # Write-Error is used instead of throw, so the finally block still returns the result
    Write-Error $errorMessage
}
finally {
    # Always build up and send back the result, also on failure (Success = false), as HelloID requires an output
    $result = [PSCustomObject]@{
        Success            = $success;
        OrganizationalUnit = $organizationalUnit;
    };

    Write-Output $result | ConvertTo-Json -Depth 2
}
