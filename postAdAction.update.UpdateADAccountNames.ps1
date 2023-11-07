#Initialize default properties
$p = $person -creplace ("samAccountName","oldsamAccountName") | ConvertFrom-Json
#$p = $person | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()
# The entitlementContext contains the domainController, adUser, configuration, exchangeConfiguration and exportData
# - domainController: The IpAddress and name of the domain controller used to perform the action on the account
# - adUser: Information about the adAccount: objectGuid, samAccountName and distinguishedName
# - configuration: The configuration that is set in the Custom PowerShell configuration
# - exchangeConfiguration: The configuration that was used for exchange if exchange is turned on
# - exportData: All mapping fields where 'Store this field in person account data' is turned on
# - mappedData: The output of the mapping script
# - account: The data available in the notification
# - previousAccount: The data before the update action
$eRef = $entitlementContext | ConvertFrom-Json

$max_iterations = 10
$upn_suffix = "domain.com"
$mail_suffix = "domain.com"

if([string]::IsNullOrEmpty($p.Name.Nickname)) { $calcFirstName = $p.Name.GivenName } else { $calcFirstName = $p.Name.Nickname }

#region functions
# Write functions logic here
function sanitizeName
{
    param($string)
    
    if($string -isnot [string]){return ''}
    $string = $string.trim()
    $string = [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
    $string = $string -replace '[\W_]',''
    $string
}

<# 
# Generate sAMAccountName using an expanding first name, falling back to a numeric iterator once max length is reached
#>
function generate-sAMAccountName()
{
    param(
      [int]$iterator = 0
      ,$firstName
      ,$lastName
    )

    $suffix = ""
	$maxAttributeLength = 20 - $suffix.Length

	$firstNameLength = $firstName.Length
	$sAMAccountName = $firstName.Substring(0, [Math]::Min($iterator + 1, $firstNameLength)) + $lastname

	# Convert to lower case
	$sAMAccountName = $sAMAccountName.ToLower()

	# Remove diacritical chars
	$sAMAccountName = $sAMAccountName -replace '[^\x20-\x7E]', ''

	# Remove specific chars
	$sAMAccountName = $sAMAccountName -replace '[^a-zA-Z0-9]', ''

	# Shorten to maximum allowable length
	$sAMAccountName = $sAMAccountName.Substring(0, [Math]::Min($sAMAccountName.Length, 20))

	If ($iterator -gt $firstNameLength) {
		# We've gone past the max length of the first name. Time to use a numeric iterator.
		$suffix = [string]($iterator - $firstNameLength + 1)

		$sAMAccountName = $sAMAccountName.Substring(0, [System.Math]::Min($sAMAccountName.Length, 20-$suffix.Length)) + $suffix
	}

	Return $sAMAccountName
}
#endregion functions

# if the names on the previous account are not the same as the current account

if ($eref.PreviousAccount.GivenName -ne $eref.Account.GivenName -or $eref.PreviousAccount.sn -ne $eref.Account.sn) {
    <# Action to perform if the condition is true #>
    try {

        $aduser = Get-ADUser $eRef.aduser.ObjectGuid -Server $eRef.domainController.Name -ErrorAction 'Stop'
        Write-Information ("Current sAMAccountName: {0}" -f $aduser.sAMAccountName )

        #Start Loop - Iterator = 0
        $i = 0
        do {
            
            $sAMAccountName = generate-sAMAccountName -firstName $calcFirstName -lastName $p.Name.FamilyName -Iterator ($i++)
            Write-Information ("Generated sAMAccountName: {0}" -f $sAMAccountName)
            $found_account = Get-ADUser -LDAPFilter ("(sAMAccountName={0})" -f $sAMAccountName)
            
        } while (
            # Iterate when AD Account Found with that sAMAccountName
            $i -lt $max_iterations -AND ($aduser.sAMAccountName -ne $sAMAccountName) -AND ($null -ne $found_account)
        )       
        #End Loop
        if($i -ge $max_iterations)
        {
            $success = $false
            $auditLogs.Add([PSCustomObject]@{
                Action = "UpdateAccount"
                Message = "Exceeded Max NameGen Iterations"
                IsError = $true
            })
            throw ('Max NameGen Iterations Exceeded for Person: {0}' -f $p.DisplayName)
        }
        
        if(-Not($dryRun -eq $True))
        {
            # Set up mail and UPN
            $upn = $sAMAccountName + "@" + $upn_suffix
            $mail = $sAMAccountName + "@" + $mail_suffix
            
			# Update user account
            $updatedAccount = set-aduser $eRef.aduser.objectguid -samAccountName $sAMAccountName -EmailAddress $mail -UserPrincipalName $upn -server $eRef.domainController.Name
            
            $auditLogs.Add([PSCustomObject]@{
                Action = "UpdateAccount"
                Message = ("Account for {0} was updated due to a name change" -f $p.DisplayName)
                IsError = $false
            })

            $eref.exportdata | Add-Member -MemberType NoteProperty -Name 'mail' -Value $mail -force 
            $eref.exportdata | Add-Member -MemberType NoteProperty -Name 'SamAccountName' -Value $sAMAccountName -force
            $success = $true
        }else{
            Write-Information("[Dry Run]: User {0} would have had a name change" -f $p.DisplayName) 
            $success = $true
        }
    }
    catch {
        $success = $false
        $auditLogs.Add([PSCustomObject]@{
                    Action = "UpdateAccount"
                    Message = "Error finding account or updating the account:  $_"
                    IsError = $True
                })
        Write-Error $_
    }
} else {
    Write-Information("User: {0} is not eligible for post action update: Name Change" -f $p.DisplayName)
    $success = $true
}

# Build up result
$result = [PSCustomObject]@{
    Success   = $success
    AuditLogs = $auditLogs

    # Return data for use in other systems.
    # If not present or empty the default export data will be used
    # The $eRef.exportData contains the export data from the mapping which is the default
    # When an object is returned the export data will be overwritten with the provided data
    ExportData = $eRef.exportData

    # Return data for use in notifications.
    # If not present or empty the default account data will be used    
    # When both the account object and previousAccount object are returned this data is used for notifications
    # Note that in order for a notification to be send there needs to be a difference between both objects
    Account = $eRef.account
    PreviousAccount = $eRef.previousAccount
}

#send result back
Write-Output $result | ConvertTo-Json -Depth 10