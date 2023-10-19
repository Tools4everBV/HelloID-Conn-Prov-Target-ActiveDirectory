#####################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-Resources-Groups-Title
#
# Version: 1.1.0
#####################################################
$rRef = $resourceContext | ConvertFrom-Json
$success = $false # Set to false at start, at the end, only when no error occurs it is set to true

$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()

# Troubleshooting
# $dryRun = $false # In preview, only 10 (random) records will be processed
$debug = $false # Warning! Only set to true when troubleshooting, this will severly impact the performance.

# Variables to define what groups to query (to check if group already exists)
$adGroupsSearchOUs = @("OU=Groups,OU=Resources,DC=enyoi,DC=org", "OU=Groups2,OU=Resources,DC=enyoi,DC=org") # Warning! When no searchOUs are specified. Groups from all ous will be retrieved.
# Example: $adGroupsSearchOUs = @("OU=Groups,OU=Resources,DC=enyoi,DC=org","OU=Combination Groups,OU=Resources,DC=enyoi,DC=org")
$adGroupsSearchFilter = "" # Warning! When no searchFilter is specified. All groups will be retrieved.
# Example: $adGroupsSearchFilter = "Name -like `"combination group`""

# Correlation values
$correlationProperty = "Description" # The AD group property that contains the unique identifier
$correlationValue = "ExternalId" # The HelloID resource property that contains the unique identifier

# Additionally set resource properties as required
$requiredFields = @("ExternalId", "Name")

#region Supporting Functions
function Get-ADSanitizedGroupName {
    # The names of security principal objects can contain all Unicode characters except the special LDAP characters defined in RFC 2253.
    # This list of special characters includes: a leading space a trailing space and any of the following characters: # , + " \ < > 
    # A group account cannot consist solely of numbers, periods (.), or spaces. Any leading periods or spaces are cropped.
    # https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc776019(v=ws.10)?redirectedfrom=MSDN
    # https://www.ietf.org/rfc/rfc2253.txt    
    param(
        [parameter(Mandatory = $true)][String]$Name
    )
    $newName = $name.trim()
    $newName = $newName -replace " - ", "_"
    $newName = $newName -replace "[`,~,!,#,$,%,^,&,*,(,),+,=,<,>,?,/,',`",,:,\,|,},{,.]", ""
    $newName = $newName -replace "\[", ""
    $newName = $newName -replace "]", ""
    $newName = $newName -replace " ", "_"
    $newName = $newName -replace "\.\.\.\.\.", "."
    $newName = $newName -replace "\.\.\.\.", "."
    $newName = $newName -replace "\.\.\.", "."
    $newName = $newName -replace "\.\.", "."

    # Remove diacritics
    $newName = Remove-StringLatinCharacters $newName
    
    return $newName
}

function Get-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $errorMessage = [PSCustomObject]@{
            VerboseErrorMessage = $null
            AuditErrorMessage   = $null
        }

        $errorMessage.VerboseErrorMessage = $ErrorObject.Exception.Message
        $errorMessage.AuditErrorMessage = $ErrorObject.Exception.Message

        Write-Output $errorMessage
    }
}
#endregion Supporting Functions

#region Execute

# Get Primary Domain Controller
try {
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}
catch {
    Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
    Write-Warning "Retrying PDC Lookup"
    $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
}

# Query AD groups
try {
    if ([String]::IsNullOrEmpty($adGroupsSearchFilter)) {
        $adGroupsSearchFilter = "*"
    }

    Write-Verbose "Querying AD groups that match the filter [$adGroupsSearchFilter]"

    $properties = @(
        , "SamAccountName"
        , "Name"
        , "DisplayName"
        , "Description"
        , "GroupCategory"
        , "GroupScope"
        , "Path"
        , $correlationProperty
    )

    $adQuerySplatParams = @{
        Filter     = $adGroupsSearchFilter
        Properties = $properties
        Server     = $pdc
    }

    if (($adGroupsSearchOUs | Measure-Object).Count -eq 0) {
        Write-Information "Querying AD groups that match filter [$($adGroupsSearchFilter)]"
        $adGroups = Get-ADGroup @adQuerySplatParams | Select-Object $properties
    }
    else {
        $adGroups = foreach ($adGroupsSearchOU in $adGroupsSearchOUs) {
            Write-Information "Querying AD groups that match filter [$($adGroupsSearchFilter)] in OU [$($adGroupsSearchOU)]"
            Get-ADGroup @adQuerySplatParams -SearchBase $adGroupsSearchOU | Select-Object $properties
        }
    }

    # Group on samAccountName (to check if group exists (as samAccountName has to be unique for a group))
    $adGroupsGrouped = $adGroups | Group-Object $correlationProperty -AsString -AsHashTable

    Write-Information "Succesfully queried AD groups. Result count: $(($adGroups | Measure-Object).Count)"
}
catch {
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"
        
    throw "Failed to query AD groups. Error Message: $($errorMessage.AuditErrorMessage)"
}

# In preview only the first 10 items of the SourceData are used
try {
    foreach ($resource in $rRef.SourceData) {
        Write-Verbose "Checking $($resource)"

        #region Check if required fields are available for correlation
        $incompleteCorrelationValues = $false
        if ([String]::IsNullOrEmpty($correlationProperty)) {
            $incompleteCorrelationValues = $true
            Write-Warning "Required correlation field [$correlationProperty] has a null or empty value"
        }
        if ([String]::IsNullOrEmpty($correlationValue)) {
            $incompleteCorrelationValues = $true
            Write-Warning "Required correlation field [$correlationValue] has a null or empty value"
        }
        if ($incompleteCorrelationValues -eq $true) {
            if (-Not($dryRun -eq $True)) {
                if ($debug -eq $true) {
                    Write-Information "Debug: Correlation values incomplete, cannot continue. CorrelationProperty = [$correlationProperty], CorrelationValue = [$correlationValue]"
    
                    $auditLogs.Add([PSCustomObject]@{
                            Message = "Skipped creating group for resource [$($resource | ConvertTo-Json)]. (Correlation values incomplete, cannot continue. CorrelationProperty = [$correlationProperty], CorrelationValue = [$correlationValue])"
                            Action  = "CreateResource"
                            IsError = $false
                        })
                }
            }
            else {
                Write-Warning "DryRun: Correlation values incomplete, cannot continue. CorrelationProperty = [$correlationProperty], CorrelationValue = [$correlationValue]"
            }

            # Skip further actions, as this is a critical error
            continue
        }
        #endregion Check if required fields are available for correlation

        #region Check if required fields are available in resource object
        $incompleteResource = $false
        $missingFields = [System.Collections.ArrayList]@()
        foreach ($requiredField in $requiredFields) {
            if ($requiredField -notin $resource.PsObject.Properties.Name) {
                $incompleteResource = $true
                [void]$missingFields.Add($requiredField)
                if ($debug -eq $true) { Write-Warning "Resource object is missing required field [$requiredField]" }
            }

            if ([String]::IsNullOrEmpty($resource.$requiredField)) {
                $incompleteResource = $true
                [void]$missingFields.Add($requiredField)
                if ($debug -eq $true) { Write-Warning "Resource object has a null or empty value for required field [$requiredField]" }
            }
        }
        if ($incompleteResource -eq $true) {
            if (-Not($dryRun -eq $True)) {
                if ($debug -eq $true) {
                    Write-Information "Debug: Resource object incomplete, cannot continue. Missing fields: $($missingFields -join ';')"
                    Write-Information "Debug: Resource object: $($resource | ConvertTo-Json)"
    
                    $auditLogs.Add([PSCustomObject]@{
                            Message = "Skipped creating group for resource [$($resource | ConvertTo-Json)]. (Resource missing required fields. Missing fields: $($missingFields -join ';'))"
                            Action  = "CreateResource"
                            IsError = $false
                        })
                }
            }
            else {
                Write-Warning "DryRun: Resource object incomplete, cannot continue. Missing fields: $($missingFields -join ';')"
                if ($debug -eq $true) { Write-Information "Debug: Resource object: $($resource | ConvertTo-Json)" }
            }

            # Skip further actions, as this is a critical error
            continue
        }
        #endregion Check if required fields are available in resource object

        try {
            #region mapping
            # The names of security principal objects can contain all Unicode characters except the special LDAP characters defined in RFC 2253.
            # This list of special characters includes: a leading space a trailing space and any of the following characters: # , + " \ < > 
            # A group account cannot consist solely of numbers, periods (.), or spaces. Any leading periods or spaces are cropped.
            # https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc776019(v=ws.10)?redirectedfrom=MSDN
            # https://www.ietf.org/rfc/rfc2253.txt

            $path = "OU=Groups,OU=Resources,DC=enyoi,DC=org"   
      
            # Best practice to use the id of the resource to avoid max char limitations and issues in case of name change
            $groupName = ("title_" + "$($resource.ExternalId)")
            # Other example to use name of resource:
            $groupName = ("title_" + "$($resource.Name)")
            $groupName = Get-ADSanitizedGroupName -Name $groupName

            # Best practice to place the unique identifier that doesn't change (mostly id or code) in the correlationProperty, e.g. description to support name change
            # In this example the description is set with the correlationProperty
            $groupDescription = "$($resource.$correlationValue)"

            $ADGroupParams = @{
                SamAccountName = $groupName
                Name           = $groupName
                DisplayName    = $groupName
                Description    = $groupDescription
                GroupCategory  = "Security"
                GroupScope     = "Global"
                Path           = $path
            }
            #endregion mapping

            # Check if group exists
            $currentADGroup = $null
            if ($null -ne $adGroupsGrouped) {
                $currentADGroup = $adGroupsGrouped["$($ADGroupParams.$correlationValue)"]
            }

            # Create new group if group does not exist yet
            if ($null -eq $currentADGroup) {
                <# Resource creation preview uses a timeout of 30 seconds
                while actual run has timeout of 10 minutes #>
                if (-Not($dryRun -eq $True)) {
                    if ($debug -eq $true) {
                        Write-Information "Debug: Creating group [$($ADGroupParams.DisplayName)] for resource [$($resource | ConvertTo-Json)]"
                        Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)"
                    }

                    $NewADGroup = New-ADGroup @ADGroupParams

                    $auditLogs.Add([PSCustomObject]@{
                            Message = "Created group [$($ADGroupParams.DisplayName)] for resource [$($resource | ConvertTo-Json)]"
                            Action  = "CreateResource"
                            IsError = $false
                        })
                }
                else {
                    Write-Warning "DryRun: Would create group [$($ADGroupParams.DisplayName)] for resource [$($resource | ConvertTo-Json)]"
                    if ($debug -eq $true) { Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)" }
                }

            }
            else {
                # Create new group if group does not exist yet
                if (-Not($dryRun -eq $True)) {
                    if ($debug -eq $true) {
                        Write-Information "Debug: Group where [$($correlationProperty)] = [$($correlationValue)] already exists"

                        $auditLogs.Add([PSCustomObject]@{
                                Message = "Skipped creating group $($correlationProperty)] = [$($correlationValue)] for resource [$($resource | ConvertTo-Json)]. (Already exists)"
                                Action  = "CreateResource"
                                IsError = $false
                            })
                    }
                }
                else {
                    Write-Warning "DryRun: Group $($correlationProperty)] = [$($correlationValue)] for resource [$($resource | ConvertTo-Json)] already exists"
                    if ($debug -eq $true) { Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)" }
                }
            }
        }
        catch {
            $ex = $PSItem
            $errorMessage = Get-ErrorMessage -ErrorObject $ex
        
            Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"
        
            Write-Warning "Failed to create group [$($ADGroupParams.DisplayName)] for resource [$($resource | ConvertTo-Json)]. Error Message: $($errorMessage.AuditErrorMessage)"
            if ($debug -eq $true) {
                Write-Information "Debug: Resource: $($resource | ConvertTo-Json)"
                Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)"
            }
    
            $auditLogs.Add([PSCustomObject]@{
                    Message = "Failed to create group [$($ADGroupParams.DisplayName)] for resource [$($resource | ConvertTo-Json)]. Error Message: $($errorMessage.AuditErrorMessage)"
                    Action  = "CreateResource"
                    IsError = $true
                })
        }
    }
}
#endregion Execute
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-not($auditLogs.IsError -contains $true)) {
        $success = $true
    }
    
    #region Build up result
    $result = [PSCustomObject]@{
        Success   = $success
        AuditLogs = $auditLogs
    }
    Write-Output ($result | ConvertTo-Json)
    #endregion Build up result
}