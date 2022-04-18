#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$pRef = $entitlementContext | ConvertFrom-json

# Operation is a script parameter which contains the action HelloID wants to perform for this permission
#   It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json
if ($dryRun -eq $True) {
    # Operation is empty for preview (dry run) mode, that's why we set it here.
    $o = "grant"
}

$success = $True
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$dynamicPermissions = New-Object Collections.Generic.List[PSCustomObject]

try{
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
$server = "HelloID001"
$path = "HelloID\Profile"
$archivePath = "HelloID\Profile\_Archief"
$archivePrefix = ""
$archiveSuffix = ""
# HomeDirectory, ProfilePath, MsTSHomeDirectory, MsTSProfilePath (or any other name, but others cannot be set in AD)
$folderType = "ProfilePath"
$setADAttributes = $true

#endregion Initialize default properties

#region Change mapping here
switch ($folderType) {
    "HomeDirectory"{
        $ad_user = Get-ADUser -Identity $aRef -Property $folderType -server $pdc
        $currentPath = $ad_user.$folderType
    }
    "ProfilePath" {
        $ad_user = Get-ADUser -Identity $aRef -Property $folderType -server $pdc
        $currentPath = $ad_user.$folderType
    }
    "MsTSHomeDirectory" {
        $ad_user = Get-ADUser -Identity $aRef -server $pdc

        $adsi = [adsi]::new("LDAP://$($ad_user.distinguishedName)")                 

        $currentPath = $adsi.psbase.InvokeGet("TerminalServicesHomeDirectory")
    }
    "MsTSProfilePath" {
        $ad_user = Get-ADUser -Identity $aRef -server $pdc

        $adsi = [adsi]::new("LDAP://$($ad_user.distinguishedName)")                 

        $currentPath = $adsi.psbase.InvokeGet("TerminalServicesProfilePath")
    }
    default {
        $ad_user = Get-ADUser -Identity $aRef -server $pdc
    }
}

if ([string]::IsNullOrWhiteSpace($currentPath)) {
    $calcDirectory = "\\{0}\{1}" -f "$server\$path", $ad_user.sAMAccountName
    $calcArchiveDirectory = "\\{0}\{1}" -f "$server\$archivePath", "$archivePrefix$($ad_user.sAMAccountName)$archiveSuffix"
}
else { # Directory already defined on Account
    $calcDirectory = $currentPath

    $currentPath = $calcDirectory
    $currentParentPath = $currentPath.replace("\$($currentPath | Split-Path -Leaf)", "")
    $currentFolder = "$($prefix)$($currentPath | Split-Path -Leaf)"
    $calcArchiveDirectory = "$($currentParentPath)\$archivePrefix$($currentFolder)$archiveSuffix"
}

Write-Verbose -Verbose ("Calculated $folderType : {0}" -f $calcDirectory)
Write-Verbose -Verbose ("Calculated $folderType archive: {0}" -f $calcArchiveDirectory)

$target = @{
    ad_user      = $ad_user
    path         = $calcDirectory
    archive_path = $calcArchiveDirectory
    drive        = "H:"
    fsr          = [System.Security.AccessControl.FileSystemRights]"Modify" #File System Rights
    act          = [System.Security.AccessControl.AccessControlType]::Allow #Access Control Type
    inf          = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit" #Inheritance Flags
    pf           = [System.Security.AccessControl.PropagationFlags]"InheritOnly" #Propagation Flags
}
#endregion Change mapping here

#region Execute
$currentPermissions = @{}
foreach ($permission in $pRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

$desiredPermissions = @{}
foreach ($contract in $p.Contracts) {
    if($contract.Context.InConditions)
    {
    $desiredPermissions["$folderType"] = $calcDirectory
    }
}

# Compare desired with current permissions and grant permissions
foreach ($permission in $desiredPermissions.GetEnumerator()) {
    $dynamicPermissions.Add([PSCustomObject]@{
        DisplayName = $permission.Value
        Reference   = [PSCustomObject]@{ Id = $permission.Name }
    })

    if (-Not $currentPermissions.ContainsKey($permission.Name)) {
        if (-Not($dryRun -eq $True)) {
            try {
                $path_exists = test-path $target.path
                if (-Not $path_exists) {
                    # Create Folder
                    Write-Verbose -Verbose ("Creating Path: {0}" -f $target.path)
                    $directory = New-Item -path $target.path -ItemType Directory -force
                }
                
                # Update AD User
                if ($setADAttributes -eq $true) {
                    switch ($folderType) {
                        "HomeDirectory" {
                            $adUserParams = @{
                                HomeDrive     = $target.drive
                                HomeDirectory = $target.path
                                Server        = $pdc
                            }
                            Set-ADUser $target.ad_user @adUserParams
                        }
                        "ProfilePath" {
                            $adUserParams = @{
                                Profilepath = $target.path
                                Server      = $pdc
                            }
                            Set-ADUser $target.ad_user @adUserParams
                        }
                        "MsTSHomeDirectory" {        
                            $adsi = [adsi]::new("LDAP://$($target.ad_user.distinguishedName)")                 

                            #Set Settings
                            $path = $target.path
                            $drive = $target.drive
                            $adsi.psbase.InvokeSet("TerminalServicesHomeDirectory", "$path")
                            $adsi.psbase.InvokeSet("TerminalServicesHomeDrive", "$drive")
                            $adsi.CommitChanges()
                        }                        
                        "MsTSProfilePath" {
                            $adsi = [adsi]::new("LDAP://$($target.ad_user.distinguishedName)")
                                                
                            #Set Settings
                            $path = $target.path                            
                            $adsi.psbase.InvokeSet("TerminalServicesProfilePath", "$path")
                            $adsi.CommitChanges()
                        }   
                    }
                }
                #Return ACL to modify
                $acl = Get-Acl $target.path
                
                #Assign rights to user
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($target.ad_user.SID, $target.fsr, $target.inf, $target.pf, $target.act)
                $acl.AddAccessRule($accessRule)

                $job = Start-Job -ScriptBlock { Set-Acl -path $args[0].path -AclObject $args[1] } -ArgumentList @($target, $acl)

                $auditLogs.Add([PSCustomObject]@{
                        Action  = "GrantDynamicPermission"
                        Message = "$folderType $($target.path) created for person $($p.DisplayName)"
                        IsError = $False
                    })
            }
            catch {
                $success = $False
                $auditLogs.Add([PSCustomObject]@{
                        Action  = "GrantDynamicPermission"
                        Message = "$folderType creation failed for person - $($homeDrive.path) - $($_)"
                        IsError = $True
                    })
                Write-Error $_
            }
        }
    }
}

# Compare current with desired permissions and revoke permissions
$newCurrentPermissions = @{}
foreach ($permission in $currentPermissions.GetEnumerator()) {   
    if (-Not $desiredPermissions.ContainsKey($permission.Name)) {
        try {
            $path_exists = test-path $target.path
            if ($path_exists) {
                $archive_path_exists = test-path $target.archive_path
                if ($archive_path_exists) {
                    $success = $False;
                    $auditLogs.Add([PSCustomObject]@{
                            Action  = "RevokeDynamicPermission"
                            Message = "$folderType archiving failed for person - $($homeDrive.path) - Archive Path $($target.archive_path) already exists"
                            IsError = $false
                        })
                }
                else {
                    if (-Not($dryRun -eq $True)) {
                        #Move home to archive
                        Write-Verbose -Verbose ("Moving path: {0} to archive path: {1}" -f $target.path, $target.archive_path)
                        $null = Move-Item -Path $target.path -Destination $target.archive_path -Force

                        # Update AD User
                        if ($setADAttributes -eq $true) {
                            switch ($folderType) {
                                "HomeDirectory" {
                                    $adUserParams = @{
                                        HomeDrive     = $target.drive
                                        HomeDirectory = $target.archive_path
                                        Server        = $pdc
                                    }
                                    Set-ADUser $target.ad_user @adUserParams
                                }
                                "ProfilePath" {
                                    $adUserParams = @{
                                        Profilepath = $target.archive_path
                                        Server      = $pdc
                                    }
                                    Set-ADUser $target.ad_user @adUserParams
                                }
                                "MsTSHomeDirectory" {        
                                    $adsi = [adsi]::new("LDAP://$($target.ad_user.distinguishedName)")                 

                                    #Set Settings
                                    $path = $target.archive_path
                                    $drive = $target.drive
                                    $adsi.psbase.InvokeSet("TerminalServicesHomeDirectory", "$path")
                                    $adsi.psbase.InvokeSet("TerminalServicesHomeDrive", "$drive")
                                    $adsi.CommitChanges()
                                }                        
                                "MsTSProfilePath" {
                                    $adsi = [adsi]::new("LDAP://$($target.ad_user.distinguishedName)")
                                                        
                                    #Set Settings
                                    $path = $target.archive_path                            
                                    $adsi.psbase.InvokeSet("TerminalServicesProfilePath", "$path")
                                    $adsi.CommitChanges()
                                }   
                            }
                        }

                        $success = $True;
                        $auditLogs.Add([PSCustomObject]@{
                            Action  = "RevokeDynamicPermission"
                            Message = "$folderType $($target.path) archived to $($target.archive_path) for person $($p.DisplayName)"
                            IsError = $False
                        })
                    }
                }
            }
            else {
                $success = $False;
                $auditLogs.Add([PSCustomObject]@{
                    Action  = "RevokeDynamicPermission"
                    Message = "$folderType archiving failed for person - $($homeDrive.path) - Path $($target.path) does not exist"
                    IsError = $false
                })
            }
        }
        catch {
            $success = $False;
            $auditLogs.Add([PSCustomObject]@{
                    Action  = "RevokeDynamicPermission"
                    Message = "$folderType archiving failed for person - $($homeDrive.path) - $($_)"
                    IsError = $True
                })
            Write-Error $_
        }
    }
    else {
        $newCurrentPermissions[$permission.Name] = $permission.Value
    }
}

# No Update actions from HelloID on Directories
<#
# Update current permissions
if ($o -eq "update") {
    foreach($permission in $newCurrentPermissions.GetEnumerator()) {    
        $auditLogs.Add([PSCustomObject]@{
            Action = "UpdateDynamicPermission"
            Message = "Updated access to department share $($permission.Value)"
            IsError = $False
        })
    }
}
#>
#endregion Execute

#region Build up result
$result = [PSCustomObject]@{
    Success            = $success
    DynamicPermissions = $dynamicPermissions
    AuditLogs          = $auditLogs
}
Write-Output ($result | ConvertTo-Json -Depth 10)
#endregion Build up result