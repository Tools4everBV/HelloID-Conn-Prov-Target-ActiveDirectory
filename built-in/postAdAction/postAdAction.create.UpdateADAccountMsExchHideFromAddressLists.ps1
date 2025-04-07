#Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json

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

#region Change mapping here
$account = @{
    Identity                   = $eRef.adUser.ObjectGuid
    msExchHideFromAddressLists = $true
}
#endregion Change mapping here

if (-Not($dryRun -eq $true)) {
    try {
        # Get Current Account
        $properties = @('SID', 'ObjectGuid', 'UserPrincipalName', 'SamAccountName', 'msExchHideFromAddressLists')
        $previousAccount = Get-ADUser -Identity $account.Identity -Properties $properties -Server $eRef.domainController.Name | Select-Object $properties

        Write-Verbose "Updating AD account $($account.Identity). Previous msExchHideFromAddressLists: $($previousAccount.msExchHideFromAddressLists). New msExchHideFromAddressLists: '$($account.msExchHideFromAddressLists)'"
        $updateUser = Set-ADUser -Identity $account.Identity -Replace @{msExchHideFromAddressLists = $account.msExchHideFromAddressLists } -Server $eRef.domainController.Name -ErrorAction Stop
        Write-Information "Succesfully updated AD account $($account.Identity). Previous msExchHideFromAddressLists: '$($previousAccount.msExchHideFromAddressLists)'. New msExchHideFromAddressLists: '$($account.msExchHideFromAddressLists)'"

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Succesfully updated AD account $($account.Identity). Previous msExchHideFromAddressLists: '$($previousAccount.msExchHideFromAddressLists)'. New msExchHideFromAddressLists: '$($account.msExchHideFromAddressLists)'"
                IsError = $False
            })
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to update AD account $($account.Identity). Previous msExchHideFromAddressLists: '$($previousAccount.msExchHideFromAddressLists)'. New msExchHideFromAddressLists: '$($account.msExchHideFromAddressLists)'. Error: $($_)"
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