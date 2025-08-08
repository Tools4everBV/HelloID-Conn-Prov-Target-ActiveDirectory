#################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-Import
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    Write-Information 'Starting target account import'
    $importFields = $($actionContext.ImportFields)

    # Add mandatory fields for HelloID to query and return
    if ('SID' -notin $importFields) { $importFields += 'SID' }
    if ('Enabled' -notin $importFields) { $importFields += 'Enabled ' }
    if ('Name' -notin $importFields) { $importFields += 'Name' }
    if ('UserPrincipalName' -notin $importFields) { $importFields += 'UserPrincipalName' }
    Write-Information "Querying fields [$importFields]"
        
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

    $actionMessage = "querying accounts"
    $properties = @(
        @{Name = 'SID'; Expression = { $_.SID.Value } }
        @{Name = 'Enabled'; Expression = { [bool]$_.Enabled } }
    ) + ($importFields | Where-Object { ($_ -ne 'SID') -and ($_ -ne 'Enabled') })

    $getADUsersSplatParams = @{
        Filter      = '*'
        Properties  = $importFields
        Server      = $pdc
        ErrorAction = 'Stop'
    }
    $existingAccounts = Get-ADUser @getADUsersSplatParams | Select-Object -Property $properties
    Write-Information "Successfully queried [$($existingAccounts.count)] existing accounts"

    $actionMessage = "returning data to HelloID"
    foreach ($account in $existingAccounts) {
        if ([string]::IsNullOrEmpty($account.Name)) {
            $account.Name = $account.SID
        }
        if ([string]::IsNullOrEmpty($account.UserPrincipalName)) {
            $account.UserPrincipalName = $account.SID
        }
        Write-Output @{
            AccountReference = $account.SID
            DisplayName      = $account.Name
            UserName         = $account.UserPrincipalName
            Enabled          = $false # No account access is granted, this should be false for the report. $account.Enabled 
            Data             = $account
        }
    }
    Write-Information 'Target account import completed'
}
catch {
    $ex = $PSItem
    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Warning $warningMessage
    Write-Error $auditMessage
}