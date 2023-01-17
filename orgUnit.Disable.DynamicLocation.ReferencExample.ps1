#Initialize default properties
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$a = $accountReference | ConvertFrom-Json;
$ma = $managerAccountReference | ConvertFrom-Json;

# The entitlementContext contains the configuration
# - configuration: The configuration that is set in the Custom PowerShell configuration
$eRef = $entitlementContext | ConvertFrom-Json

$success = $false

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Calculate AD OU based on location
# The Netherlands - enyoi.local/resources/NL/geblokkeerde gebruikers
# Germany - enyoi.local/resources/DE/behinderte benutzer
# America - enyoi.local/resources/USA/disabled users
Write-Verbose "Location: '$($p.Location.Name)'"
switch ($p.Location.Name) {
    "The Netherlands" {
        $baseOULDAPFilter = '(name=NL)'
        $ouLDAPFilter = '(name=geblokkeerde gebruikers)'
    }
    "Germany" {
        $baseOULDAPFilter = '(name=DE)'
        $ouLDAPFilter = '(name=behinderte benutzer)'
    }
    "America" {
        $baseOULDAPFilter = '(name=USA)'
        $ouLDAPFilter = '(name=disabled users)'
    }
    default {
        $baseOULDAPFilter = '(name=resources)'
        $ouLDAPFilter = '(name=Disabled users)'
    }
}
Write-Verbose "baseOULDAPFilter: '$($baseOULDAPFilter)'"
Write-Verbose "ouLDAPFilter: '$($ouLDAPFilter)'"

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

try {
    Write-Verbose "Querying AD OU where $($ouLDAPFilter) in SearchBase $($baseAdOU.distinguishedName)"

    $adOU = Get-ADOrganizationalUnit -LDAPFilter $ouLDAPFilter -Properties canonicalName, name, objectGuid -SearchBase $($baseAdOU.distinguishedName)
    if ($null -ne $adOU) {
        $organizationalUnit = [PSCustomObject]@{
            canonicalName = $adOU.canonicalName
            name          = $adOU.distinguishedName
            objectGuid    = $adOU.objectGuid
        }
    }
    else {
        throw "No AD OU where $($ouLDAPFilter)"
    }

    $success = $true;
    Write-Verbose "Succesfully queried AD OU where $($ouLDAPFilter) in SearchBase $($baseAdOU.distinguishedName)"
}
catch {
    $success = $false;

    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    throw "Could not query AD OU where $($ouLDAPFilter) in SearchBase $($baseAdOU.distinguishedName). Error: $($ex.Exception.Message)"
}

#build up result
$result = [PSCustomObject]@{
    Success            = $success;
    OrganizationalUnit = $organizationalUnit;
};

#send result back
Write-Output $result | ConvertTo-Json -Depth 2