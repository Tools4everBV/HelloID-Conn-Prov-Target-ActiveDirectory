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

# Calculate AD OU based on location
# The Netherlands - enyoi.local/resources/NL/gebruikers
# Germany - enyoi.local/resources/DE/benutzer
# America - enyoi.local/resources/USA/users
Write-Verbose "Location: '$($p.Location.Name)'"
switch ($p.Location.Name) {
    "The Netherlands" {
        $enabledBaseOULDAPFilter = '(name=NL)'
        $enabledOULDAPFilter = '(name=gebruikers)'
    }
    "Germany" {
        $enabledBaseOULDAPFilter = '(name=DE)'
        $enabledOULDAPFilter = '(name=benutzer)'
    }
    "America" {
        $enabledBaseOULDAPFilter = '(name=USA)'
        $enabledOULDAPFilter = '(name=users)'
    }
    default {
        $enabledBaseOULDAPFilter = '(name=resources)'
        $enabledOULDAPFilter = '(name=users)'
    }
}
Write-Verbose "enabledBaseOULDAPFilter: '$($enabledBaseOULDAPFilter)'"
Write-Verbose "enabledOULDAPFilter: '$($enabledOULDAPFilter)'"

# Calculate AD OU based on location
# The Netherlands - enyoi.local/resources/NL/geblokkeerde gebruikers
# Germany - enyoi.local/resources/DE/behinderte benutzer
# America - enyoi.local/resources/USA/disabled users
Write-Verbose "Location: '$($p.Location.Name)'"
switch ($p.Location.Name) {
    "The Netherlands" {
        $disabledBaseOULDAPFilter = '(name=NL)'
        $disabledOULDAPFilter = '(name=geblokkeerde gebruikers)'
    }
    "Germany" {
        $disabledBaseOULDAPFilter = '(name=DE)'
        $disabledOULDAPFilter = '(name=behinderte benutzer)'
    }
    "America" {
        $disabledBaseOULDAPFilter = '(name=USA)'
        $disabledOULDAPFilter = '(name=disabled users)'
    }
    default {
        $disabledBaseOULDAPFilter = '(name=resources)'
        $disabledOULDAPFilter = '(name=Disabled users)'
    }
}
Write-Verbose "disabledBaseOULDAPFilter: '$($disabledBaseOULDAPFilter)'"
Write-Verbose "disabledOULDAPFilter: '$($disabledOULDAPFilter)'"

# Get AD account
try {
    Write-Verbose "Querying AD user with objectGuid '$($aRef.objectGuid)'"
    $properties = @('SID', 'ObjectGuid', 'UserPrincipalName', 'SamAccountName', 'Enabled')
    $adUser = Get-ADUser -Identity $($aRef.objectGuid) -Properties $properties | Select-Object $properties
    if ($null -ne $adUser) {
        Write-Verbose "Succesfully queried AD user with objectGuid '$($aRef.objectGuid)'"
    }
    else {
        throw "No AD user with objectGuid '$($aRef.objectGuid)'"
    }

    # Search enabled or disabled OU based on account state
    if ($adUser.Enabled -eq $true) {
        $baseOULDAPFilter = $enabledBaseOULDAPFilter
        $OULDAPFilter = $enabledOULDAPFilter
    }
    else {
        $baseOULDAPFilter = $disabledBaseOULDAPFilter
        $OULDAPFilter = $disabledOULDAPFilter
    }
}
catch {
    $success = $false;

    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    throw "Could not query AD user with objectGuid '$($aRef.objectGuid)'. Error: $($ex.Exception.Message)"
}

# Get AD Base OU
try {
    Write-Verbose "Querying Base AD OU where $($baseOULDAPFilter)"

    $baseAdOU = Get-ADOrganizationalUnit -LDAPFilter $baseOULDAPFilter -Properties distinguishedName
    if ($null -ne $baseAdOU) {
        Write-Verbose "Succesfully queried Base AD OU where $($baseOULDAPFilter): $($baseAdOU.distinguishedName)"
    }
    else {
        throw "No AD OU where $($baseOULDAPFilter)"
    }
}
catch {
    $success = $false;

    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    throw "Could not query Base AD OU where $($baseOULDAPFilter). Error: $($ex.Exception.Message)"
}

# Get AD Base location OU
try {
    Write-Verbose "Querying AD OU where $($OULDAPFilter) in SearchBase $($baseAdOU.distinguishedName)"

    $adOU = Get-ADOrganizationalUnit -LDAPFilter $OULDAPFilter -Properties canonicalName, name, objectGuid -SearchBase $($baseAdOU.distinguishedName)
    if ($null -ne $adOU) {
        $organizationalUnit = [PSCustomObject]@{
            canonicalName = $adOU.canonicalName
            name          = $adOU.distinguishedName
            objectGuid    = $adOU.objectGuid
        }
    }
    else {
        throw "No AD OU where $($OULDAPFilter)"
    }

    $success = $true;
    Write-Verbose "Succesfully queried AD OU where $($OULDAPFilter) in SearchBase $($baseAdOU.distinguishedName)"
}
catch {
    $success = $false;

    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    throw "Could not query AD OU where $($OULDAPFilter) in SearchBase $($baseAdOU.distinguishedName). Error: $($ex.Exception.Message)"
}

#build up result
$result = [PSCustomObject]@{
    Success            = $success;
    OrganizationalUnit = $organizationalUnit;
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 2