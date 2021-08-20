#region Initialize default properties
$config = ConvertFrom-Json $configuration
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$pd = $personDifferences | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json;

$success = $False
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
#endregion Initialize default properties

#region Execute
    # Log Names
    Write-Information "Previous Name: $($pp.Name.GivenName) $($pp.Name.FamilyName)"
    Write-Information "Current Name: $($p.Name.GivenName) $($p.Name.FamilyName)"

    # Get Current Account 
    $previousAccount = Get-ADUser -Identity $aRef -Properties @("mail","proxyAddresses","sAMAccountName") -Server $pdc | Select SID, UserPrincipalName, sAMAccountName, distinguishedName, mail, proxyAddresses, @{n="primarySMTP";e={$_.proxyAddresses | Where { $_ -clike "SMTP:*"}}}

    # Confirm Name has changed
    if(($pp.Name.GivenName -ne $p.Name.GivenName -or $pp.Name.FamilyName -ne $p.Name.FamilyName) -or $previousAccount.primarySMTP -ne "SMTP:$($previousAccount.mail)")
    {
        # Check Name Logic
		# TBD...
		
		# Check Proxy Addresses
        Write-Information "Name Change detected";
        Write-Information "Current Proxy Addresses $($previousAccount.proxyAddresses | ConvertTo-Json)"
        try
        {
            if($previousAccount.primarySMTP -ne "SMTP:$($previousAccount.mail)")
            {
                if(-Not($dryRun -eq $True)) {

                    Write-Information "Current Primary SMTP [$($previousAccount.primarySMTP)] should be [SMTP:$($previousAccount.mail)]"

                    #Remove Primary
                    Write-Information "Remove Address [$($previousAccount.primarySMTP)]";
                    $previousAccount | Set-AdUser -Remove @{ProxyAddresses=$($previousAccount.primarySMTP)} -Server $pdc;
                    $auditLogs.Add([PSCustomObject]@{
                                                        Action = "UpdateAccount"
                                                        Message = "Removed proxyAddress [$($previousAccount.primarySMTP)] for $($previousAccount.sAMAccountName)"
                                                        IsError = $False
                                                    })

                    #Change Primary to Alias
                    Write-Information "Add Address [$($previousAccount.primarySMTP.ToLower())]";
                    $previousAccount | Set-AdUser -Add @{ProxyAddresses=$($previousAccount.primarySMTP.ToLower())} -Server $pdc;
                    $auditLogs.Add([PSCustomObject]@{
                                                        Action = "UpdateAccount"
                                                        Message = "Add proxyAddress [$($previousAccount.primarySMTP.ToLower())] for $($previousAccount.sAMAccountName)"
                                                        IsError = $False
                                                    })

                    #Add New Primary
                    Write-Information "Add Address [SMTP:$($previousAccount.mail)]";
                    $previousAccount | Set-AdUser -Add @{ProxyAddresses="SMTP:$($previousAccount.mail)"} -Server $pdc;
                     $auditLogs.Add([PSCustomObject]@{
                                                        Action = "UpdateAccount"
                                                        Message = "Add proxyAddress [$($previousAccount.mail)] for $($previousAccount.sAMAccountName) "
                                                        IsError = $False
                                                    })
                }
            }
            else
            {
                Write-Information "Primary SMTP correct. No change required."
            }

            $success = $true;
        }
        catch
        {
            $auditLogs.Add([PSCustomObject]@{
                                            Action = "UpdateAccount"
                                            Message = "Failed to update proxyAddress: $($_)"
                                            IsError = $True
                                        })
        }
        #Get Updated Account
        $updatedAccount = Get-ADUser -Identity $aRef -Properties @("mail","proxyAddresses") -Server $pdc | Select SID, UserPrincipalName, distinguishedName, mail, proxyAddresses, @{n="primarySMTP";e={$_.proxyAddresses | Where { $_ -clike "SMTP:*"}}}    
    }
    else
    {
        $updatedAccount = $previousAccount;
        Write-Information "Skipped proxy addresses update (No Name Change)";
        $success = $true;
    }


#endregion Execute


#region Build up result
$result = [PSCustomObject]@{
    Success = $success
    AccountReference = $aRef
    AuditLogs = $auditLogs;
    Account = $updatedAccount
    PreviousAccount = $previousAccount
    
    ExportData = [PSCustomObject]@{
        proxyAddresses = $updatedAccount.proxyAddresses    
    }
};
  
Write-Output ($result | ConvertTo-Json -Depth 10)
#endregion Build up result