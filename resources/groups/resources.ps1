#####################################################
# HelloID-Conn-Prov-Target-ActiveDirectory-Resources-Groups
# PowerShell V2
#################################################

# Set debug logging
switch ($actionContext.Configuration.isDebug) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Variables to define what groups to query (to check if group already exists)
$adGroupsSearchOUs = @("OU=HelloID,OU=Security Groups,DC=enyoi,DC=org") # Warning! When no searchOUs are specified. Groups from all ous will be retrieved.
# Example: $adGroupsSearchOUs = @("OU=Groups,OU=Resources,DC=enyoi,DC=org","OU=Combination Groups,OU=Resources,DC=enyoi,DC=org")
$adGroupsSearchFilter = "" # Warning! When no searchFilter is specified. All groups will be retrieved.
# Example: $adGroupsSearchFilter = "Name -like `"combination group`""
$adGroupsCreateOU = "OU=HelloID,OU=Security Groups,DC=enyoi,DC=org"

# Correlation values
$correlationProperty = "ExtensionAttribute1" # The AD group property that contains the unique identifier
$correlationValue = "ExternalId" # The HelloID resource property that contains the unique identifier

# Additionally set resource properties as required
$requiredFields = @("ExternalId", "Name", "Code") # If title is used
# $requiredFields = @("ExternalId", "DisplayName") # If department is used

$resourceData = $resourceContext.SourceData 
# Example below for when the externalID is a combination of values
# $resourceData | foreach-object {
#     $_ | Add-Member -MemberType NoteProperty -Name "DepartmentCode" -Value $_.ExternalId
#     $_.ExternalId = $_.Code + "_" + $_.DepartmentCode
# }

$resourceData = $resourceData | Select-Object -Unique   ExternalId, Name, Code #, DepartmentCode

#region Supporting Functions
function Remove-StringLatinCharacters {
    PARAM ([string]$String)
    [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
}

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
    $newName = $newName -replace " - ", "-"
    $newName = $newName -replace "[`,~,!,#,$,%,^,&,*,(,),+,=,<,>,?,/,',`",,:,\,|,},{,.]", ""
    $newName = $newName -replace "\[", ""
    $newName = $newName -replace "]", ""
    $newName = $newName -replace " ", "-"
    $newName = $newName -replace "--", "-"
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
if ([string]::IsNullOrEmpty($actionContext.Configuration.fixedDomainController)) {
    try {
        $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
    }
    catch {
        Write-Warning ("PDC Lookup Error: {0}" -f $_.Exception.InnerException.Message)
        Write-Warning "Retrying PDC Lookup"
        $pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
    }
}
else {
    write-verbose "A fixed domain controller is configured [$($actionContext.Configuration.fixedDomainController)]"    
    $pdc = $($actionContext.Configuration.fixedDomainController)
}

# Query AD groups
try {
    if ([String]::IsNullOrEmpty($adGroupsSearchFilter)) {
        $adGroupsSearchFilter = "*"
    }

    Write-Verbose "Querying AD groups that match the filter [$adGroupsSearchFilter]"

    $properties = [System.Collections.ArrayList]@(
        , "SamAccountName"
        , "Name"
        , "DisplayName"
        , "Description"
        , "GroupCategory"
        , "GroupScope"
        , "extensionAttribute1"
        , "objectguid"
    )
    if ($correlationProperty -notin $properties) {
        [void]$properties.Add($correlationProperty)
    }

    $adQuerySplatParams = @{
        Filter     = $adGroupsSearchFilter
        Properties = $properties
        Server     = $pdc
    }

    if ([String]::IsNullOrEmpty($adGroupsSearchOUs)) {
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
    foreach ($resource in $resourceData) {
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
            if (-Not($actionContext.DryRun -eq $True)) {
                if ($actionContext.Configuration.isDebug -eq $true) {
                    Write-Information "Debug: Correlation values incomplete, cannot continue. CorrelationProperty = [$correlationProperty], CorrelationValue = [$correlationValue]"
    
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
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
                if ($actionContext.Configuration.isDebug -eq $true) { Write-Warning "Resource object is missing required field [$requiredField]" }
            }

            if ([String]::IsNullOrEmpty($resource.$requiredField)) {
                $incompleteResource = $true
                [void]$missingFields.Add($requiredField)
                if ($actionContext.Configuration.isDebug -eq $true) { Write-Warning "Resource object has a null or empty value for required field [$requiredField]" }
            }
        }
        if ($incompleteResource -eq $true) {
            if (-Not($actionContext.DryRun -eq $True)) {
                if ($actionContext.Configuration.isDebug -eq $true) {
                    Write-Information "Debug: Resource object incomplete, cannot continue. Missing fields: $($missingFields -join ';')"
                    Write-Information "Debug: Resource object: $($resource | ConvertTo-Json)"
    
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Skipped creating group for resource [$($resource | ConvertTo-Json)]. (Resource missing required fields. Missing fields: $($missingFields -join ';'))"
                            Action  = "CreateResource"
                            IsError = $false
                        })
                }
            }
            else {
                Write-Warning "DryRun: Resource object incomplete, cannot continue. Missing fields: $($missingFields -join ';')"
                if ($actionContext.Configuration.isDebug -eq $true) { Write-Information "Debug: Resource object: $($resource | ConvertTo-Json)" }
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

            # Best practice to use the id of the resource to avoid max char limitations and issues in case of name change
            $samaccountname = ("title_" + "$($resource.ExternalId)")
            $groupName = $resource.Name
            # # Other example to use name of resource:
            # $groupName = ("department_" + "$($resource.ExternalId)")
            # $groupName = ("title_" + "$($resource.Name)")
            # $groupName = ("department_" + "$($resource.DisplayName)")

            $groupName = Get-ADSanitizedGroupName -Name $groupName

            # Best practice to place the unique identifier that doesn't change (mostly id or code) in the correlationProperty, e.g. description to support name change
            # In this example the description is set with the correlationProperty
            $correlationValueOutput = "$($resource.$correlationValue)"

            # Example when correlationValue is extensionAttribute1
            $ADGroupParams = @{
                SamAccountName  = $samaccountname
                Name            = $groupName
                DisplayName     = $groupName
                OtherAttributes = @{'extensionAttribute1' = "$correlationValueOutput" }
                Description     = "Group managed by HelloID."
                GroupCategory   = "Security"
                GroupScope      = "Global"
                Path            = $adGroupsCreateOU
                Server          = $pdc
            }

            # Example when correlationValue is SamAccountName
            # $ADGroupParams = @{
            #     SamAccountName = $correlationValueOutput
            #     Name           = $groupName
            #     DisplayName    = $groupName
            #     Description    = "Group managed by HelloID."
            #     GroupCategory  = "Security"
            #     GroupScope     = "Global"
            #     Path           = $adGroupsCreateOU
            #     Server          = $pdc
            # }

            #endregion mapping

            # Check if group exists
            $currentADGroup = $null
            if ($null -ne $adGroupsGrouped) {
                # $currentADGroup = $adGroupsGrouped["$($ADGroupParams.$correlationProperty)"]
                $currentADGroup = $adGroupsGrouped[$correlationValueOutput]
            }

            # Create new group if group does not exist yet
            if ($null -eq $currentADGroup) {
                <# Resource creation preview uses a timeout of 30 seconds
                while actual run has timeout of 10 minutes #>
                if (-Not($actionContext.DryRun -eq $True)) {
                    if ($actionContext.Configuration.isDebug -eq $true) {
                        Write-Information "Debug: Creating group [$($ADGroupParams.Name)] for resource [$($resource | ConvertTo-Json)]"
                        Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)"
                    }

                    $null = New-ADGroup @ADGroupParams

                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Created group [$($ADGroupParams.Name)] for resource [$($resource | ConvertTo-Json)]"
                            Action  = "CreateResource"
                            IsError = $false
                        })
                }
                else {
                    Write-Warning "DryRun: Would create group [$($ADGroupParams.Name)] for resource [$($resource | ConvertTo-Json)]"
                    if ($actionContext.Configuration.isDebug -eq $true) { Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)" }
                }
            }
            else {
                if($actionContext.Configuration.renameResources -and ($currentADGroup.Name -ne $groupName -or $currentADGroup.DisplayName -ne $groupName))
                {
                    if (-Not($actionContext.DryRun -eq $True)) {
                        
                        Write-Information "Debug: Group where [$($correlationProperty)] = [$($correlationValue)] already exists, but will be renamed"

                        $SetADGroupParams = @{
                            Identity        = $currentADGroup.objectguid
                            DisplayName     = $groupName
                            Server          = $pdc
                        }
                        $null = Set-AdGroup @SetADGroupParams

                        $RenameADGroupParams = @{
                            Identity        = $currentADGroup.objectguid
                            NewName         = $groupName
                            Server          = $pdc
                        }
                        $null = Rename-ADObject @RenameADGroupParams

                        $outputContext.AuditLogs.Add([PSCustomObject]@{
                                Message = "Renaming group [$($correlationProperty)] = [$($correlationValue)] for resource [$($resource | ConvertTo-Json)]."
                                Action  = "CreateResource"
                                IsError = $false
                            })
                    }
                    else {
                        Write-Warning "DryRun: Group [$($correlationProperty)] = [$($correlationValue)] for resource [$($resource | ConvertTo-Json)] already exists but will be renamed"
                        if ($actionContext.Configuration.isDebug -eq $true) { Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)" }
                    }
                }
                else
                {
                    # Create new group if group does not exist yet
                    if (-Not($actionContext.DryRun -eq $True)) {
                        if ($actionContext.Configuration.isDebug -eq $true) {
                            Write-Information "Debug: Group where [$($correlationProperty)] = [$($correlationValue)] already exists"

                            $outputContext.AuditLogs.Add([PSCustomObject]@{
                                    Message = "Skipped creating group [$($correlationProperty)] = [$($correlationValue)] for resource [$($resource | ConvertTo-Json)]. (Already exists)"
                                    Action  = "CreateResource"
                                    IsError = $false
                                })
                        }
                    }
                    else {
                        Write-Warning "DryRun: Group $($correlationProperty)] = [$($correlationValue)] for resource [$($resource | ConvertTo-Json)] already exists"
                        if ($actionContext.Configuration.isDebug -eq $true) { Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)" }
                    }
                }
            }
        }
        catch {
            $ex = $PSItem
            $errorMessage = Get-ErrorMessage -ErrorObject $ex
        
            Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"
        
            Write-Warning "Failed to create group [$($ADGroupParams.Name)] for resource [$($resource | ConvertTo-Json)]. Error Message: $($errorMessage.AuditErrorMessage)"
            if ($actionContext.Configuration.isDebug -eq $true) {
                Write-Information "Debug: Resource: $($resource | ConvertTo-Json)"
                Write-Information "Debug: Group parameters: $($ADGroupParams | ConvertTo-Json)"
            }
    
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Failed to create group [$($ADGroupParams.Name)] for resource [$($resource | ConvertTo-Json)]. Error Message: $($errorMessage.AuditErrorMessage)"
                    Action  = "CreateResource"
                    IsError = $true
                })
        }
    }
}
#endregion Execute
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-not($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}