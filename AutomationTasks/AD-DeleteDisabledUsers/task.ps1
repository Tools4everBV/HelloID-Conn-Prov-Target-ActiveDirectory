$config = @{
        TargetOU= "OU=Disabled Users,DC=domain,DC=com";
        DeleteAfterDays = 30;
        DescriptionPrefix = "AUTOMATED - Delete After: ";
        Enabled = $false;
        LogSkips = $true;
        MaxDeletes = 50;
}

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

#Get PDC
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator

#Get Disabled Users from Target OU
$disabledUsers = Get-ADUser -LDAPFilter "(UserAccountControl:1.2.840.113556.1.4.803:=2)" -SearchBase $config.TargetOU -Properties Description -Server $pdc


$i=0;
#Loop over Disabled Users
foreach($user in $disabledUsers)
{
    #Check if User contains Prefix
    if($user.Description -like "$($config.DescriptionPrefix)*")
    {
        $deleteDate = [datetime]::parseexact($user.Description.replace($config.DescriptionPrefix,''), 'yyyy-MM-dd', $null)

        if((Get-Date) -gt $deleteDate)
        {
            $message = "Deleting User [$($user.sAMAccountName)] - [$($deleteDate)]"
            if($config.Enabled)
            {
                #Stop Procssing if Max Deletes thresholds exceeded
				if($i -ge $config.MaxDeletes) { Write-Warning -Verbose "Max Delete threshold met [$($config.MaxDeletes)]"; break; }
				
				Write-HidStatus -Event Warning -Message $message;
                try
                {
                    Remove-ADUser -Identity $user.SamAccountName -Confirm:$false;
                    Write-HidSummary -Event Success -Message "Deleted User [$($user.sAMAccountName)]"
                }
                catch
                {
                    Write-HidSummary -Event Error -Message "Failed to Delete $user.SamAccountName, stopping processing" ;
                    break;
                }
                $i++;
            }
            else
            {
                Write-HidStatus -Event Warning  "Read-Only, $($message)"
            }
        }
        else
        {
            if($config.LogSkips) { Write-HidStatus -Event Information "Skipped, future date - $($user.sAMAccountName) [$($deleteDate)]"; }
        }
    }
    #Add Delete Prefix
    else
    {
        #Set Date based on DeleteAfterDays config
        $date = (Get-Date).AddDays($config.DeleteAfterDays).ToString('yyyy-MM-dd');
        
        $message = "Setting User Delete Date [$($user.sAMAccountName)] - [$($deleteDate)]";
        if($config.Enabled)
        {
            Write-HidStatus -Event Warning -Message $message;
            try
            {
                Set-ADUser -Identity $user.SamAccountName -Replace @{ Description= "Student - AUTOMATED - Delete After: $($date)"} -Server $pdc
                Write-HidSummary -Event Success -Message "Set User Delete Date [$($user.sAMAccountName)]"
            }
            catch
            {
                Write-HidSummary -Event Error -Message "Failed to update delete date for $user.SamAccountName, stopping processing";
                break;
            }
        }
        else
        {
            Write-Verbose -Verbose "Read-Only, $($message)"
        }
    }
}