# The resourceData used in this default script uses resources based on Title
$rRef = $resourceContext | ConvertFrom-Json
$success = $false

$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

#Get Primary Domain Controller
$pdc = (Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -Property PDCEmulator).PDCEmulator
Write-Information "Using PDC [$pdc]"

# In preview only the first 10 items of the SourceData are used
foreach ($title in $rRef.SourceData) {
    $calc_title = $title.Name;
    $calc_title = $calc_title -replace '\s','_' #Remove Spaces 
    $calc_title = $calc_title -replace '[^a-zA-Z0-9_]', '' #Remove Special Characters, except underscore
    $calc_title = $calc_title -replace '__','_' #Remove Double Underscores 
    $calc_groupName = "IAM_TITLE_$($calc_title)"

    if($calc_groupName -eq "IAM_TITLE_") { continue }

    $groupExists = [bool](Get-ADGroup -Filter "sAMAccountName -eq '$($calc_groupName)'" -Server $pdc)

    # If resource does not exist
    if ($groupExists -eq $False) {
        <# Resource creation preview uses a timeout of 30 seconds
           while actual run has timeout of 10 minutes #>
        Write-Information "Creating $($calc_groupName)"

        if (-Not($dryRun -eq $True)) {
            try{
                New-ADGroup -Name $calc_groupName -SamAccountName $calc_groupName -GroupCategory Security -GroupScope Global -Path "OU=Titles,OU=IAM,OU=Groups,OU=Phoenix1,DC=pesd,DC=ad" -Server $pdc
                $success = $True
            } catch {
                Write-Error "Failed to Create $($calc_groupName) - $_"
            }
        }

        $auditLogs.Add([PSCustomObject]@{
            Message = "Creating resource for title $($title.name) - $calc_groupName"
            Action  = "CreateResource"
            IsError = $false
        })
    }
}

$success = $true

# Send results
$result = [PSCustomObject]@{
    Success   = $success
    AuditLogs = $auditLogs
}

Write-Output $result | ConvertTo-Json -Depth 10