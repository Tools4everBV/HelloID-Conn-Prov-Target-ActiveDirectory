#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json

$success = $True
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

# Operation is a script parameter which contains the action HelloID wants to perform for this permission
#   It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json

# The permissionReference contains the Identification object provided in the retrieve permissions call
$pRef = $permissionReference | ConvertFrom-Json

# The entitlementContext contains the sub permissions (Previously the $permissionReference variable)
$eRef = $entitlementContext | ConvertFrom-Json

$currentPermissions = @{}
foreach($permission in $eRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

# Determine all the sub-permissions that needs to be Granted/Updated/Revoked
$subPermissions = New-Object Collections.Generic.List[PSCustomObject]

try{
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
#endregion Initialize default properties

#region Support Functions
function Get-ConfigProperty
{
    [cmdletbinding()]
    Param (
        [object]$object,
        [string]$property
    )
    Process {
        $subItems = $property.split('.')
        $value = $object.psObject.copy()
        for($i = 0; $i -lt $subItems.count; $i++)
        {
            $value = $value."$($subItems[$i])"
        }
        return $value
    }
}
#endregion Support Functions

#region Change mapping here
if(-Not($dryRun -eq $True))
{
    try {
        $ad_user = Get-ADUser -Identity $aRef -Property HomeDirectory -server $pdc
    } catch 
    {
        Write-Warning ("AD Account Not Found.  Ref: {0}" -f $aRef)
    }
} else {
    $correlationPersonField = Get-ConfigProperty -object $p -property ($config.correlationPersonField -replace '\$p.','')
    $correlationAccountField = $config.correlationAccountField
    $filter = "($($correlationAccountField)=$($correlationPersonField))"
    Write-Information "LDAP Filter: $($filter)"
    
    $ad_user = Get-ADUser -LDAPFilter $filter -Property HomeDirectory -server $pdc
}

if([string]::IsNullOrWhiteSpace($ad_user.HomeDirectory))
{
    $calcHomeDirectory = "\\{0}\{1}" -f "SERVERNAME\SHARENAME",$ad_user.sAMAccountName
    Write-Information ("Calculated HomeDirectory: {0}" -f $calcHomeDirectory)
}
else # Directory already defined on Account
{
    Write-Information ("Existing HomeDir Found: {0}" -f $ad_user.HomeDirectory)
    $existing_homedir = $True
    $calcHomeDirectory = $ad_user.HomeDirectory
}

$target = @{
    ad_user = $ad_user
    path = $calcHomeDirectory
    drive = "H:"
    fsr = [System.Security.AccessControl.FileSystemRights]"Modify" #File System Rights
    act = [System.Security.AccessControl.AccessControlType]::Allow #Access Control Type
    inf = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit" #Inheritance Flags
    pf = [System.Security.AccessControl.PropagationFlags]"InheritOnly" #Propagation Flags
}

#endregion Change mapping here

#region Execute
Write-Information ("Existing Permissions: {0}" -f $entitlementContext)
$desiredPermissions = @{}
if($o -match "grant|update")
{
    $desiredPermissions["HomeDirectory"] = $calcHomeDirectory
}
Write-Information ("Defined Permissions: {0}" -f ($desiredPermissions.keys | ConvertTo-Json))

# Compare desired with current permissions and grant permissions
foreach($permission in $desiredPermissions.GetEnumerator()) {
    $subPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Value
            Reference = [PSCustomObject]@{ Id = $permission.Name }
    })
    
    if(-Not $currentPermissions.ContainsKey($permission.Name))
    {
        if(-Not($dryRun -eq $True))
        {
            try{
                $hd_exists = test-path $target.path
                if(-Not $hd_exists)
                {
                    # Create Folder
                    $homeDirectory = New-Item -path $target.path -ItemType Directory -force
                    Write-Information ("Creating Home Directory: {0}" -f $target.path)
                }
                
                # Update AD User
                Set-ADUser $target.ad_user -HomeDrive $target.drive -HomeDirectory $target.path -Server $pdc
                
                #Return ACL to modify
                $acl = Get-Acl $target.path

                #Assign rights to user
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($target.ad_user.SID,$target.fsr,$target.inf,$target.pf,$target.act)
                $acl.AddAccessRule($accessRule)

                $job = Start-Job -ScriptBlock { Set-Acl -path $args[0].path -AclObject $args[1] } -ArgumentList @($target,$acl)

                $auditLogs.Add([PSCustomObject]@{
                    Action = "GrantPermission"
                    Message = "Home Directory $($target.path) created for person $($p.DisplayName)"
                    IsError = $False
                })
            }
            catch{
                $success = $False
                $auditLogs.Add([PSCustomObject]@{
                    Action = "GrantPermission"
                    Message = "Home Directory creation failed for person - $($homeDrive.path) - $($_)"
                    IsError = $True
                })
                Write-Error $_
            }
        }
    }
}

# Compare current with desired permissions and revoke permissions
# No Revoke or Update actions from HelloID on Home Directories
<#
$newCurrentPermissions = @{}
foreach($permission in $currentPermissions.GetEnumerator()) {    
    if(-Not $desiredPermissions.ContainsKey($permission.Name))
    {
        $auditLogs.Add([PSCustomObject]@{
            Action = "RevokePermission"
            Message = "Revoked access to department share $($permission.Value)"
            IsError = $False
        })
    } else {
        $newCurrentPermissions[$permission.Name] = $permission.Value
    }
}

# Update current permissions
if ($o -eq "update") {
    foreach($permission in $newCurrentPermissions.GetEnumerator()) {    
        $auditLogs.Add([PSCustomObject]@{
            Action = "UpdatePermission"
            Message = "Updated access to department share $($permission.Value)"
            IsError = $False
        })
    }
}
#>

# Handle case of empty defined dynamic permissions.  Without this the entitlement will error.
if ($o -match "update|grant" -AND $subPermissions.count -eq 0)
{
    $subPermissions.Add([PSCustomObject]@{
            DisplayName = "No HomeDir Defined"
            Reference = [PSCustomObject]@{ Id = "No HomeDir Defined" }
    })
}
#endregion Execute

#region Build up result
$result = [PSCustomObject]@{
    Success = $success
    SubPermissions = $subPermissions
    AuditLogs = $auditLogs
}
Write-Output ($result | ConvertTo-Json -Depth 10)
#endregion Build up result
