#region Configuration
$config = @{
    TargetOU= "OU=Disabled Users,DC=domain,DC=com";
    DeleteAfterDays = 30;
    DescriptionPrefix = "AUTOMATED - Delete After: ";
    Enabled = $false;
    UpdateInvalidDescriptions = $false;
    LogSkips = $true;
    MaxDeletes = 50;
}

#Get PDC
try{
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}

#endregion Configuration

#region Supporting Functions
function Write-HidStatus{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Message,
 
        [Parameter(Mandatory=$true)]
        [String]
        $Event
    )
    if([String]::IsNullOrEmpty($portalBaseUrl) -eq $true){
        Write-Output ($Message)
    }else{
        Hid-Write-Status -Message $Message -Event $Event
    }
}

function Write-HidSummary{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Message,
 
        [Parameter(Mandatory=$true)]
        [String]
        $Event
    )
    if([String]::IsNullOrEmpty($portalBaseUrl) -eq $true){
        Write-Output ($Message)
    }else{
        Hid-Write-Summary -Message $Message -Event $Event
    }
}
#endregion Supporting Functions

#region Execute
    #Get Disabled Users from Target OU
    $disabledUsers = Get-ADUser -LDAPFilter "(UserAccountControl:1.2.840.113556.1.4.803:=2)" -SearchBase $config.TargetOU -Properties Description -Server $pdc

    $i=0;
    #Loop over Disabled Users
    foreach($user in $disabledUsers)
    {
        #Check if User contains Prefix
        if($user.Description -like "$($config.DescriptionPrefix)*")
        {
            $deleteDate = [datetime]::parse($user.Description.replace($config.DescriptionPrefix,'')) # Original parseExact 2nd parameter: , 'yyyy-MM-dd', $null)

            if((Get-Date) -gt $deleteDate)
            {
                $message = "Deleting User [{0}] - [{1}]" -f $user.sAMAccountName,$deleteDate
                if($config.Enabled)
                {
                    #Stop Processing if Max Deletes thresholds exceeded
                    if($i -ge $config.MaxDeletes) { Write-HidStatus -Event Warning -Message ("Stopping: Max Delete threshold met [{0}].  Total Accounts to Evaluate: {1}" -f $config.MaxDeletes,$disabledUsers.count); break; }
                    
                    Write-HidStatus -Event Warning -Message $message;
                    try
                    {
                        Remove-ADUser -Identity $user.SamAccountName -Confirm:$false;
                        Write-HidSummary -Event Success -Message ("Deleted User [{0}]" -f $user.sAMAccountName)
                    }
                    catch
                    {
                        Write-HidSummary -Event Error -Message ("Failed to Delete [{0}], stopping processing" -f $user.SamAccountName);
                        break;
                    }
                    $i++;
                }
                else
                {
                    Write-HidStatus -Event Warning -Message ("Read-Only: {0}" -f $user.SamAccountName)
                }
            }
            else
            {
                if($config.LogSkips) { Write-HidStatus -Event Information ("Skipped, future date - {0} - [{1:u}]" -f $user.sAMAccountName,$deleteDate); }
            }
        }
        #Add Delete Prefix
        else
        {
            #Set Date based on DeleteAfterDays config
            $date = (Get-Date).AddDays($config.DeleteAfterDays).ToString('yyyy-MM-dd');
            
            $message = "Invalid Description on [{0}]: [{1}] - Setting New User Description [{2}{3}]" -f $user.sAMAccountName,$user.description,$config.DescriptionPrefix,$date;
            if($config.Enabled -AND $config.UpdateInvalidDescriptions)
            {
                Write-HidStatus -Event Warning -Message $message;
                try
                {
                    Set-ADUser -Identity $user.SamAccountName -Replace @{ Description= ("{0}{1}" -f $config.DescriptionPrefix,$date)} -Server $pdc
                    Write-HidSummary -Event Success -Message "Updated User Description: [$($user.sAMAccountName)]"
                }
                catch
                {
                    Write-HidSummary -Event Error -Message ("Failed to update description for {0}, stopping processing" -f $user.SamAccountName);
                    break;
                }
            }
            else
            {
                Write-HidStatus -Event Information -Message ("Read-Only: {0}" -f $message )
            }
        }
    }
#endregion Execute
