#Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$location = $p.primaryContract.Location.Code

# The entitlementContext contains the domainController, adUser, configuration, exchangeConfiguration and exportData
# - domainController: The IpAddress and name of the domain controller used to perform the action on the account
# - adUser: Information about the adAccount: objectGuid, samAccountName and distinguishedName
# - configuration: The configuration that is set in the Custom PowerShell configuration
# - exchangeConfiguration: The configuration that was used for exchange if exchange is turned on
# - exportData: All mapping fields where 'Store this field in person account data' is turned on
$eRef = $entitlementContext | ConvertFrom-Json
$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()

# logging preferences
$verbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Get Current Account
$properties = @('SID', 'ObjectGuid', 'UserPrincipalName', 'SamAccountName', 'Description')
$previousAccount = Get-ADUser -Identity $aRef.ObjectGuid -Properties $properties -Server $eRef.domainController.Name | Select-Object $properties

#region Change mapping here
$currentDate = (Get-Date).ToString("dd/MM/yyyy hh:mm:ss")
$account = @{
    Identity  = $aRef.ObjectGuid
    Description = "Enabled by HelloID at $currentDate"
}

#endregion Change mapping here

if (-Not($dryRun -eq $true)) {
    # HomeDir
    try {
        Write-Verbose "Updating AD account $($account.Identity). Previous Description: $($previousAccount.Description). New Description: '$($account.Description)'"
        $updateUser = Set-ADUser @account -ErrorAction Stop
        Write-Information "Succesfully updated AD account $($account.Identity). Previous Description: '$($previousAccount.Description)'. New Description: '$($account.Description)'"

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "EnableAccount"
                Message = "Succesfully updated AD account $($account.Identity). Previous Description: '$($previousAccount.Description)'. New Description: '$($account.Description)'"
                IsError = $False
            })
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to update AD account $($account.Identity). Previous Description: '$($previousAccount.Description)'. New Description: '$($account.Description)'. Error: $($_)"
                IsError = $True
            })
        throw $_
    }
}
else {
    # Write dry run logic here
}

#build up result
$result = [PSCustomObject]@{
    Success   = $success
    AuditLogs = $auditLogs

    # Return data for use in other systems.
    # If not present or empty the default export data will be used
    # ExportData = [PSCustomObject]@{}
}

#send result back
Write-Output $result | ConvertTo-Json -Depth 10