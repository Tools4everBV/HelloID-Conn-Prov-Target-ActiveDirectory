#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-json

$success = $True
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];
$dynamicPermissions = New-Object Collections.Generic.List[PSCustomObject];

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Supporting Functions
function Get-ADSanitizeGroupName
{
    param(
        [parameter(Mandatory = $true)][String]$Name
    )
    $newName = $name.trim();
    $newName = $newName -replace ' - ','.'
    $newName = $newName -replace '[`,~,!,#,$,%,^,&,*,(,),+,=,<,>,?,/,'',",;,:,\,|,},{]',''
    $newName = $newName -replace '\[','';
    $newName = $newName -replace ']','';
    $newName = $newName -replace ' ','.';
    $newName = $newName -replace '\.\.\.\.\.','.';
    $newName = $newName -replace '\.\.\.\.','.';
    $newName = $newName -replace '\.\.\.','.';
    $newName = $newName -replace '\.\.','.';
    return $newName;
}
#endregion Supporting Functions

#region Change mapping here
$desiredPermissions = @{};

foreach($contract in $p.Contracts) {
    # Skip Base contract
    if($contract.Title.Name -eq "Employee") { continue; }
    
    if($contract.Context.InConditions -or $dryRun -eq $True)
    {
        
        $departmentId = Get-ADSanitizeGroupName -Name $contract.Custom.SiteDescShort;
        $departmentName = Get-ADSanitizeGroupName -Name $contract.Department.DisplayName;
        $title = Get-ADSanitizeGroupName -Name $contract.Title.Name;
        $jobCategory = Get-ADSanitizeGroupName -Name $contract.Division.Name;
        $teamName = Get-ADSanitizeGroupName -Name $contract.team.name;
        $teamId = Get-ADSanitizeGroupName -Name $contract.team.ExternalId;
        
        # Debug Data
        #Write-Information "Department Id: $($departmentId)";
        #Write-Information "Department Name: $($departmentName)";
        #Write-Information "Title: $($title)";
        #Write-Information "Job Category: $($jobCategory)";
        #Write-Information "Team Name: $($teamName)";
        #Write-Information "Team Id: $($teamId)";
        
        $desiredPermissions["AG.$($jobCategory)"] = "AG.$($jobCategory)";
        $desiredPermissions["AG.$($departmentName).$($jobCategory)"] = "AG.$($departmentName).$($jobCategory)";
        $desiredPermissions["AG.$($departmentId).$($title)"] = "AG.$($departmentId).$($title)";
        $desiredPermissions["AG.$($title)"] = "AG.$($title)";
        $desiredPermissions["AG.$($departmentName).$($teamId)"] = "AG.$($departmentName).$($teamId)";
        $desiredPermissions["AG.$($teamId)"] = "AG.$($teamId)";
    }
}
#endregion Change mapping here

#region Execute
# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json;

if($dryRun -eq $True) {
    # Operation is empty for preview (dry run) mode, that's why we set it here.
    $o = "grant";
}

#Current Automated Groups
$agGroups = Get-ADGroup -LDAPFilter "(adminDescription=Automated Group)" -Server $pdc

#Get User Current Automation Groups
Get-ADPrincipalGroupMembership -Identity $aRef -Server $pdc | Where-Object { $agGroups.SID -contains $_.SID } | ForEach-Object { $currentPermissions[$_.name] = $_.name; }

# Compare desired with current permissions and grant permissions
foreach($permission in $desiredPermissions.GetEnumerator()) {
    $dynamicPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Value;
            Reference = [PSCustomObject]@{ Id = $permission.Name };
    });
    if(-Not $currentPermissions.ContainsKey($permission.Name))
    {
        Write-Information "Add - $($permission.Name)";
        $permissionSuccess = $false;
        try{
            # If not dry run, add to AD Group
            if(-Not($dryRun -eq $True)) { Add-ADGroupMember -Identity $permission.Name -Members @($aRef) -Server $pdc -Confirm:$false }
            $permissionSuccess = $true;
        }
        catch
        {
            Write-Error "Add Failed - $($permission.Name): $($_)";
            $success = $False;
        }
        $auditLogs.Add([PSCustomObject]@{
            Action = "GrantDynamicPermission";
            Message = "Granted access to department share $($permission.Value)";
            IsError = $permissionSuccess;
        });
    }    
}

# Compare current with desired permissions and revoke permissions
$newCurrentPermissions = @{};

foreach($permission in $currentPermissions.GetEnumerator()) {    
    if(-Not $desiredPermissions.ContainsKey($permission.Name))
    {
        Write-Information "Remove - $($permission.Name)";
        
        $permissionSuccess = $false;
        try{
            # If not dry run, remove from AD Group
            if(-Not($dryRun -eq $True)) 
            { 
                Write-Information "Remove-ADGroupMember -Identity $($permission.Name) -Members @($($accountReference)) -Server $($pdc) -Confirm:false"
                Remove-ADGroupMember -Identity $permission.Name -Members @($aRef) -Server $pdc -Confirm:$false;
            
            }
            $permissionSuccess = $true;
        }
        catch
        {
            Write-Error "Remove Failed - $($permission.Name): $($_)";
            $success = $False;
        }
        $auditLogs.Add([PSCustomObject]@{
            Action = "RevokeDynamicPermission";
            Message = "Revoked access to department share $($permission.Value)";
            IsError = $False;
        });
    } else {
        $newCurrentPermissions[$permission.Name] = $permission.Value;
    }
}

# Update current permissions
#if ($o -eq "update") {
#    foreach($permission in $newCurrentPermissions.GetEnumerator()) {    
#        Write-Information "Update - $($permission.Name)";
#        $auditLogs.Add([PSCustomObject]@{
#            Action = "UpdateDynamicPermission";
#            Message = "Updated access to department share $($permission.Value)";
#            IsError = $False;
#        });
#    }
#}
#endregion Execute

#region Build up result
$result = [PSCustomObject]@{
    Success = $success;
    DynamicPermissions = $dynamicPermissions;
    AuditLogs = $auditLogs;
};
Write-Output $result | ConvertTo-Json -Depth 10;
#endregion Build up result
