#################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-ImportSubPermission
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    Write-Information 'Starting target sub-permissions import '
   
    # Configure, must be the same as the values used in retreive permissions
    $permissionReference = 'dep'
    $permissionDisplayName = 'Department'

    $filterGroups = "Description -like 'department*'"
    # $filterGroups = "extensionAttribute2 -eq 'HelloIDdepartment'"
    # If all groups needs to be queried
    # $filterGroups = '*'

    # $searchGroupOUs = @("OU=HelloID,OU=Security Groups,DC=enyoi,DC=org","OU=HelloID,OU=Other Groups,DC=enyoi,DC=org")
    # If all groups needs to be queried
    $searchGroupOUs = @("")

    # If all users needs to be queried
    $filterUsers = '*'

    # $searchUserOUs = @("OU=HelloID,OU=Employee Users,DC=enyoi,DC=org","OU=HelloID,OU=Other Users,DC=enyoi,DC=org")
    # If all users needs to be queried
    $searchUserOUs = @("")

    $actionMessage = "getting primary domain controller"
    if ([string]::IsNullOrEmpty($actionContext.Configuration.fixedDomainController)) {
        try {
            $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
        }
        catch {
            Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
            Write-Warning "Retrying PDC Lookup"
            $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
        }
    }
    else {
        Write-Information "A fixed domain controller is configured [$($actionContext.Configuration.fixedDomainController)]"    
        $pdc = $($actionContext.Configuration.fixedDomainController)
    }  
    
    $actionMessage = "querying groups"
    $properties = @('ObjectGUID', 'Name', 'member')
    $getADGroupsSplatParams = @{
        Filter        = $filterGroups
        Properties    = $properties
        ResultSetSize = $null
        Server        = $pdc
        ErrorAction   = 'Stop'
    }

    if ([String]::IsNullOrEmpty($searchGroupOUs)) {
        Write-Information "Querying AD groups that match filter [$($filterGroups)]"
        $groups = Get-ADGroup @getADGroupsSplatParams | Select-Object $properties
    }
    else {
        $groups = foreach ($searchGroupOU in $searchGroupOUs) {
            Write-Information "Querying AD groups that match filter [$($filterGroups)] in OU [$($searchGroupOU)]"
            Get-ADGroup @getADGroupsSplatParams -SearchBase $searchGroupOU | Select-Object $properties
        }
    }
    Write-Information "Successfully queried [$($groups.count)] existing groups"

    $actionMessage = "querying users"
    $properties = @('DistinguishedName', 'ObjectSid')
    $getADUsersSplatParams = @{
        Filter        = $filterUsers
        Properties    = $properties
        ResultSetSize = $null
        Server        = $pdc
        ErrorAction   = 'Stop'
    }

    if ([String]::IsNullOrEmpty($searchUserOUs)) {
        Write-Information "Querying AD users that match filter [$($filterUsers)]"
        $users = Get-ADUser @getADUsersSplatParams | Select-Object $properties
    }
    else {
        $users = foreach ($searchUserOU in $searchUserOUs) {
            Write-Information "Querying AD users that match filter [$($filterUsers)] in OU [$($searchUserOU)]"
            Get-ADUser @getADUsersSplatParams -SearchBase $searchUserOU | Select-Object $properties
        }
    }
    $usersGrouped = $users | Group-Object -Property DistinguishedName -AsString -AsHashTable
    Write-Information "Successfully queried [$($users.count)] existing users"

    $actionMessage = "returning data to HelloID"
    foreach ($group in $groups) {
        $groupMembers = @()
        foreach ($groupMember in $group.member) {
            $groupMemberSID = $usersGrouped[$groupMember].ObjectSid.Value
            if (-not([string]::IsNullOrEmpty($groupMemberSID))) { 
                $groupMembers += $groupMemberSID
            }
        }
        $numberOfAccounts = $(($groupMembers | Measure-Object).Count)   

        if (-not([string]::IsNullOrEmpty($group.Name))) {
            $displayname = $($group.Name).substring(0, [System.Math]::Min(100, $($group.Name).Length))
        }
        else {
            $displayname = $group.ObjectGUID
        }

        $permission = @{
            PermissionReference      = @{
                Reference = $permissionReference
            }       
            DisplayName              = $permissionDisplayName
            SubPermissionReference   = @{
                Id = $group.ObjectGUID
            }
            SubPermissionDisplayName = $displayName
        }

        # Batch permissions based on the amount of account references, 
        # to make sure the output objects are not above the limit
        $accountsBatchSize = 500
        if ($numberOfAccounts -gt 0) {
            $accountsBatchSize = 500
            $batches = 0..($numberOfAccounts - 1) | Group-Object { [math]::Floor($_ / $accountsBatchSize ) }
            foreach ($batch in $batches) {
                $permission.AccountReferences = [array]($batch.Group | ForEach-Object { @($groupMembers[$_]) })
                Write-Output $permission
            }
        }
    }
    Write-Information 'Target sub-permissions import completed'
}
catch {
    $ex = $PSItem
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Warning $warningMessage
    Write-Error $auditMessage
}