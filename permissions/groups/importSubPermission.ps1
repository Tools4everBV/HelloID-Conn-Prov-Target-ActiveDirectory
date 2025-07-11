#################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-ImportSubPermission
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    Write-Information 'Starting target sub-permissions import '
   
    # Configure, must be the same as the values used in retrieve permissions
    $permissionReference = 'dep'
    $permissionDisplayName = 'Department'

    $filter = "Description -like 'department*'"
    # If all groups needs to be queried
    # $filter = '*'

    # $searchOUs = @("OU=HelloID,OU=Security Groups,DC=enyoi,DC=org","OU=HelloID,OU=Other Groups,DC=enyoi,DC=org")
    # If all OUs needs to be queried
    $searchOUs = @("")

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
    $properties = @('ObjectGUID', 'Name')
    $getADGroupsSplatParams = @{
        Filter      = $filter
        Properties  = $properties
        Server      = $pdc
        ErrorAction = 'Stop'
    }
    if ([String]::IsNullOrEmpty($searchOUs)) {
        Write-Information "Querying AD groups that match filter [$($filter)]"
        $groups = Get-ADGroup @getADGroupsSplatParams | Select-Object $properties
    }
    else {
        $groups = foreach ($searchOU in $searchOUs) {
            Write-Information "Querying AD groups that match filter [$($filter)] in OU [$($searchOU)]"
            Get-ADGroup @getADGroupsSplatParams -SearchBase $searchOU | Select-Object $properties
        }
    }
    Write-Information "Successfully queried [$($groups.count)] existing groups"

    $actionMessage = "returning data to HelloID"
    foreach ($group in $groups) {
        $groupMembers = @()
        $getADGroupMembersSplatParams = @{
            Identity    = $group.ObjectGUID
            Recursive   = $true
            Server      = $pdc
            ErrorAction = 'Stop'
        }
        $members = Get-ADGroupMember @getADGroupMembersSplatParams
        $groupMembers += $members.SID.Value
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
            DisplayName              = "Permission - $permissionDisplayName"
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