#####################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set to false at start, at the end, only when no error occurs it is set to true
$outputContext.Success = $false 

# AccountReference must have a value for dryRun
$outputContext.AccountReference = "Unknown"

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

$account = $actionContext.Data

try {

    if (-not($account.PSObject.Properties.Name -contains 'sAMAccountName')) {
        throw "sAMAccountName not mapped. This is mandatory"
    }

    if ([string]::IsNullOrEmpty($Account.sAMAccountName)) {
        throw "sAMAccountName has no value. This is mandatory"
    }

    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationProperty = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue
    
        if ([string]::IsNullOrEmpty($correlationProperty)) {
            Write-Warning "Correlation is enabled but not configured correctly."
            throw "Correlation is enabled but not configured correctly."
        }
    
        if ([string]::IsNullOrEmpty($correlationValue)) {
            Write-Warning "The correlation value for [$correlationProperty] is empty. This is likely a scripting issue."
            throw "The correlation value for [$correlationProperty] is empty. This is likely a scripting issue."
        }
    }
    else {
        Write-Warning "Correlation is enabled but not configured correctly."
        throw "Configuration of correlation is madatory."
    }

    #Get Primary Domain Controller
    try {
        $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
    }
    catch {
        Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
        Write-Warning "Retrying PDC Lookup"
        $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
    }

    write-verbose "Querying user with sAMAccountName '$($account.sAMAccountName)'"
    
    $user = Get-ADUser -Identity $account.sAMAccountName -Server $pdc -ErrorAction Stop

    if ([string]::IsNullOrEmpty($user.ObjectGUID)) {
        throw "Failed to return a user with sAMAccountName [$($account.sAMAccountName)]" 
    }

    $outputContext.AccountReference = $user.SID.Value
    if ($account.PSObject.Properties.Name -contains 'SID') {
        $account.SID = $user.SID.Value
    }

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "CorrelateAccount"
            Message = "Successfully queried and correlated to user $($user.sAMAccountName) ($($user.SID.Value))"
            IsError = $false
        })
}
catch {
    $ex = $PSItem
    
    # If error message empty, fall back on $ex.Exception.Message
    if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
        $verboseErrorMessage = $ex.Exception.Message
    }
    if ([String]::IsNullOrEmpty($auditErrorMessage)) {
        $auditErrorMessage = $ex.Exception.Message
    }

    write-verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "CorrelateAccount"
            Message = "Error querying user with sAMAccountName '$($account.sAMAccountName)'. Error Message: $auditErrorMessage"
            IsError = $True
        })       
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }

    $outputContext.Data = $account
}