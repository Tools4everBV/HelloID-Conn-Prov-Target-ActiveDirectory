#region Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-json
$c = $configuration | ConvertFrom-Json

# Operation is a script parameter which contains the action HelloID wants to perform for this permission
# It has one of the following values: "grant", "revoke", "update"
$o = $operation | ConvertFrom-Json

if($dryRun -eq $True) {
    # Operation is empty for preview (dry run) mode, that's why we set it here.
    $o = "grant"
}

$success = $True
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$dynamicPermissions = New-Object Collections.Generic.List[PSCustomObject]
#endregion

$currentPermissions = @{}
foreach($permission in $pRef.CurrentPermissions) {
    $currentPermissions[$permission.Reference.Id] = $permission.DisplayName
}

$desiredPermissions = @{
	'Remote Mailbox' = 'Remote Mailbox'
}
#foreach($contract in $p.Contracts) {
#    $desiredPermissions['Remote Mailbox'] = 'Remote Mailbox Enabled'
#}

# Compare desired with current permissions and grant permissions
foreach($permission in $desiredPermissions.GetEnumerator()) {
    $dynamicPermissions.Add([PSCustomObject]@{
            DisplayName = $permission.Value
            Reference = [PSCustomObject]@{ Id = $permission.Name }
    })
    if(-Not $currentPermissions.ContainsKey($permission.Name))
    {
        # Connect to Exch, get Current Mailbox
        # If no mailbox, error so it can be retried later.
        # If ArchiveState == 'none', Enable Archive
        # Else, End
    
        $Credentials = [System.Management.Automation.PSCredential]::new($c.exch_username,$($c.exch_Password | ConvertTo-SecureString -AsPlainText -Force))
        try {
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $c.exch_uri -Authentication Kerberos -Credential $Credentials
            $_adUser = get-aduser -Identity $aRef -Property msExchRecipientDisplayType
            write-Information ("msExchRecipientDisplayType: {0}" -f $_adUser.msExchRecipientDisplayType)
            # Check if user already Remote Mailbox Enabled.
            if($null -eq $_aduser.msExchRecipientDisplayType)
            {
                write-Information "Enabling Remote Mailbox"
                if(-Not($dryRun -eq $True))
                {
                    $mailbox = Invoke-Command -Session $Session -ArgumentList $_adUser.sAMAccountName,($_adUser.sAMAccountName + "@" + $c.onmicrosoft_domain ) -ScriptBlock {enable-remoteMailbox $args[0] -RemoteRoutingAddress ($args[1])} -ErrorAction Stop
                }
                else
                {
                    write-Information ("DryRun - Would Execute: {0}" -f ('Invoke-Command -Session $Session -ArgumentList $_adUser.sAMAccountName,($_adUser.sAMAccountName + "@" + $c.onmicrosoft_domain ) -ScriptBlock {enable-remoteMailbox $args[0] -RemoteRoutingAddress $args[1]} -ErrorAction Stop'))
                }
                #Start-Sleep -s 1
                $auditLogs.Add([PSCustomObject]@{
                    Action = "GrantDynamicPermission"
                    Message = "Enabled Remote Mailbox: {0}" -f $mailbox.UserPrincipalName
                    IsError = $False
                })
            }
            <#
            $mailbox = Invoke-Command -Session $Session -ArgumentList $_adUser.sAMAccountName -ScriptBlock {get-remoteMailbox $args[0] } -ErrorAction Stop
            write-Information ("Archive State: {0}" -f $mailbox.ArchiveState)
            if ($mailbox.ArchiveState -eq 'none')
            {
                if(-Not($dryRun -eq $True))
                {
                    $return = Invoke-Command -Session $Session -ArgumentList $_adUser.sAMAccountName -ScriptBlock {enable-remoteMailbox $args[0] -Archive } -ErrorAction Stop
                }
                else
                {
                    write-Information ("DryRun - Would Execute: {0}" -f ('Invoke-Command -Session $Session -ArgumentList $_adUser.sAMAccountName -ScriptBlock {enable-remoteMailbox $args[0] -Archive } -ErrorAction Stop'))
                }
            }

            $auditLogs.Add([PSCustomObject]@{
                Action = "GrantDynamicPermission"
                Message = "Enabled Archive Against Mailbox: {0}" -f $mailbox.UserPrincipalName
                IsError = $False
            }) #>
        }
        catch
        {
            $success = $false
            $auditLogs.Add([PSCustomObject]@{
                Action = "GrantDynamicPermission"
                Message = "Error Communicating with Exchange Server:  {0}" -f $_
                IsError = $True
            })
        }
        finally
        {
            Remove-PSSession $Session
        }
    }    
}

# Compare current with desired permissions and revoke permissions
#   For Exchange Archive, no actual removal actions are called.
$newCurrentPermissions = @{}
foreach($permission in $currentPermissions.GetEnumerator()) {    
    if(-Not $desiredPermissions.ContainsKey($permission.Name))
    {
        $auditLogs.Add([PSCustomObject]@{
            Action = "RevokeDynamicPermission"
            Message = "Revoked record of Archive Permission (no mailbox changes actually made)"
            IsError = $False
        })
    } else {
        $newCurrentPermissions[$permission.Name] = $permission.Value
    }
}

# Update current permissions
<# No Update logic needed for Mailbox Archive
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

# Send results
$result = [PSCustomObject]@{
    Success = $success
    DynamicPermissions = $dynamicPermissions
    AuditLogs = $auditLogs
}
Write-Output $result | ConvertTo-Json -Depth 10
