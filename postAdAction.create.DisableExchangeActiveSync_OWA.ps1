#Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()
$eRef = $entitlementContext | ConvertFrom-Json

#region Disable the ActiveSync on Mailbox new user
$ExchangeURI = ""
$username = ""
$password = ""

$userCredential = New-Object -TypeName pscredential $username, (ConvertTo-SecureString $password -AsPlainText -Force)
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ExchangeURI -Authentication Kerberos -Credential $UserCredential
$exchange = Import-PSSession $Session

$currentUser = Get-ADUser $aRef.ObjectGuid

if (-Not($dryRun -eq $True)) {
    Try{
        $adUser = $currentUser.samaccountname   
        Set-CASMailbox -Identity $adUSer -ActiveSyncEnabled $false -OWAforDevicesEnabled $false
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
            Action  = "CreateAccount"
            Message = "Successfully disabled ActiveSync and OWA for Devices for user $($p.DisplayName)"
            IsError = $False
                })
    } 
    Catch {
        $success = $False
        $auditLogs.Add([PSCustomObject]@{
            Action  = "CreateAccount"
            Message = "Failed to disabled ActiveSync and OWA for Devices for user $($p.DisplayName). Error: $($_)"
            IsError = $True
                })
            throw $_
    }
}
else {
    # Write dry run logic here
}
#end region Disable the ActiveSync on Mailbox new user


#build up result
$result = [PSCustomObject]@{
    Success   = $success
    AuditLogs = $auditLogs

    # Return data for use in other systems.
    # If not present or empty the default export data will be used
    # ExportData = [PSCustomObject]@{}
}

#send result back
Write-Output $result | ConvertTo-Json -Depth 10