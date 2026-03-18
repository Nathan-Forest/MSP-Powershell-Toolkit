<#
.SYNOPSIS
    Detect Users with Multiple License Group Memberships
.DESCRIPTION
    Finds users who are members of 2+ license assignment groups, which can cause duplicate licenses
    This helps identify licensing conflicts and unnecessary license consumption
.NOTES
    Author: Nathan Forest 
#>

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All", "GroupMember.Read.All"

# Define your license groups
$licenseGroups = Import-Csv "./groupstocheck.csv" | Select-Object -ExpandProperty GroupName

Write-Host "`nLicense Groups to Check: $($licenseGroups.Count)" -ForegroundColor Yellow
Write-Host "Fetching group memberships...`n" -ForegroundColor Cyan

# Key = UserPrincipalName, Value = Array of group names
$userGroupMemberships = @{}

# Loop through each license group
foreach ($groupName in $licenseGroups) {
    Write-Host "Checking group: $groupName" -ForegroundColor Cyan
    
    try {
        $group = Get-MgGroup -Filter "displayName eq '$groupName'" -ErrorAction Stop
        
        if ($group) {
            $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction Stop
            
            Write-Host " Found $($members.Count) members" -ForegroundColor Yellow
            
            # For each member, add this group to their list
            foreach ($member in $members) {
                $user = Get-MgUser -UserId $member.Id -Property DisplayName, UserPrincipalName -ErrorAction SilentlyContinue
                
                if ($user) {
                    $upn = $user.UserPrincipalName
                    
                    if (-not $userGroupMemberships.ContainsKey($upn)) {
                        $userGroupMemberships[$upn] = @{
                            DisplayName = $user.DisplayName
                            Groups      = @()
                        }
                    }
                    
                    $userGroupMemberships[$upn].Groups += $groupName
                }
            }
        }
        else {
            Write-Host " Group not found!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " Error: $_" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

# Filter to only users in 2+ groups
$usersWithMultipleGroups = @()

foreach ($upn in $userGroupMemberships.Keys) {
    $groupCount = $userGroupMemberships[$upn].Groups.Count
    
    if ($groupCount -ge 2) {
        $usersWithMultipleGroups += [PSCustomObject]@{
            DisplayName       = $userGroupMemberships[$upn].DisplayName
            UserPrincipalName = $upn
            GroupCount        = $groupCount
            Groups            = ($userGroupMemberships[$upn].Groups -join "; ")
            Issue             = "User has $groupCount license groups - may have duplicate licenses"
        }
    }
}

# Display results
if ($usersWithMultipleGroups.Count -gt 0) {
    Write-Host "FOUND $($usersWithMultipleGroups.Count) USERS IN MULTIPLE LICENSE GROUPS`n" -ForegroundColor Red
    
    $usersWithMultipleGroups = $usersWithMultipleGroups | Sort-Object GroupCount -Descending
    
    # Display summary
    Write-Host "Summary by Group Count:" -ForegroundColor Cyan
    $usersWithMultipleGroups | Group-Object GroupCount | 
    Select-Object @{Name = "Groups"; Expression = { $_.Name } }, Count | 
    Format-Table -AutoSize
    
    # Display detailed results
    Write-Host "`nDetailed Results:" -ForegroundColor Cyan
    $usersWithMultipleGroups | Format-Table DisplayName, UserPrincipalName, GroupCount, Groups -AutoSize -Wrap
    
    # Export to CSV
    $exportPath = ".\DuplicateLicenseGroups_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    if (-not (Test-Path ".\")) {
        New-Item -Path ".\" -ItemType Directory -Force | Out-Null
    }
    
    $usersWithMultipleGroups | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host "`n Report exported to: $exportPath" -ForegroundColor Green
    
    # Calculate potential license savings
    $totalExtraGroups = ($usersWithMultipleGroups | Measure-Object -Property GroupCount -Sum).Sum - $usersWithMultipleGroups.Count
    Write-Host "`n Potential License Optimization:" -ForegroundColor Yellow
    Write-Host " Users should be in 1 group each" -ForegroundColor Yellow
    Write-Host " Extra group memberships to remove: $totalExtraGroups" -ForegroundColor Yellow
    
    # GridView for interactive exploration
    $usersWithMultipleGroups | Out-GridView -Title "Users in Multiple License Groups - SVDPQLD"
    
}
else {
    Write-Host "No users found in multiple license groups - licensing is clean!" -ForegroundColor Green
}

Disconnect-MgGraph
Write-Host "`nScript complete!" -ForegroundColor Cyan
