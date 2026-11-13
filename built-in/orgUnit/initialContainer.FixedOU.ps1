# Initial container - Fixed OU
# Used for: Administration > Organizational unit configuration > "Initial container" (use PowerShell)
#
# Determines the OU in which the AD account must be placed when it is created.
# The result is returned as OrganizationalUnit (canonicalName, name, objectGuid) for the HelloID AD OU entitlement.
#
# - The OU is fixed and configured at the top of the script.

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

# Define OU
# enyoi.local/Users
$ouDistinguishedName = 'OU=Users,DC=enyoi,DC=local'

try {
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
