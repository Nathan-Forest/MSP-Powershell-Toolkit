<#
.SYNOPSIS
    Audit Teams Voice licensing and phone number assignments

.DESCRIPTION
    Checks all users with "Telstra Calling for Office 365" license and reports:
    - Whether they have a phone number assigned
    - What the phone number is
    - Account status (Enabled/Disabled)
    - License assignment type (Direct or Group-based)
    - Which group assigned the license (if applicable)
    
    Helps identify:
    - Users with license but no phone number (waste)
    - Users with phone number but no license (compliance issue)
    - License assignment discrepancies

.PARAMETER ExportPath
    Path to export CSV report (default: .\Report)

.PARAMETER IncludeDisabledAccounts
    Include disabled accounts in the report

.PARAMETER CheckAllPhoneSystemLicenses
    Check all phone system licenses, not just Telstra Calling

.EXAMPLE
    .\Get-TeamsVoiceLicenseReport.ps1

.EXAMPLE
    .\Get-TeamsVoiceLicenseReport.ps1 -IncludeDisabledAccounts

.EXAMPLE
    .\Get-TeamsVoiceLicenseReport.ps1 -CheckAllPhoneSystemLicenses

.NOTES
    Author: Nathan Forest
    Created: 2026-03-25
    Requires: Microsoft.Graph.Users, MicrosoftTeams modules
    Permissions: User.Read.All, Group.Read.All
    
    Common Phone System SKUs:
    - Telstra Calling for Office 365
    - MCOPSTN1 (Domestic Calling Plan)
    - MCOPSTN2 (International Calling Plan)
    - MCOEV (Phone System)
    - MCOPSTNEAU (Calling Plan for Australia)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\Report",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeDisabledAccounts,
    
    [Parameter(Mandatory = $false)]
    [switch]$CheckAllPhoneSystemLicenses
)

#Requires -Modules Microsoft.Graph.Users, MicrosoftTeams

#region Helper Functions

function Get-FriendlyLicenseName {
    param([string]$SkuPartNumber)
    
    $licenseMap = @{
        # Phone System & Calling Plans
        "MCOEV" = "Phone System"
        "MCOEV_VIRTUALUSER" = "Phone System - Virtual User"
        "MCOPSTN1" = "Domestic Calling Plan"
        "MCOPSTN2" = "International Calling Plan"
        "MCOPSTN5" = "Calling Plan Pay-As-You-Go"
        "MCOPSTNEAU" = "Calling Plan for Australia"
        "MCOPSTNEAU2" = "Telstra Calling for Office 365"
        "TEAMS_PHONE_STANDARD_FLW" = "Teams Phone with Calling Plan (Frontline Worker)"
        "MCOCAP" = "Common Area Phone"
        "PHONESYSTEM_VIRTUALUSER" = "Phone System - Virtual User"
        
        # Teams & Communication
        "MCOSTANDARD" = "Skype for Business Online Plan 2"
        "TEAMS1" = "Microsoft Teams"
        "MCOMEETADV" = "Audio Conferencing"
    }
    
    if ($licenseMap.ContainsKey($SkuPartNumber)) {
        return $licenseMap[$SkuPartNumber]
    }
    
    return $SkuPartNumber
}

function Get-LicenseAssignmentSource {
    param(
        [string]$UserId,
        [string]$SkuId
    )
    
    try {
        $user = Get-MgUser -UserId $UserId -Property "Id,LicenseAssignmentStates" -ErrorAction Stop
        
        if ($user.LicenseAssignmentStates) {
            $assignmentState = $user.LicenseAssignmentStates | Where-Object { $_.SkuId -eq $SkuId }
            
            if ($assignmentState) {
                if ($assignmentState.AssignedByGroup) {
                    try {
                        $group = Get-MgGroup -GroupId $assignmentState.AssignedByGroup -ErrorAction Stop
                        return @{
                            AssignmentType = "Group"
                            GroupName = $group.DisplayName
                            GroupId = $assignmentState.AssignedByGroup
                        }
                    } catch {
                        return @{
                            AssignmentType = "Group"
                            GroupName = "[Unable to retrieve group name]"
                            GroupId = $assignmentState.AssignedByGroup
                        }
                    }
                } else {
                    return @{
                        AssignmentType = "Direct"
                        GroupName = ""
                        GroupId = ""
                    }
                }
            }
        }
        
        return @{
            AssignmentType = "Direct (Assumed)"
            GroupName = ""
            GroupId = ""
        }
        
    } catch {
        Write-Warning "Error checking license assignment for user ${UserId}: $($_.Exception.Message)"
        return @{
            AssignmentType = "Error"
            GroupName = ""
            GroupId = ""
        }
    }
}

function Get-UserPhoneNumber {
    param([string]$UserPrincipalName)
    
    try {
        # Try to get Teams user info
        $teamsUser = Get-CsOnlineUser -Identity $UserPrincipalName -ErrorAction Stop
        
        $phoneNumber = $null
        $numberType = $null
        
        # Check various phone number properties
        if ($teamsUser.LineURI) {
            $phoneNumber = $teamsUser.LineURI -replace 'tel:', ''
            $numberType = "Direct Routing / Operator Connect"
        } elseif ($teamsUser.OnPremLineURI) {
            $phoneNumber = $teamsUser.OnPremLineURI -replace 'tel:', ''
            $numberType = "On-Premises (Hybrid)"
        } elseif ($teamsUser.TelephoneNumber) {
            $phoneNumber = $teamsUser.TelephoneNumber
            $numberType = "Calling Plan"
        }
        
        # Get additional Teams voice config
        $enterpriseVoiceEnabled = $teamsUser.EnterpriseVoiceEnabled
        $voicePolicy = $teamsUser.OnlineVoiceRoutingPolicy
        
        return @{
            PhoneNumber = $phoneNumber
            NumberType = $numberType
            EnterpriseVoiceEnabled = $enterpriseVoiceEnabled
            VoicePolicy = $voicePolicy
            HasPhoneNumber = -not [string]::IsNullOrEmpty($phoneNumber)
        }
    } catch {
        Write-Warning "Could not retrieve phone info for ${UserPrincipalName}: $($_.Exception.Message)"
        return @{
            PhoneNumber = $null
            NumberType = "Error retrieving"
            EnterpriseVoiceEnabled = $false
            VoicePolicy = $null
            HasPhoneNumber = $false
        }
    }
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Teams Voice License & Phone Number Audit" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Ensure export path exists
if (-not (Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
try {
    Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Microsoft Graph" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Connect to Teams (for phone number lookup)
Write-Host "Connecting to Microsoft Teams..." -ForegroundColor Yellow
try {
    Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
    Write-Host "Connected to Microsoft Teams`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Microsoft Teams" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Note: You may need to install the module: Install-Module MicrosoftTeams`n" -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Get all tenant SKUs
Write-Host "Retrieving tenant licenses..." -ForegroundColor Yellow
try {
    $subscribedSkus = Get-MgSubscribedSku -All -ErrorAction Stop
    Write-Host "Found $($subscribedSkus.Count) license types`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to retrieve licenses" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    Disconnect-MicrosoftTeams | Out-Null
    exit 1
}

# Identify phone system SKUs
$phoneSystemSkus = @()

if ($CheckAllPhoneSystemLicenses) {
    Write-Host "Checking all Phone System licenses..." -ForegroundColor Yellow
    $phoneSkuPatterns = @("MCOEV", "MCOPSTN", "TELSTRA", "PHONE", "CALLING")
    
    foreach ($sku in $subscribedSkus) {
        foreach ($pattern in $phoneSkuPatterns) {
            if ($sku.SkuPartNumber -like "*$pattern*") {
                $phoneSystemSkus += $sku
                break
            }
        }
    }
} else {
    Write-Host "Checking for Telstra Calling for Office 365 license..." -ForegroundColor Yellow
    # Look for Telstra Calling specifically
    $telstraSku = $subscribedSkus | Where-Object { 
        $_.SkuPartNumber -like "*TELSTRA*" -or 
        $_.SkuPartNumber -eq "MCOPSTNEAU2" -or
        $_.SkuPartNumber -eq "MCOPSTNEAU"
    }
    
    if ($telstraSku) {
        $phoneSystemSkus += $telstraSku
    } else {
        Write-Host "Telstra Calling license not found in tenant" -ForegroundColor Yellow
        Write-Host "Available phone-related SKUs:" -ForegroundColor Gray
        $subscribedSkus | Where-Object { $_.SkuPartNumber -like "*MCO*" -or $_.SkuPartNumber -like "*PHONE*" } | ForEach-Object {
            Write-Host "  - $($_.SkuPartNumber): $(Get-FriendlyLicenseName -SkuPartNumber $_.SkuPartNumber)" -ForegroundColor Gray
        }
        Write-Host "`nTip: Use -CheckAllPhoneSystemLicenses to check all phone licenses`n" -ForegroundColor Yellow
        
        Disconnect-MgGraph | Out-Null
        Disconnect-MicrosoftTeams | Out-Null
        exit 0
    }
}

Write-Host "Found $($phoneSystemSkus.Count) phone system license(s) to check:`n" -ForegroundColor Green
$phoneSystemSkus | ForEach-Object {
    $friendlyName = Get-FriendlyLicenseName -SkuPartNumber $_.SkuPartNumber
    Write-Host "  - $friendlyName ($($_.SkuPartNumber))" -ForegroundColor White
    Write-Host "    Assigned: $($_.ConsumedUnits) / $($_.PrepaidUnits.Enabled)" -ForegroundColor Gray
}
Write-Host ""

# Build filter
$filter = "assignedLicenses/`$count ne 0"
if (-not $IncludeDisabledAccounts) {
    $filter += " and accountEnabled eq true"
}

# Get all licensed users
Write-Host "Retrieving licensed users..." -ForegroundColor Yellow
$allUsers = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,JobTitle,Department,OfficeLocation,AccountEnabled,AssignedLicenses,LicenseAssignmentStates" -Filter $filter -ConsistencyLevel eventual -CountVariable userCount

Write-Host "Found $userCount licensed users`n" -ForegroundColor Green

# Filter to users with phone system licenses
Write-Host "Filtering to users with phone system licenses..." -ForegroundColor Yellow
$usersWithPhoneLicense = $allUsers | Where-Object {
    $userLicenses = $_.AssignedLicenses.SkuId
    $phoneSkuIds = $phoneSystemSkus.SkuId
    
    foreach ($skuId in $phoneSkuIds) {
        if ($userLicenses -contains $skuId) {
            return $true
        }
    }
    return $false
}

Write-Host "Found $($usersWithPhoneLicense.Count) users with phone system licenses`n" -ForegroundColor Green

if ($usersWithPhoneLicense.Count -eq 0) {
    Write-Host "No users found with the specified phone system license(s)" -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    Disconnect-MicrosoftTeams | Out-Null
    exit 0
}

# Process each user
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Analyzing Phone Number Assignments" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$results = [System.Collections.Generic.List[object]]::new()
$processedCount = 0

foreach ($user in $usersWithPhoneLicense) {
    $processedCount++
    Write-Progress -Activity "Analyzing Phone Number Assignments" -Status "Processing $($user.DisplayName)" -PercentComplete (($processedCount / $usersWithPhoneLicense.Count) * 100)
    
    # Find which phone SKU(s) the user has
    $userPhoneSkus = @()
    foreach ($phoneSku in $phoneSystemSkus) {
        if ($user.AssignedLicenses.SkuId -contains $phoneSku.SkuId) {
            $userPhoneSkus += $phoneSku
        }
    }
    
    # Get phone number info
    $phoneInfo = Get-UserPhoneNumber -UserPrincipalName $user.UserPrincipalName
    
    # Process each phone license the user has
    foreach ($phoneSku in $userPhoneSkus) {
        # Get license assignment source
        $assignmentInfo = Get-LicenseAssignmentSource -UserId $user.Id -SkuId $phoneSku.SkuId
        
        $results.Add([PSCustomObject]@{
            UserName = $user.DisplayName
            Email = $user.UserPrincipalName
            JobTitle = $user.JobTitle
            Department = $user.Department
            Office = $user.OfficeLocation
            LicenseName = Get-FriendlyLicenseName -SkuPartNumber $phoneSku.SkuPartNumber
            LicenseSKU = $phoneSku.SkuPartNumber
            HasPhoneNumber = $phoneInfo.HasPhoneNumber
            PhoneNumber = $phoneInfo.PhoneNumber
            NumberType = $phoneInfo.NumberType
            EnterpriseVoiceEnabled = $phoneInfo.EnterpriseVoiceEnabled
            VoiceRoutingPolicy = $phoneInfo.VoicePolicy
            AssignmentType = $assignmentInfo.AssignmentType
            AssignedByGroup = $assignmentInfo.GroupName
            GroupId = $assignmentInfo.GroupId
            AccountStatus = if ($user.AccountEnabled) { "Enabled" } else { "Disabled" }
            UserId = $user.Id
            Status = if ($phoneInfo.HasPhoneNumber) { "OK - Has Number" } else { "ATTENTION - License but No Number" }
        })
    }
    
    # Throttling protection
    if ($processedCount % 20 -eq 0) {
        Start-Sleep -Milliseconds 500
    }
}

Write-Progress -Activity "Analyzing Phone Number Assignments" -Completed

# Generate report
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $ExportPath "Teams_Voice_License_Report_$timestamp.csv"

$results | Export-Csv -Path $reportPath -NoTypeInformation

# Display summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "AUDIT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Total Users with Phone Licenses: $($results.Count)" -ForegroundColor White

$withNumbers = ($results | Where-Object { $_.HasPhoneNumber -eq $true }).Count
$withoutNumbers = ($results | Where-Object { $_.HasPhoneNumber -eq $false }).Count

Write-Host "`nPhone Number Assignment:" -ForegroundColor Yellow
Write-Host "  With Phone Numbers: $withNumbers" -ForegroundColor Green
Write-Host "  Without Phone Numbers: $withoutNumbers" -ForegroundColor $(if ($withoutNumbers -gt 0) { "Red" } else { "White" })

if ($withoutNumbers -gt 0) {
    Write-Host "`n$withoutNumbers users have phone system licenses but NO phone number assigned!" -ForegroundColor Yellow
    Write-Host "  This represents potential license waste.`n" -ForegroundColor Yellow
}

Write-Host "`nLicense Assignment Type:" -ForegroundColor Yellow
$results | Group-Object AssignmentType | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
}

Write-Host "`nAccount Status:" -ForegroundColor Yellow
$enabledCount = ($results | Where-Object { $_.AccountStatus -eq "Enabled" }).Count
$disabledCount = ($results | Where-Object { $_.AccountStatus -eq "Disabled" }).Count
Write-Host "  Enabled: $enabledCount" -ForegroundColor Green
Write-Host "  Disabled: $disabledCount" -ForegroundColor $(if ($disabledCount -gt 0) { "Yellow" } else { "White" })

if ($CheckAllPhoneSystemLicenses) {
    Write-Host "`nBy License Type:" -ForegroundColor Yellow
    $results | Group-Object LicenseName | Sort-Object Count -Descending | ForEach-Object {
        $withNum = ($_.Group | Where-Object { $_.HasPhoneNumber }).Count
        $total = $_.Count
        Write-Host "  $($_.Name): $total total ($withNum with numbers)" -ForegroundColor White
    }
}

# Group-based assignment details
$groupAssignments = $results | Where-Object { $_.AssignmentType -eq "Group" }
if ($groupAssignments.Count -gt 0) {
    Write-Host "`nTop Groups Assigning Phone Licenses:" -ForegroundColor Yellow
    $groupAssignments | Group-Object AssignedByGroup | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) users" -ForegroundColor White
    }
}

Write-Host "`nReport exported to: $reportPath" -ForegroundColor Green

# Display in GridView
$results | Out-GridView -Title "Teams Voice License Report - $($results.Count) Users"

# Disconnect
Disconnect-MgGraph | Out-Null
Disconnect-MicrosoftTeams | Out-Null
Write-Host "`nDisconnected from Microsoft Graph and Teams`n" -ForegroundColor Cyan

#endregion
