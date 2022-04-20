#Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
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

# HomeDir
$HomeDirPath = "\\server\share\optional-folder\$($adUser.sAMAccountName)"
Write-Verbose "HomeDir path: $($HomeDirPath)"

# Permissions options:
# Apply to this folder, subfolder and files:
#   InheritanceFlags = "ContainerInherit, ObjectInherit"
#   PropagationFlags = "None"

# Apply to subfolder and files:
#   InheritanceFlags = "ContainerInherit, ObjectInherit"
#   PropagationFlags = "InheritOnly"

$targetHome = @{
    ad_user = $adUser
    path    = $HomeDirPath
    fsr     = [System.Security.AccessControl.FileSystemRights]"FullControl" # Optiong can de found at Microsoft docs: https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights?view=net-6.0
    act     = [System.Security.AccessControl.AccessControlType]::Allow # Options: Allow , Remove
    inf     = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit" # Options: None , ContainerInherit , ObjectInherit
    pf      = [System.Security.AccessControl.PropagationFlags]"None" # Options: None , NoPropagateInherit , InheritOnly
}

# ProfileDir
$ProfileDirPath = "\\server\share\optional-folder\$($adUser.sAMAccountName)"
Write-Verbose "ProfileDir path: $($ProfileDirPath)"

$targetProfile = @{
    ad_user = $adUser
    path    = $ProfileDirPath
    fsr     = [System.Security.AccessControl.FileSystemRights]"FullControl" # Optiong can de found at Microsoft docs: https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights?view=net-6.0
    act     = [System.Security.AccessControl.AccessControlType]::Allow # Options: Allow , Remove
    inf     = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit" # Options: None , ContainerInherit , ObjectInherit
    pf      = [System.Security.AccessControl.PropagationFlags]"None" # Options: None , NoPropagateInherit , InheritOnly
}

#endregion Change mapping here

if (-Not($dryRun -eq $true)) {
    # HomeDir
    try {
        $homeDirExists = test-path $targetHome.path
        if (-Not $homeDirExists) {
            $success = $false
            $auditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "Failed to grant permissions $($targetHome.fsr) for user $($targetHome.ad_user.distinguishedName) to directory $($targetHome.path). Error: No directory found at path: $($targetHome.path)"
                    IsError = $True
                })
            Write-Error "No directory found at path: $($targetHome.path)"                
        }

        #Return ACL to modify
        $acl = Get-Acl $targetHome.path
        
        #Assign rights to user
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($targetHome.ad_user.SID, $targetHome.fsr, $targetHome.inf, $targetHome.pf, $targetHome.act)
        $acl.AddAccessRule($accessRule)

        Write-Verbose "Setting ACL permissions. File System Rights:$($targetHome.fsr), Inheritance Flags:$($targetHome.inf), Propagation Flags:$($targetHome.pf), Access Control Type:$($targetHome.act) for user $($targetHome.ad_user.distinguishedName) to directory $($targetHome.path)"
        $job = Start-Job -ScriptBlock { Set-Acl -path $args[0].path -AclObject $args[1] } -ArgumentList @($targetHome, $acl)
        Write-Information "Succesfully set ACL permissions. FSR:$($targetHome.fsr), InF:$($targetHome.inf), PF:$($targetHome.pf), ACT:$($targetHome.act) for user $($targetHome.ad_user.distinguishedName) to directory $($targetHome.path)"

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Successfully granted permissions $($targetHome.fsr) for user $($targetHome.ad_user.distinguishedName) to directory $($targetHome.path)"
                IsError = $False
            })
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to grant permissions $($targetProfile.fsr) for user $($targetProfile.ad_user.distinguishedName) to directory $($targetHome.path). Error: $($_)"
                IsError = $True
            })
        throw $_
    }

    # ProfileDir
    try {
        $profileDirExists = test-path $targetProfile.path
        if (-Not $profileDirExists) {
            $success = $false
            $auditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "Failed to grant permissions $($targetProfile.fsr) for user $($targetProfile.ad_user.distinguishedName) to directory $($targetProfile.path). Error: No directory found at path: $($targetProfile.path)"
                    IsError = $True
                })
            Write-Error "No directory found at path: $($targetProfile.path)"                
        }

        #Return ACL to modify
        $acl = Get-Acl $targetProfile.path

        #Assign rights to user
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($targetProfile.ad_user.SID, $targetProfile.fsr, $targetProfile.inf, $targetProfile.pf, $targetProfile.act)
        $acl.AddAccessRule($accessRule)

        Write-Verbose "Setting ACL permissions. File System Rights:$($targetProfile.fsr), Inheritance Flags:$($targetProfile.inf), Propagation Flags:$($targetProfile.pf), Access Control Type:$($targetProfile.act) for user $($targetProfile.ad_user.distinguishedName) to directory $($targetHome.path)"
        $job = Start-Job -ScriptBlock { Set-Acl -path $args[0].path -AclObject $args[1] } -ArgumentList @($targetProfile, $acl)
        Write-Information "Succesfully set ACL permissions. FSR:$($targetProfile.fsr), InF:$($targetProfile.inf), PF:$($targetProfile.pf), ACT:$($targetProfile.act) for user $($targetProfile.ad_user.distinguishedName) to directory $($targetProfile.path)"

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Successfully granted permissions $($targetProfile.fsr) for user $($targetProfile.ad_user.distinguishedName) to directory $($targetProfile.path)"
                IsError = $False
            })
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to grant permissions $($targetProfile.fsr) for user $($targetProfile.ad_user.distinguishedName) to directory $($targetProfile.path). Error: $($_)"
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
