# Move on update - Dynamic OU (based on department)
# Used for: Administration > Organizational unit configuration > "Move account when the account update action is performed" (use PowerShell)
#
# Determines the OU in which the AD account must be placed, based on the department of the primary contract.
# The result is returned as OrganizationalUnit (canonicalName, name, objectGuid) for the HelloID AD OU entitlement.
#
# - The enabled OU and the disabled OU per department are configured in the switches at the top of the script.
# - A department that is not configured in the switches uses the default OU.
# - To base the OU on something else, change the value in the switches, for example the location: $p.Location.Name
# - The enabled/disabled state of the account is NOT used, because accounts can also be created disabled and must not end up in the disabled OU.
#   Instead the current OU of the account is checked: when it is already in the disabled OU (or a sub OU of it) the account is placed in the disabled OU of its department, otherwise in the enabled OU.

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

# Define disabled base OU
# enyoi.local/Disabled users
$disabledBaseOUDistinguishedName = 'OU=Disabled users,DC=enyoi,DC=local'

# Define enabled OU based on department
# enyoi.local/Users/Dept1 - Dept1 & Dept1Team
# enyoi.local/Users/Dept2 - Dept2 & Dept2Team
# enyoi.local/Users/Dept3 - Dept3 & Dept3Team
# enyoi.local/Users/Default - Everything else
$departmentExternalId = $p.PrimaryContract.Department.ExternalId
switch ($departmentExternalId) {
    { $_ -in "Dept1", "Dept1Team" } {
        $enabledOUDistinguishedName = 'OU=Dept1,OU=Users,DC=enyoi,DC=local'
    }
    { $_ -in "Dept2", "Dept2Team" } {
        $enabledOUDistinguishedName = 'OU=Dept2,OU=Users,DC=enyoi,DC=local'
    }
    { $_ -in "Dept3", "Dept3Team" } {
        $enabledOUDistinguishedName = 'OU=Dept3,OU=Users,DC=enyoi,DC=local'
    }
    default {
        $enabledOUDistinguishedName = 'OU=Default,OU=Users,DC=enyoi,DC=local'
    }
}

# Define disabled OU based on department
# enyoi.local/Disabled users/Dept1 - Dept1 & Dept1Team
# enyoi.local/Disabled users/Dept2 - Dept2 & Dept2Team
# enyoi.local/Disabled users/Dept3 - Dept3 & Dept3Team
# enyoi.local/Disabled users/Default - Everything else
switch ($departmentExternalId) {
    { $_ -in "Dept1", "Dept1Team" } {
        $disabledOUDistinguishedName = 'OU=Dept1,OU=Disabled users,DC=enyoi,DC=local'
    }
    { $_ -in "Dept2", "Dept2Team" } {
        $disabledOUDistinguishedName = 'OU=Dept2,OU=Disabled users,DC=enyoi,DC=local'
    }
    { $_ -in "Dept3", "Dept3Team" } {
        $disabledOUDistinguishedName = 'OU=Dept3,OU=Disabled users,DC=enyoi,DC=local'
    }
    default {
        $disabledOUDistinguishedName = 'OU=Default,OU=Disabled users,DC=enyoi,DC=local'
    }
}

try {
    $actionMessage = "determining the OUs based on department [$departmentExternalId]"
    Write-Information "Successfully determined the OUs. Enabled OU: [$enabledOUDistinguishedName], disabled OU: [$disabledOUDistinguishedName]"

    # Get AD account
    $actionMessage = "querying AD user with objectGuid '$($aRef.objectGuid)'"
    $adUser = Get-ADUser -Identity $($aRef.objectGuid) -Properties DistinguishedName
    if ($null -eq $adUser) {
        throw "No AD user with objectGuid '$($aRef.objectGuid)'"
    }

    # The current OU is the parent of the distinguished name of the user
    $currentOUDistinguishedName = ($adUser.DistinguishedName -split '(?<!\\),', 2)[1]
    Write-Information "Successfully queried AD user with objectGuid '$($aRef.objectGuid)'. Current OU: [$currentOUDistinguishedName]"

    # Use the disabled OU when the user is already in the disabled OU (or a sub OU of it), otherwise use the enabled OU
    $actionMessage = "determining the OU based on the current OU [$currentOUDistinguishedName]"
    if ($currentOUDistinguishedName -eq $disabledBaseOUDistinguishedName -or $currentOUDistinguishedName.EndsWith(",$disabledBaseOUDistinguishedName", [System.StringComparison]::OrdinalIgnoreCase)) {
        $ouDistinguishedName = $disabledOUDistinguishedName
        Write-Information "Current OU is in the disabled OU. The account will be placed in OU [$ouDistinguishedName]"
    }
    else {
        $ouDistinguishedName = $enabledOUDistinguishedName
        Write-Information "Current OU is not in the disabled OU. The account will be placed in OU [$ouDistinguishedName]"
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
