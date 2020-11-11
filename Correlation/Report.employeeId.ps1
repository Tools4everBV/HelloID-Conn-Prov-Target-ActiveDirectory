## Correlation Report by employeeId in Active Directory
## The purpose of this script is to pull in Source Data and check if we can link
## existing accounts by id. It will then report any accounts/persons
## that match up, need to be created, or we have multiple matches for.

## Instructions
## 1. Add Source Data
## 2. Update Settings

#Settings
$config = @{
                sourceDataIDField = 'EmployeeID'
}

#Source Data
    Write-Verbose -Verbose "Retrieving Source data";
    $persons = [System.Collections.ArrayList]@();
    Write-Verbose -Verbose "$($persons.count) source record(s)";

#AD Users
    $adUsers = Get-ADUser -LDAPFilter "(employeeId=*)" -Properties EmployeeID;
    Write-Verbose -Verbose "$($adUsers.count) ad users(s) with employeeID";

#Compare
    $results = @{
                    create = [System.Collections.ArrayList]@();
                    match = [System.Collections.ArrayList]@();
    }

    $i = 1;
    foreach($person in $persons)
    {
        Write-Verbose -Verbose "$($i):$($persons.count)";
        $result = $null
        $match = $null
        
        foreach($r in $adUsers)
        {
            if($r.EmployeeID.Replace(' ','') -eq $person."$($config.sourceDataIDField)")
            {
                $result = [PSCustomObject]@{ id = $person."$($config.sourceDataIDField)"; userId = $r.DistinguishedName; person = $person; User = $r; }
                [void]$results.match.Add($result);
                $match = $true;
            }
        }
               
        if($match -ne $true) { [void]$results.create.Add($person) }
        $i++;
        
    }

#Duplicate Correlations
    $duplicates = [System.Collections.ArrayList]@();
    $duplicatesbyUserId = ($results.match | Group-Object -Property userId) | Where-Object { $_.Count -gt 1 }
    if($duplicatesbyUserId -is [System.Array]) { [void]$duplicates.AddRange($duplicatesbyUserId) } else { [void]$duplicates.Add($duplicatesbyUserId) };
    $duplicatesbyId = ($results.match | Group-Object -Property Id) | Where-Object { $_.Count -gt 1 }
    if($duplicatesbyId -is [System.Array]) { [void]$duplicates.AddRange($duplicatesbyId) } else { [void]$duplicates.Add($duplicatesbyId) };

#Results
    Write-Verbose -Verbose "$($results.create.count) Create(s)"
    Write-Verbose -Verbose "$($results.match.count) Correlation(s)"
    Write-Verbose -Verbose "$($duplicates.count) Duplicate Correlation(s)"

    $results.create | Out-GridView
    if($duplicates.count -gt 0) { $duplicates | Out-GridView } 