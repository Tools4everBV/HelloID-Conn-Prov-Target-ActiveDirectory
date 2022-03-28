#Initialize default properties
$p    = $person | ConvertFrom-Json
$m    = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
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
$adUser = Get-ADUser $eRef.adUser.ObjectGuid

$calcDirectory = "\\server\share\optional-folder\$($adUser.sAMAccountName)"
Write-Verbose "HomeDir path: $($calcDirectory)"

$target = @{
    ad_user      = $adUser
    path         = $calcDirectory
    fsr          = [System.Security.AccessControl.FileSystemRights]"FullControl" #File System Rights
    act          = [System.Security.AccessControl.AccessControlType]::Allow #Access Control Type
    inf          = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit" #Inheritance Flags
    pf           = [System.Security.AccessControl.PropagationFlags]"InheritOnly" #Propagation Flags
}

#endregion Change mapping here

if (-Not($dryRun -eq $true)) {
    # Write create logic here
    try {
        $path_exists = test-path $target.path
        if (-Not $path_exists) {
            $success = $false
            $auditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "Failed to grant permissions $($target.fsr) for user $($target.ad_user.distinguishedName) to directory $($target.path). Error: No directory found at path: $($target.path)"
                    IsError = $True
                })
            Write-Error "No directory found at path: $($target.path)"                
        }

        #Return ACL to modify
        $acl = Get-Acl $target.path
        
        #Assign rights to user
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($target.ad_user.SID, $target.fsr, $target.inf, $target.pf, $target.act)
        $acl.AddAccessRule($accessRule)

        Write-Verbose "Setting ACL permissions. File System Rights:$($target.fsr), Inheritance Flags:$($target.inf), Propagation Flags:$($target.pf), Access Control Type:$($target.act) for user $($target.ad_user.distinguishedName)"
        $job = Start-Job -ScriptBlock { Set-Acl -path $args[0].path -AclObject $args[1] } -ArgumentList @($target, $acl)
        Write-Information "Succesfully set ACL permissions. FSR:$($target.fsr), InF:$($target.inf), PF:$($target.pf), ACT:$($target.act) for user $($target.ad_user.distinguishedName)"

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Successfully granted permissions $($target.fsr) for user $($target.ad_user.distinguishedName) to directory $($target.path)"
                IsError = $False
            })

        # Update aRef with Home Dir path
        $aRef.HomeDirectory = $target.path
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to grant permissions $($target.fsr) for user $($target.ad_user.distinguishedName) to directory $($target.path). Error: $($_)"
                IsError = $True
            })
        throw $_
    }
} else {
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