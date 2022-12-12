#####################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-Create-CorrelateUser
#
# Version: 1.1.0
#####################################################
# Initialize default values
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $true # Set to true at start, because only when an error occurs it is set to false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Change mapping here
$account = [PSCustomObject]@{
    SAMAccountName = $p.Accounts.MicrosoftActiveDirectory.SAMAccountName
}

# # Troubleshooting
# $account = [PSCustomObject]@{
#     SAMAccountName = $p.Accounts.MicrosoftActiveDirectory.SAMAccountName
# }
# $dryRun = $false

#Get Primary Domain Controller
try {
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}

try {
    Write-Verbose "Querying user with SAMAccountName '$($account.SAMAccountName)'"

    if ([string]::IsNullOrEmpty($account.SAMAccountName)) { throw "No SAMAccountName provided" }  
    
    $user = Get-ADUser -Identity $account.SAMAccountName -Server $pdc -ErrorAction Stop
    
    if ($null -eq $user.Guid) { throw "Failed to return a user with SAMAccountName '$($account.SAMAccountName)'" }

    $aRef = $user.SID.Value

    $auditLogs.Add([PSCustomObject]@{
            Action  = "CreateAccount"
            Message = "Successfully queried and correlated to user $($user.SAMAccountName) ($($user.SID.Value))"
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

    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"
    $success = $false
    $auditLogs.Add([PSCustomObject]@{
            Action  = "CreateAccount"
            Message = "Error querying user with SAMAccountName '$($account.SAMAccountName)'. Error Message: $auditErrorMessage"
            IsError = $True
        })       
}
finally {
    # Send results
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $aRef
        AuditLogs        = $auditLogs
        Account          = $account

        # Optionally return data for use in other systems
        ExportData       = [PSCustomObject]@{
            DisplayName       = $user.Name
            SAMAccountName    = $user.SAMAccountName
            UserPrincipalName = $user.UserPrincipalName
            SID               = $user.SID.Value
        }
    }

    Write-Output $result | ConvertTo-Json -Depth 10
}
