#####################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-DynamicPermissions-Groups
#
# Version: 1.2.1
#####################################################

#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json

$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json

# The permissionReference contains the Identification object provided in the retrieve permissions call
$pRef = $permissionReference | ConvertFrom-Json

# The entitlementContext contains the sub permissions (Previously the $permissionReference variable)
$eRef = $entitlementContext | ConvertFrom-Json

$currentPermissions = @{}
foreach ($permission in $eRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

# Determine all the sub-permissions that needs to be Granted/Updated/Revoked
$subPermissions = New-Object Collections.Generic.List[PSCustomObject]

#Get Primary Domain Controller
try {
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
#endregion Initialize default properties

#region Supporting Functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}

function Get-ADSanitizeGroupName {
    param(
        [parameter(Mandatory = $true)][String]$Name
    )
    $newName = $name.trim()
    $newName = $newName -replace ' - ', '_'
    $newName = $newName -replace '[`,~,!,#,$,%,^,&,*,(,),+,=,<,>,?,/,'',",,:,\,|,},{,.]', ''
    $newName = $newName -replace '\[', ''
    $newName = $newName -replace ']', ''
    # $newName = $newName -replace ' ', '_'
    $newName = $newName -replace '\.\.\.\.\.', '.'
    $newName = $newName -replace '\.\.\.\.', '.'
    $newName = $newName -replace '\.\.\.', '.'
    $newName = $newName -replace '\.\.', '.'

    # Remove diacritics
    $newName = Remove-StringLatinCharacters $newName
    
    return $newName
}

function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }

        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            # $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message # Does not show the correct error message for the Raet IAM API calls
            $httpErrorObj.ErrorMessage = $ErrorObject.Exception.Message

        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }

        Write-Output $httpErrorObj
    }
}

function Get-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $errorMessage = [PSCustomObject]@{
            VerboseErrorMessage = $null
            AuditErrorMessage   = $null
        }

        if ( $($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $httpErrorObject = Resolve-HTTPError -Error $ErrorObject

            $errorMessage.VerboseErrorMessage = $httpErrorObject.ErrorMessage

            $errorMessage.AuditErrorMessage = $httpErrorObject.ErrorMessage
        }

        # If error message empty, fall back on $ex.Exception.Message
        if ([String]::IsNullOrEmpty($errorMessage.VerboseErrorMessage)) {
            $errorMessage.VerboseErrorMessage = $ErrorObject.Exception.Message
        }
        if ([String]::IsNullOrEmpty($errorMessage.AuditErrorMessage)) {
            $errorMessage.AuditErrorMessage = $ErrorObject.Exception.Message
        }

        Write-Output $errorMessage
    }
}
#endregion Supporting Functions

#region Change mapping here
$desiredPermissions = @{}
if ($o -ne "revoke") {
    # Example: Contract Based Logic:
    foreach ($contract in $p.Contracts) {
        Write-Verbose ("Contract in condition: {0}" -f $contract.Context.InConditions)
        if ($contract.Context.InConditions -OR ($dryRun -eq $True)) {
            # Example: department_<departmentname>
            $groupName = "department_" + $contract.Department.DisplayName

            # Example: title_<titlename>
            # $groupName = "title_" + $contract.Title.Name

            # Sanitize group name, e.g. replace ' - ' with '_' or other sanitization actions 
            $groupName = Get-ADSanitizeGroupName -Name $groupName
            
            # Get group to use objectGuid to avoid name change issues
            $group = $null
            $filter = "Name -eq `"$groupName`""
            $group = Get-ADGroup -Filter $filter
            if ($null -eq $group) {
                throw "No Group found that matches filter '$($filter)'"
            }
            elseif ($group.ObjectGUID.count -gt 1) {
                throw "Multiple Groups that matches filter '$($filter)'. Please correct this so the groups are unique."
            }

            # Add group to desired permissions with the objectguid as key and the displayname as value (use objectguid to avoid issues with name changes and for uniqueness)
            $desiredPermissions["$($group.ObjectGUID)"] = $group.Name
        }
    }
    
    # Example: Person Based Logic:
    # Example: location_<locationname>
    # $groupName = "location_" + $p.Location.Name

    # # Sanitize group name, e.g. replace ' - ' with '_' or other sanitization actions 
    # $groupName = Get-ADSanitizeGroupName -Name $groupName
    
    # # Get group to check whether it exists and is unique
    # $group = $null
    # $filter = "Name -eq `"$groupName`""
    # $group = Get-ADGroup -Filter $filter
    # if ($null -eq $group) {
    #     throw "No Group found that matches filter '$($filter)'"
    # }
    # elseif ($group.ObjectGUID.count -gt 1) {
    #     throw "Multiple Groups that matches filter '$($filter)'. Please correct this so the groups are unique."
    # }

    # # Add group to desired permissions with the objectguid as key and the displayname as value (use objectguid to avoid issues with name changes and for uniqueness)
    # $desiredPermissions["$($group.ObjectGUID)"] = $group.Name
}

Write-Information ("Desired Permissions: {0}" -f ($desiredPermissions.Values | ConvertTo-Json))

Write-Information ("Existing Permissions: {0}" -f ($eRef.CurrentPermissions.DisplayName | ConvertTo-Json))
#endregion Change mapping here

#region Execute
try {
    # Compare desired with current permissions and grant permissions
    foreach ($permission in $desiredPermissions.GetEnumerator()) {
        $subPermissions.Add([PSCustomObject]@{
                DisplayName = $permission.Value
                Reference   = [PSCustomObject]@{ Id = $permission.Name }
            })

        if (-Not $currentPermissions.ContainsKey($permission.Name)) {
            # Grant AD Groupmembership
            try {
                if ($dryRun -eq $false) {
                    Write-Verbose "Granting permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'"

                    #Note:  No errors thrown if user is already a member.
                    Add-ADGroupMember -Identity $($permission.Name) -Members @($aRef) -server $pdc -ErrorAction 'Stop'

                    $auditLogs.Add([PSCustomObject]@{
                            Action  = "GrantPermission"
                            Message = "Successfully granted permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'"
                            IsError = $false
                        })
                }
                else {
                    Write-Warning "DryRun: Would grant permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'"
                }
            }
            catch {
                $ex = $PSItem
                $errorMessage = Get-ErrorMessage -ErrorObject $ex
            
                Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"
                    
                $auditLogs.Add([PSCustomObject]@{
                        Action  = "GrantPermission"
                        Message = "Error granting permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'. Error Message: $($errorMessage.AuditErrorMessage)"
                        IsError = $True
                    })
            }
        }    
    }

    # Compare current with desired permissions and revoke permissions
    $newCurrentPermissions = @{}
    foreach ($permission in $currentPermissions.GetEnumerator()) {    
        if (-Not $desiredPermissions.ContainsKey($permission.Name) -AND $permission.Name -ne "No Groups Defined") {
            # Revoke AD Groupmembership
            try {
                if ($dryRun -eq $false) {
                    Write-Verbose "Revoking permission to group '$($permission.Value) ($($permission.Name))' to user '$aRef'"

                    Remove-ADGroupMember -Identity $permission.Name -Members @($aRef) -Confirm:$false -server $pdc -ErrorAction 'Stop'

                    $auditLogs.Add([PSCustomObject]@{
                            Action  = "RevokePermission"
                            Message = "Successfully revoked permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'"
                            IsError = $false
                        })
                }
                else {
                    Write-Warning "DryRun: Would revoke permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'"
                }
            }
            # Handle issue of AD Account or Group having been deleted.  Handle gracefully.
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                $ex = $PSItem
                $errorMessage = Get-ErrorMessage -ErrorObject $ex
            
                Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

                $auditLogs.Add([PSCustomObject]@{
                        Action  = "RevokePermission"
                        Message = "Successfully revoked permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef' (Identity not found. skipped action)"
                        IsError = $false
                    })
            }
            catch {
                $ex = $PSItem
                $errorMessage = Get-ErrorMessage -ErrorObject $ex
            
                Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

                $auditLogs.Add([PSCustomObject]@{
                        Action  = "RevokePermission"
                        Message = "Error revoking permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'. Error Message: $($errorMessage.AuditErrorMessage)"
                        IsError = $True
                    })
            }

        }
        else {
            $newCurrentPermissions[$permission.Name] = $permission.Value
        }
    }

    # Update current permissions
    <# Updates not needed for Group Memberships.
    if ($o -eq "update") {
        foreach ($permission in $newCurrentPermissions.GetEnumerator()) {    
            $auditLogs.Add([PSCustomObject]@{
                    Action  = "UpdatePermission"
                    Message = "Successfully updated permission to group '$($permission.Value) ($($permission.Name))' for user '$aRef'"
                    IsError = $false
                })
        }
    }
    #>

    # Handle case of empty defined dynamic permissions.  Without this the entitlement will error.
    if ($o -match "update|grant" -AND $subPermissions.count -eq 0) {
        $subPermissions.Add([PSCustomObject]@{
                DisplayName = "No Groups Defined"
                Reference   = [PSCustomObject]@{ Id = "No Groups Defined" }
            })
    }
}
#endregion Execute
finally { 
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($auditLogs.IsError -contains $true)) {
        $success = $true
    }

    #region Build up result
    $result = [PSCustomObject]@{
        Success        = $success
        SubPermissions = $subPermissions
        AuditLogs      = $auditLogs
    }
    Write-Output ($result | ConvertTo-Json -Depth 10)
    #endregion Build up result
}
