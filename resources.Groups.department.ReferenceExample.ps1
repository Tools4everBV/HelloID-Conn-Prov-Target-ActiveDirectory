# The resourceData used in this default script uses resources based on Title
$rRef = $resourceContext | ConvertFrom-Json
$success = $true

$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()

# Troubleshooting
# $dryRun = $false
$debug = $true

$path = "OU=Groups,OU=Resources,DC=consultancytest,DC=nl"
$adGroupNamePrefix = ""
$adGroupNameSuffix = ""
$adGroupDescriptionPrefix = "Security Group voor combinatie "
$adGroupDescriptionSuffix = ""

#Get Primary Domain Controller
try {
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}

#region Supporting Functions
function Get-ADSanitizeGroupName {
    param(
        [parameter(Mandatory = $true)][String]$Name
    )
    $newName = $name.trim()
    $newName = $newName -replace ' - ','_'
    $newName = $newName -replace '[`,~,!,#,$,%,^,&,*,(,),+,=,<,>,?,/,'',",,:,\,|,},{,.]', ''
    $newName = $newName -replace '\[', ''
    $newName = $newName -replace ']', ''
    # $newName = $newName -replace ' ','_'
    $newName = $newName -replace '\.\.\.\.\.', '.'
    $newName = $newName -replace '\.\.\.\.', '.'
    $newName = $newName -replace '\.\.\.', '.'
    $newName = $newName -replace '\.\.', '.'
    return $newName
}
#endregion Supporting Functions

#region Execute
# In preview only the first 10 items of the SourceData are used
try{
    foreach ($resource in $rRef.SourceData) {
        # Write-Information "Checking $($resource)"
        try {
            # The names of security principal objects can contain all Unicode characters except the special LDAP characters defined in RFC 2253.
            # This list of special characters includes: a leading space a trailing space and any of the following characters: # , + " \ < > 
            # A group account cannot consist solely of numbers, periods (.), or spaces. Any leading periods or spaces are cropped.
            # https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc776019(v=ws.10)?redirectedfrom=MSDN
            # https://www.ietf.org/rfc/rfc2253.txt
            
            
            # Example: Department (department differs from other objects as the property for the name is "DisplayName", not "Name")
            $ADGroupName = ("$adGroupNamePrefix" + "$($resource.DisplayName)" + "$adGroupNameSuffix")
            $ADGroupDescription = ("$adGroupDescriptionPrefix" + "$($resource.DisplayName)" + "$adGroupDescriptionSuffix")

            # Example: Title 
            # $ADGroupName = ("$adGroupNamePrefix" + "$($resource.Name)" + "$adGroupNameSuffix")
            # $ADGroupDescription = ("$adGroupDescriptionPrefix" + "$($resource.Name)" + "$adGroupDescriptionSuffix")

            # Example: Custom field (custom fields consists of only one attribute, no object with multiple attributes present!)
            # $ADGroupName = ("$adGroupNamePrefix" + "$($resource)" + "$adGroupNameSuffix")
            # $ADGroupDescription = ("$adGroupDescriptionPrefix" + "$($resource)" + "$adGroupDescriptionSuffix")

            $ADGroupName = Get-ADSanitizeGroupName -Name $ADGroupName

            $ADGroupParams = @{
                Name           = $ADGroupName
                SamAccountName = $ADGroupName
                GroupCategory  = "Security"
                GroupScope     = "Global"
                DisplayName    = $ADGroupName
                Path           = $path
                Description    = $ADGroupDescription
            }

            $distinguishedName = "CN=$($ADGroupParams.Name),$($ADGroupParams.Path)"
            $groupExists = [bool](Get-ADGroup -Filter { DistinguishedName -eq $distinguishedName } -Server $pdc)

            # If resource does not exist
            if ($groupExists -eq $False) {
                <# Resource creation preview uses a timeout of 30 seconds
                while actual run has timeout of 10 minutes #>
                Write-Information "Creating $($distinguishedName)"

                if (-Not($dryRun -eq $True)) {
                    $NewADGroup = New-ADGroup @ADGroupParams

                    $success = $True
                    $auditLogs.Add([PSCustomObject]@{
                            Message = "Created resource for $($resource) - $distinguishedName"
                            # Message = "Created resource for $($resource.name) - $distinguishedName"
                            Action  = "CreateResource"
                            IsError = $false
                        })
                }
            }
            else {
                if ($debug -eq $true) { Write-Warning "Group $($distinguishedName) already exists" }
                $success = $True
                # $auditLogs.Add([PSCustomObject]@{
                #     Message = "Skipped resource for $($resource.name) - $distinguishedName"
                #     Action  = "CreateResource"
                #     IsError = $false
                # })
        
            }
            
        }
        catch {
            Write-Warning "Failed to Create $($distinguishedName). Error: $_"

            # $success = $false
            $auditLogs.Add([PSCustomObject]@{
                    Message = "Failed to create resource for $($resource) - $distinguishedName. Error: $_"
                    # Message = "Failed to create resource for $($resource.name) - $distinguishedName. Error: $_"
                    Action  = "CreateResource"
                    IsError = $true
                })
        }
    }
}
#endregion Execute
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($auditLogs.IsError -contains $true)) {
        $success = $true
    }

    #region Build up result
    $result = [PSCustomObject]@{
        Success   = $success
        AuditLogs = $auditLogs
    }
    Write-Output ($result | ConvertTo-Json -Depth 10)
    #endregion Build up result
}