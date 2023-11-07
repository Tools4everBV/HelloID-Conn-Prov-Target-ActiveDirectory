#Initialize default properties
$p = $person | ConvertFrom-Json
$m = $manager | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$mRef = $managerAccountReference | ConvertFrom-Json

# The entitlementContext contains the domainController, adUser, configuration and exchangeConfiguration
# - domainController: The IpAddress and name of the domain controller used to perform the action on the account
# - adUser: Information about the adAccount: objectGuid, samAccountName and distinguishedName
# - configuration: The configuration that is set in the Custom PowerShell configuration
# - exchangeConfiguration: The configuration that was used for exchange if exchange is turned on
# - account: The data available in the notification
$eRef = $entitlementContext | ConvertFrom-Json

$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()
$success = $false

# logging preferences
$verbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

#region functions
function New-GeneratedPassword {
    <#
.SYNOPSIS
    This will generate a simple random password like "rvsZxx0lr" and optionally include numbers and/or special characters
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $MinimumLength = 8,

        [Parameter(Mandatory = $false)]
        $MaximumLength = 16,

        [Parameter(Mandatory = $false)]
        $MinimumUpperCaseLetters = 1,

        [Parameter(Mandatory = $false)]
        $MaximumUpperCaseLetters = 2,

        [Parameter(Mandatory = $false)]
        $MinimumDigits,

        [Parameter(Mandatory = $false)]
        $MaximumDigits,
                
        [Parameter(Mandatory = $false)]
        $MinimumSpecialChars,

        [Parameter(Mandatory = $false)]
        $MaximumSpecialChars,
        
        [Parameter(Mandatory = $false)]
        $AllowedLowerCaseLetters = "abcdefghiklmnoprstuvwxyz",

        [Parameter(Mandatory = $false)]
        $AllowedUpperCaseLetters = "ABCDEFGHKLMNOPRSTUVWXYZ",
        
        [Parameter(Mandatory = $false)]
        $AllowedDigits = "1234567890",

        [Parameter(Mandatory = $false)]
        $AllowedSpecialChars = "@#$%^&*-_!+=:?/();"
    )
    $lowerCaseLetters = $null
    $upperCaseLetters = $null
    $digits = $null
    $specialChars = $null

    # Total length of random password
    if ($MinimumLength -ne $MaximumLength) {
        $totalLength = Get-Random -Minimum $MinimumLength -Maximum $MaximumLength
    }
    else {
        $totalLength = $MaximumLength
    }

    <#--------- Upper case letters ---------#>
    # Total length of allowed upper case letters
    if ($MinimumUpperCaseLetters -and $MaximumUpperCaseLetters) {
        $amountOfUpperCaseLetters = Get-Random -Minimum $MinimumUpperCaseLetters -Maximum $MaximumUpperCaseLetters
    }
    elseif ($MinimumUpperCaseLetters -and !$MaximumUpperCaseLetters) {
        $amountOfUpperCaseLetters = Get-Random -Minimum $MinimumUpperCaseLetters -maximum ($MinimumUpperCaseLetters + 1)
    }
    elseif (!$MinimumUpperCaseLetters -and $MaximumUpperCaseLetters) {
        $amountOfUpperCaseLetters = Get-Random -Minimum ($MaximumUpperCaseLetters - 1) -Maximum $MaximumUpperCaseLetters
    }
    else {
        $amountOfUpperCaseLetters = 0
    }

    # Get random upper case letters
    if ($amountOfUpperCaseLetters -gt 0) {
        $random = 1..$amountOfUpperCaseLetters | ForEach-Object { Get-Random -Maximum $AllowedUpperCaseLetters.Length }
        $upperCaseLetters = ([String]$AllowedUpperCaseLetters[$random]).replace(" ", "")
    }

    <#--------- Digits ---------#>
    # Total length of allowed digits
    if ($MinimumDigits -and $MaximumDigits) {
        $amountOfDigits = Get-Random -Minimum $MinimumDigits -Maximum $MaximumDigits
    }
    elseif ($MinimumDigits -and !$MaximumDigits) {
        $amountOfDigits = Get-Random -Minimum $MinimumDigits -maximum ($MinimumDigits + 1)
    }
    elseif (!$MinimumDigits -and $MaximumDigits) {
        $amountOfDigits = Get-Random -Minimum ($MaximumDigits - 1) -Maximum $MaximumDigits
    }
    else {
        $amountOfDigits = 0
    }

    # Get random digits
    if ($amountOfDigits -gt 0) {
        $random = 1..$amountOfDigits | ForEach-Object { Get-Random -Maximum $AllowedDigits.Length }
        $digits = ([String]$AllowedDigits[$random]).replace(" ", "")
    }


    <#--------- Special Characters ---------#>
    # Total length of allowed special characters
    if ($MinimumSpecialChars -and $MaximumSpecialChars) {
        $amountOfSpecialChars = Get-Random -Minimum $MinimumSpecialChars -Maximum $MaximumSpecialChars
    }
    elseif ($MinimumSpecialChars -and !$MaximumSpecialChars) {
        $amountOfSpecialChars = Get-Random -Minimum $MinimumSpecialChars -maximum ($MinimumSpecialChars + 1)
    }
    elseif (!$MinimumSpecialChars -and $MaximumSpecialChars) {
        $amountOfSpecialChars = Get-Random -Minimum ($MaximumSpecialChars - 1) -Maximum $MaximumSpecialChars
    }
    else {
        $amountOfSpecialChars = 0
    }

    # Get random special chars
    if ($amountOfSpecialChars -gt 0) {
        $random = 1..$amountOfSpecialChars | ForEach-Object { Get-Random -Maximum $AllowedSpecialChars.Length }
        $specialChars = ([String]$AllowedSpecialChars[$random]).replace(" ", "")
    }

    <#--------- Lower case letters ---------#>
    # Get random lower case letters
    $amountOfLowerCaseLetters = ($totalLength - $amountOfUpperCaseLetters - $amountOfDigits - $amountOfSpecialChars)
    $random = 1..$amountOfLowerCaseLetters | ForEach-Object { Get-Random -Maximum $AllowedLowerCaseLetters.Length }
    $lowerCaseLetters = ([String]$AllowedLowerCaseLetters[$random]).replace(" ", "")

    # Join all generated password charactesr to one string
    $passwordCharacters = ($lowerCaseLetters + $upperCaseLetters + $digits + $specialChars).replace(" ", "")

    # Make sure password doesn't start with a digit
    $randomPassword = "$($lowerCaseLetters.ToCharArray() | Get-Random -Count 1)"

    # Scramble password characters
    $characterArray = $passwordCharacters.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count ($characterArray.Length - 1)
    $randomPassword += -join $scrambledStringArray
    return $randomPassword
}
#endregion functions

#region Change AD mapping here
try {
    Write-Verbose "Generating random password"

    $generatePasswordSplatParams = @{
        MinimumLength           = 14
        MaximumLength           = 16
        MinimumDigits           = 1
        MaximumDigits           = 2
        MinimumSpecialChars     = 1
        MaximumSpecialChars     = 2
        AllowedSpecialChars     = "!@#%&"
        AllowedLowerCaseLetters = "abcdefghijkmnpqrstuvwxyz"
        AllowedUpperCaseLetters = "ABCDEFGHKLMNPRSTUVWXYZ"
        AllowedDigits           = "23456789"
    }

    $Password = New-GeneratedPassword @generatePasswordSplatParams

    Write-Verbose "Successfully generated random password"
}
catch {
    throw "Error generating random password. Error: $($_.Exception.Message)"
}

$account = @{
    Identity              = $aRef.ObjectGuid
    Password              = $Password
    ChangePasswordAtLogon = $false
}
#region Change AD mapping here

try {
    # Get AD Account
    try {
        Write-Verbose "Querying AD user [$($account.Identity)]"

        $properties = @('SID', 'ObjectGuid', 'UserPrincipalName', 'SamAccountName', 'Description')
        $currentAccount = Get-ADUser -Identity $account.Identity -Properties $properties -Server $eRef.domainController.Name | Select-Object $properties

        Write-Verbose "Successfully queried AD user [$($account.Identity)]"
    }
    catch {
        throw "Error querying AD user [$($account.Identity)]. Error: $($_.Exception.Message)"
    }

    # Reset AD Account Password
    try {
        if (-Not($dryRun -eq $true)) {
            Write-Verbose "Resetting password of AD user [$($account.Identity)]. Change at next logon: [$($account.ChangePasswordAtLogon)]"

            $resetPasswordADUser = Set-ADAccountPassword -Identity $account.Identity -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $account.Password -Force)
            $updateADUser = Set-ADUser -Identity $account.Identity -ChangePasswordAtLogon $account.ChangePasswordAtLogon

            Write-Information "Successfully reset password of AD user [$($account.Identity)]. Change at next logon: [$($account.ChangePasswordAtLogon)]"
            $success = $true
            $auditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "Successfully reset password of AD user [$($account.Identity)]. Change at next logon: [$($account.ChangePasswordAtLogon)]"
                    IsError = $False
                })
        }
        else {
            $success = $true
            $auditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "DryRun: Would reset password of AD user [$($account.Identity)]. Change at next logon: [$($account.ChangePasswordAtLogon)]"
                    IsError = $False
                })
        }
    }
    catch {
        $success = $false
        $auditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Error resetting password of AD user [$($account.Identity)]. Change at next logon: [$($account.ChangePasswordAtLogon)]. Error: $($_.Exception.Message)"
                IsError = $True
            })
        throw "Error resetting password of AD user [$($account.Identity)]. Change at next logon: [$($account.ChangePasswordAtLogon)]. Error: $($_.Exception.Message)"
    }
}
catch {
    throw "Error executing Post AD action. Error: $($_.Exception.Message)"
}
finally {
    $accountData = $eRef.account
    # Add property for New Password to account
    $accountData | Add-Member -MemberType NoteProperty -Name "Password" -Value $Password -Force

    # Build up result
    $result = [PSCustomObject]@{
        Success   = $success
        AuditLogs = $auditLogs

        # Return data for use in other systems.
        # If not present or empty the default export data will be used
        # The $eRef.exportData contains the export data from the mapping which is the default
        # When an object is returned the export data will be overwritten with the provided data
        # ExportData = $eRef.exportData

        # Return data for use in notifications.
        # If not present or empty the default account data will be used
        # When an object is returned this data will be available in the notification
        Account   = $accountData
    }

    #send result back
    Write-Output $result | ConvertTo-Json -Depth 10
}