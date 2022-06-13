#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$pRef = $entitlementContext | ConvertFrom-json

$success = $True
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
$dynamicPermissions = New-Object Collections.Generic.List[PSCustomObject];

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator

#region Supporting Functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}

function Get-ADSanitizeGroupName {
    param(
        [parameter(Mandatory = $true)][String]$Name
    )
    $newName = $name.trim();
    $newName = $newName -replace ' - ', '_'
    $newName = $newName -replace '[`,~,!,#,$,%,^,&,*,(,),+,=,<,>,?,/,'',",;,:,\,|,},{,.]', ''
    $newName = $newName -replace '\[', '';
    $newName = $newName -replace ']', '';
    $newName = $newName -replace ' ', '_';
    $newName = $newName -replace '\.\.\.\.\.', '.';
    $newName = $newName -replace '\.\.\.\.', '.';
    $newName = $newName -replace '\.\.\.', '.';
    $newName = $newName -replace '\.\.', '.';

    # Remove diacritics
    $newName = Remove-StringLatinCharacters $newName
    
    return $newName;
}
#endregion Supporting Functions

#region Change mapping here
$desiredPermissions = @{};
foreach ($contract in $p.Contracts) {
    Write-Verbose ("Contract in condition: {0}" -f $contract.Context.InConditions)
    if (( $contract.Context.InConditions) ) {
        $name = "department_" + $contract.Department.DisplayName
        $name = Get-ADSanitizeGroupName -Name $name

        $ADGroup = $null
        $ADGroup = Get-ADGroup -Filter { Name -eq $name } -Properties DisplayName
        if ($null -eq $ADGroup) {
            throw "No Group found with name: $name"
        }
        elseif ($ADGroup.sAMAccountName.count -gt 1) {
            throw "Multiple Groups found with name: $name . Please correct this so the description is unique."
        }

        $group_DisplayName = $ADGroup.Name
        $group_ObjectGUID = $ADGroup.ObjectGUID
        $desiredPermissions["$($group_DisplayName)"] = $group_ObjectGUID
    }
}

Write-Information ("Desired Permissions: {0}" -f ($desiredPermissions.keys | ConvertTo-Json))
#endregion Change mapping here

#region Execute
# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json

if ($dryRun -eq $True) {
    # Operation is empty for preview (dry run) mode, that's why we set it here.
    $o = "grant"
}

Write-Verbose ("Existing Permissions: {0}" -f $entitlementContext)
$currentPermissions = @{}
foreach ($permission in $pRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

# Compare desired with current permissions and grant permissions
foreach ($permission in $desiredPermissions.GetEnumerator()) {
    $dynamicPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Name
            Reference   = [PSCustomObject]@{ Id = $permission.Value }
        })

    if (-Not $currentPermissions.ContainsKey($permission.Value)) {
        # Add user to Membership
        if (-Not($dryRun -eq $True)) {
            try {
                $ObjectGUID = "$($permission.Value)"
                $ADGroup = Get-ADGroup -Identity $ObjectGUID

                #Note:  No errors thrown if user is already a member.
                Write-Verbose "Adding user: $($aRef) to group: $($ADGroup)"
                Add-ADGroupMember -Identity $ADGroup -Members @($aRef) -server $pdc

                $success = $true
                $auditLogs.Add(
                    [PSCustomObject]@{
                        Action  = "GrantDynamicPermission"
                        Message = "Successfully granted $($aRef.Username) to group $($permission.Name) ($($permission.Value))"
                        IsError = $false
                    }
                )
            
            }
            catch {
                $success = $false
                $auditLogs.Add(
                    [PSCustomObject]@{
                        Action  = "GrantDynamicPermission"
                        Message = "Failed to grant $($aRef.Username) to group $($permission.Name) ($($permission.Value))"
                        IsError = $true
                    }
                )
        

                Write-Warning $_
            }
        }
    }    
}

# Compare current with desired permissions and revoke permissions
$newCurrentPermissions = @{}
foreach ($permission in $currentPermissions.GetEnumerator()) {    
    if (-Not $desiredPermissions.ContainsKey($permission.Value)) {
        # Revoke Membership
        if (-Not($dryRun -eq $True)) {
            try {
                $ObjectGUID = "$($permission.Value)"
                $ADGroup = Get-ADGroup -Identity $ObjectGUID

                Write-Verbose "Removing user: $($aRef) from group: $($ADGroup)"
                Remove-ADGroupMember -Identity $ADGroup -Members @($aRef) -Confirm:$false -server $pdc

                $success = $true
                $auditLogs.Add(
                    [PSCustomObject]@{
                        Action  = "RevokeDynamicPermission"
                        Message = "Successfully revoked $($aRef.Username) from group $($permission.Name) ($($permission.Value))"
                        IsError = $false
                    }
                )
            
            }
            # Handle issue of AD Account or Group having been deleted.  Handle gracefully.
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                Write-Warning "Identity Not Found.  Continuing"
                Write-Warning $_
            }
            catch {
                $success = $false
                $auditLogs.Add(
                    [PSCustomObject]@{
                        Action  = "RevokeDynamicPermission"
                        Message = "Failed to grant $($aRef.Username) from group $($permission.Name) ($($permission.Value))"
                        IsError = $true
                    }
                )

                Write-Warning $_
            }
        }
    }
    else {
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
#endregion Execute

#region Build up result
$result = [PSCustomObject]@{
    Success            = $success;
    DynamicPermissions = $dynamicPermissions;
    AuditLogs          = $auditLogs;
};
Write-Output $result | ConvertTo-Json -Depth 10;
#endregion Build up result