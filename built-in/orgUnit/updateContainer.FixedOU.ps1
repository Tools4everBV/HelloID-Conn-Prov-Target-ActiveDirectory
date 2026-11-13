# Move on update - Dynamic OU (fixed enabled and disabled OU)
# Used for: Administration > Organizational unit configuration > "Move account when the account update action is performed" (use PowerShell)
#
# Determines the OU in which the AD account must be placed.
# The result is returned as OrganizationalUnit (canonicalName, name, objectGuid) for the HelloID AD OU entitlement.
#
# - The enabled OU and the disabled OU are fixed and configured at the top of the script.
# - The enabled/disabled state of the account is NOT used, because accounts can also be created disabled and must not end up in the disabled OU.
#   Instead the current OU of the account is checked: when it is already in the disabled OU it stays there, otherwise the enabled OU is used.

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

# Define enabled OU
# enyoi.local/Users
$enabledOUDistinguishedName = 'OU=Users,DC=enyoi,DC=local'

# Define disabled OU
# enyoi.local/Disabled users
$disabledOUDistinguishedName = 'OU=Disabled users,DC=enyoi,DC=local'

try {
    # Get AD account
    $actionMessage = "querying AD user with objectGuid '$($aRef.objectGuid)'"
    $adUser = Get-ADUser -Identity $($aRef.objectGuid) -Properties DistinguishedName
    if ($null -eq $adUser) {
        throw "No AD user with objectGuid '$($aRef.objectGuid)'"
    }

    # The current OU is the parent of the distinguished name of the user
    $currentOUDistinguishedName = ($adUser.DistinguishedName -split '(?<!\\),', 2)[1]
    Write-Information "Successfully queried AD user with objectGuid '$($aRef.objectGuid)'. Current OU: [$currentOUDistinguishedName]"

    # Keep the user in the disabled OU when it is already there, otherwise use the enabled OU
    $actionMessage = "determining the OU based on the current OU [$currentOUDistinguishedName]"
    if ($currentOUDistinguishedName -eq $disabledOUDistinguishedName) {
        $ouDistinguishedName = $disabledOUDistinguishedName
        Write-Information "Current OU is the disabled OU. The account stays in OU [$ouDistinguishedName]"
    }
    else {
        $ouDistinguishedName = $enabledOUDistinguishedName
        Write-Information "Current OU is not the disabled OU. The account will be placed in OU [$ouDistinguishedName]"
    }

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
