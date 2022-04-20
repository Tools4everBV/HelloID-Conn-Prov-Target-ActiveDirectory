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
$adUser = Get-ADUser $eRef.adUser.ObjectGuid

# HomeDir
$HomeDirPath = "\\server\share\optional-folder\$($adUser.sAMAccountName)"
Write-Verbose "HomeDir path: $($HomeDirPath)"

$targetHome = @{
    ad_user = $adUser
    path    = $HomeDirPath
    # Supported permissions: Full Control,Modify,Read and execute,Read-only,Write-only
    permission  = "Full Control"
    # The objects the permissions apply to. Supported inheritance levels: This folder only,This folder and subfolders,This folder, subfolders and files
    inheritance = "This folder, subfolders and files"
}

# ProfileDir
$ProfileDirPath = "\\server\share\optional-folder\$($adUser.sAMAccountName)"
Write-Verbose "ProfileDir path: $($ProfileDirPath)"

$targetProfile = @{
    ad_user = $adUser
    path    = $HomeDirPath
    # Supported permissions: Full Control,Modify,Read and execute,Read-only,Write-only
    permission  = "Full Control"
    # The objects the permissions apply to. Supported inheritance levels: This folder only,This folder and subfolders,This folder, subfolders and files
    inheritance = "This folder, subfolders and files"
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
                    Message = "Error setting permissions: $($targetHome.permission) for user: $($targetHome.ad_user.sAMAccountName) to $($targetHome.inheritance) for directory: $($targetHome.$path). Error: No directory found at path: $($targetHome.path)"
                    IsError = $True
                })
            Write-Error "No directory found at path: $($targetHome.path)"                
        }

        Write-Verbose "Setting permissions: $($targetHome.permission) for user: $($targetHome.ad_user.sAMAccountName) to $($targetHome.inheritance) for directory: $($targetHome.path)"
        switch($targetHome.permission){
            "Full Control" { $perm = "(F)" }
            "Modify " { $perm = "(M)" }
            "Read and execute" { $perm = "(RX)" }
            "Read-only" { $perm = "(R)" }
            "Write-only" { $perm = "(W)" }
        }
    
        switch($($targetHome.inheritance)){
            "This folder only" { $inher = "" }
            "This folder and subfolders " { $inher = "(CI)" }
            "This folder, subfolders and files" { $inher = "(CI)(OI)" }
        }
    
        # Icacls docs: https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/icacls 
        $setAcl = icacls $targetHome.path /grant "$($targetHome.ad_user.sAMAccountName):$($inher)$($perm)" /T
        Write-Information "Succesfully set permissions: $($targetHome.permission) for user: $($targetHome.ad_user.sAMAccountName) to $($targetHome.inheritance) for directory: $($targetHome.path)"
        
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Successfully set permissions: $($targetHome.permission) for user: $($targetHome.ad_user.sAMAccountName) to $($targetHome.inheritance) for directory: $($targetHome.path)"
                IsError = $False
            })
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to set permissions: $($targetHome.permission) for user: $($targetHome.ad_user.sAMAccountName) to $($targetHome.inheritance) for directory: $($targetHome.path). Error: $($_)"
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
                    Message = "Error setting permissions: $($targetProfile.permission) for user: $($targetProfile.ad_user.sAMAccountName) to $($targetProfile.inheritance) for directory: $($targetProfile.$path). Error: No directory found at path: $($targetProfile.path)"
                    IsError = $True
                })
            Write-Error "No directory found at path: $($targetProfile.path)"                
        }

        Write-Verbose "Setting permissions: $($targetProfile.permission) for user: $($targetProfile.ad_user.sAMAccountName) to $($targetProfile.inheritance) for directory: $($targetProfile.path)"
        switch($targetProfile.permission){
            "Full Control" { $perm = "(F)" }
            "Modify " { $perm = "(M)" }
            "Read and execute" { $perm = "(RX)" }
            "Read-only" { $perm = "(R)" }
            "Write-only" { $perm = "(W)" }
        }
    
        switch($($targetProfile.inheritance)){
            "This folder only" { $inher = "" }
            "This folder and subfolders " { $inher = "(CI)" }
            "This folder, subfolders and files" { $inher = "(CI)(OI)" }
        }
    
        # Icacls docs: https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/icacls 
        $setAcl = icacls $targetProfile.path /grant "$($targetProfile.ad_user.sAMAccountName):$($inher)$($perm)" /T
        Write-Information "Succesfully set permissions: $($targetProfile.permission) for user: $($targetProfile.ad_user.sAMAccountName) to $($targetProfile.inheritance) for directory: $($targetProfile.path)"
        
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Successfully set permissions: $($targetProfile.permission) for user: $($targetProfile.ad_user.sAMAccountName) to $($targetProfile.inheritance) for directory: $($targetProfile.path)"
                IsError = $False
            })
    }
    catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Failed to set permissions: $($targetProfile.permission) for user: $($targetProfile.ad_user.sAMAccountName) to $($targetProfile.inheritance) for directory: $($targetProfile.path). Error: $($_)"
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