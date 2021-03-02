#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-json

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
$dynamicPermissions = New-Object Collections.Generic.List[PSCustomObject];

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Change mapping here

# Get current AD Account
$ad_user = Get-ADUser -Identity $aRef -Property HomeDirectory -server $pdc


if([string]::IsNullOrWhiteSpace($ad_user.homeDirectory))
{
	$calcHomeDirectory = "\\{0}\{1}" -f "FILESERVER01",$ad_user.sAMAccountName
}
else # Directory already defined on Account
{
	$calcHomeDirectory = $ad_user.HomeDirectory
}

Write-Verbose -Verbose ("Calculated HomeDirectory: {0}" -f $calcHomeDirectory)

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
# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json

if($dryRun -eq $True) {
    # Operation is empty for preview (dry run) mode, that's why we set it here.
    $o = "grant"
}

$currentPermissions = @{}
foreach($permission in $pRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

$desiredPermissions = @{}
foreach($contract in $p.Contracts) {
    if($contract.Context.InConditions)
    {
        $desiredPermissions["HomeDirectory"] = $calcHomeDirectory # Set this to the calculated HomeDir?
    }
}

# Compare desired with current permissions and grant permissions
foreach($permission in $desiredPermissions.GetEnumerator()) {
    $dynamicPermissions.Add([PSCustomObject]@{
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
                    Write-Verbose -Verbose ("Creating Home Directory: {0}" -f $target.path)
				}
				
				# Update AD User
				Set-ADUser $target.ad_user -HomeDrive $target.letter -HomeDirectory $target.path -Server $pdc
				
				#Return ACL to modify
				$acl = Get-Acl $target.path

				#Assign rights to user
				$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($target.ad_user.SID,$target.fsr,$target.inf,$target.pf,$target.act);
				$acl.AddAccessRule($accessRule);

				$job = Start-Job -ScriptBlock { Set-Acl -path $homeDirectory -AclObject $acl; }
				
				$auditLogs.Add([PSCustomObject]@{
					Action = "GrantDynamicPermission"
					Message = "Home Directory $($target.path) created for person $($p.DisplayName)"
					IsError = $False
				})
				$success = $True
			}
			catch{
				$auditLogs.Add([PSCustomObject]@{
					Action = "GrantDynamicPermission"
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
            Action = "RevokeDynamicPermission"
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
            Action = "UpdateDynamicPermission"
            Message = "Updated access to department share $($permission.Value)"
            IsError = $False
        })
    }
}
#>
$success = $True
#endregion Execute



#region Build up result
$result = [PSCustomObject]@{
    Success = $success;
    DynamicPermissions = $dynamicPermissions;
    AuditLogs = $auditLogs;
};
Write-Output $result | ConvertTo-Json -Depth 10;
#endregion Build up result
