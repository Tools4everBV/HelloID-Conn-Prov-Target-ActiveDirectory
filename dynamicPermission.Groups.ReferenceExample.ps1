# 2021-02-05 - Student Groups - Dynamic Permissions Example
# 2021-08-17 - Updated with Entitlement Context variable change.
#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json

# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json

# The entitlementContext contains the sub permissions (Previously the $permissionReference variable)
$eRef = $entitlementContext | ConvertFrom-Json

$currentPermissions = @{}
foreach($permission in $eRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

$success = $True
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$subPermissions = New-Object Collections.Generic.List[PSCustomObject]

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Change mapping here
$desiredPermissions = @{}
if (-Not($o -eq "revoke"))
{
    foreach($contract in $p.Contracts) {  # If Testing:  -OR ($dryRun -eq $True)
        if($contract.Context.InConditions)
        {
            # <GradYear>.Students.<Location>
            $group_sAMAccountName = "{0}.Students.{1}" -f $p.custom.GradYear,$contract.Department.ExternalID
            $desiredPermissions[$group_sAMAccountName] = $group_sAMAccountName

            # Students.<Location>
            $group_sAMAccountName = "Students.{0}" -f $contract.Department.ExternalID
            $desiredPermissions[$group_sAMAccountName] = $group_sAMAccountName

            # Students.<Alt Location>
            if(-Not [string]::IsNullOrWhiteSpace($p.custom.AltLocation))
            {
                $group_sAMAccountName = "Students.{0}" -f $p.custom.AltLocation
                $desiredPermissions[$group_sAMAccountName] = $group_sAMAccountName
            }
        }
    }
}
Write-Verbose -Verbose ("Defined Permissions: {0}" -f ($desiredPermissions.keys | ConvertTo-Json))
#endregion Change mapping here

#region Execute
Write-Verbose -Verbose ("Existing Permissions: {0}" -f $entitlementContext)

# Compare desired with current permissions and grant permissions
foreach($permission in $desiredPermissions.GetEnumerator()) {
    $subPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Value
            Reference = [PSCustomObject]@{ Id = $permission.Name }
    })

    if(-Not $currentPermissions.ContainsKey($permission.Name))
    {
        # Add user to Membership
        $permissionSuccess = $true
        if(-Not($dryRun -eq $True))
        {
            try
            {
                #Note:  No errors thrown if user is already a member.
                Add-ADGroupMember -Identity $($permission.Name) -Members @($aRef) -server $pdc
                Write-Verbose -Verbose ("Successfully Granted Permission to: {0}" -f $permission.Name)
            }
            catch
            {
                $permissionSuccess = $False
                $success = $False
                # Log error for further analysis.  Contact Tools4ever Support to further troubleshoot
                Write-Error ("Error Granting Permission for Group [{0}]:  {1}" -f $permission.Name, $_)
            }
        }

        $auditLogs.Add([PSCustomObject]@{
            Action = "GrantDynamicPermission"
            Message = "Granted membership: {0}" -f $permission.Name
            IsError = -NOT $permissionSuccess
        })
    }    
}

# Compare current with desired permissions and revoke permissions
$newCurrentPermissions = @{}
foreach($permission in $currentPermissions.GetEnumerator()) {    
    if(-Not $desiredPermissions.ContainsKey($permission.Name) -AND $permission.Name -ne "No Groups Defined")
    {
        # Revoke Membership
        if(-Not($dryRun -eq $True))
        {
            $permissionSuccess = $True
            try
            {
                Remove-ADGroupMember -Identity $permission.Name -Members @($aRef) -Confirm:$false -server $pdc
            }
            # Handle issue of AD Account or Group having been deleted.  Handle gracefully.
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
                Write-Verbose -Verbose "Identity Not Found.  Continuing"
                Write-Verbose -Verbose $_
            }
            catch
            {
                $permissionSuccess = $False
                $success = $False
                # Log error for further analysis.  Contact Tools4ever Support to further troubleshoot.
                Write-Error ("Error Revoking Permission from Group [{0}]:  {1}" -f $permission.Name, $_)
            }
        }
        
        $auditLogs.Add([PSCustomObject]@{
            Action = "RevokeDynamicPermission"
            Message = "Revoked membership: {0}" -f $permission.Name
            IsError = -Not $permissionSuccess
        })
    } else {
        $newCurrentPermissions[$permission.Name] = $permission.Value
    }
}

# Update current permissions
<# Updates not needed for Group Memberships.
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

# Handle case of empty defined dynamic permissions.  Without this the entitlement will error.
if ($o -match "update|grant" -AND $subPermissions.count -eq 0)
{
    $subPermissions.Add([PSCustomObject]@{
            DisplayName = "No Groups Defined"
            Reference = [PSCustomObject]@{ Id = "No Groups Defined" }
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