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
$account = $actionContext.Data

try {
    #region Verify correlation configuration and properties
    $actionMessage = "verifying correlation configuration and properties"

    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue
    
        if ([string]::IsNullOrEmpty($correlationField)) {
            Write-Warning "Correlation is enabled but not configured correctly."
            throw "Correlation is enabled but not configured correctly."
        }
    
        if ([string]::IsNullOrEmpty($correlationValue)) {
            Write-Warning "The correlation value for [$correlationField] is empty. This is likely a scripting issue."
            throw "The correlation value for [$correlationField] is empty. This is likely a scripting issue."
        }
    }
    else {
        Write-Warning "Correlation is enabled but not configured correctly."
        throw "Configuration of correlation is madatory."
    }
    #endregion Verify correlation configuration and properties

    #region Get Primary Domain Controller
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
    #endregion Get Primary Domain Controller

    #region Get Microsoft Active Directory account
    $actionMessage = "querying Microsoft Active Directory account"
    
    $user = Get-ADUser -Filter "$correlationField -eq '$correlationValue'" -Server $pdc -ErrorAction Stop

    Write-Information "Queried Microsoft Active Directory account where [$($correlationField)] = [$($correlationValue)]. Result: $($user | ConvertTo-Json)"
    #endregion Get Microsoft Active Directory account

    #region Calulate action
    $actionMessage = "calculating action"
    if (($user | Measure-Object).count -eq 0) {
        $actionAccount = "NotFound"
    }
    elseif (($user | Measure-Object).count -eq 1) {
        $actionAccount = "Correlate"
    }
    elseif (($user | Measure-Object).count -gt 1) {
        $actionAccount = "MultipleFound"
    }
    #endregion Calulate action

    #region Process
    switch ($actionAccount) {
        "Correlate" {
            #region Correlate account
            $actionMessage = "correlating to account"

            $outputContext.AccountReference = $user.SID.Value
            if ($account.PSObject.Properties.Name -contains 'SID') {
                $account.SID = $user.SID.Value
            }

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CorrelateAccount" # Optionally specify a different action for this audit log
                    Message = "Correlated to account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json) on [$($correlationField)] = [$($correlationValue)]."
                    IsError = $false
                })

            $outputContext.AccountCorrelated = $true
            #endregion Correlate account

            break
        }

        "MultipleFound" {
            #region Multiple accounts found
            $actionMessage = "correlating to account"

            # Throw terminal error
            throw "Multiple accounts found where [$($correlationField)] = [$($correlationValue)]. Please correct this so the persons are unique."
            #endregion Multiple accounts found

            break
        }

        "NotFound" {
            #region No account found
            $actionMessage = "correlating to account"
    
            # Throw terminal error
            throw "No account found where [$($correlationField)] = [$($correlationValue)]."
            #endregion No account found

            break
        }
    }
    #endregion Process
}
catch {
    $ex = $PSItem  

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "CorrelateAccount"
            Message = $auditMessage
            IsError = $true
        }) 
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }

    $outputContext.Data = $account
}