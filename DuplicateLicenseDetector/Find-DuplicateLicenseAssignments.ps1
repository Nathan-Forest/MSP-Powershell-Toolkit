<#
.SYNOPSIS
    Detect duplicate Microsoft 365 license assignments (direct + group) for cost optimization

.DESCRIPTION
    Finds users who have the same license assigned BOTH directly AND via group membership.
    This represents waste - one assignment should be removed.
    
    Reports:
    - Which licenses are duplicated
    - Which groups assigned them
    - User account status (enabled/disabled)
    - Last sign-in date
    - Cost impact and savings potential

.PARAMETER ExportPath
    Path to export CSV reports (default: .\Report)

.PARAMETER IncludeDisabledAccounts
    Include disabled accounts in the report (default: enabled accounts only)

.PARAMETER ShowCostEstimate
    Calculate estimated monthly/annual waste (requires manual price configuration)

.EXAMPLE
    .\Find-DuplicateLicenseAssignments.ps1

.EXAMPLE
    .\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts

.EXAMPLE
    .\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate -ExportPath "C:\Reports"

.NOTES
    Author: Nathan Forest
    Created: 2026-03-20
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Groups modules
    Permissions: User.Read.All, Group.Read.All, AuditLog.Read.All (for last sign-in)
    
    Business Impact: Typical savings of 5-15% of total license costs
    Runtime: ~5 minutes for 1000 users (much faster than comprehensive analysis)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\Report",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeDisabledAccounts,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowCostEstimate
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups

#region Helper Functions

function Get-FriendlyLicenseName {
    param([string]$SkuId, [string]$SkuPartNumber)
    
    # Comprehensive SKU ID to Friendly Name mapping
    $licenseMap = @{
        # Microsoft 365 Plans
        "SPE_E3" = "Microsoft 365 E3"
        "SPE_E5" = "Microsoft 365 E5"
        "SPE_F1" = "Microsoft 365 F1"
        "SPE_F3" = "Microsoft 365 F3"
        "Microsoft_365_E3" = "Microsoft 365 E3"
        "Microsoft_365_E5" = "Microsoft 365 E5"
        
        # Office 365 Plans
        "STANDARDPACK" = "Office 365 E1"
        "STANDARDWOFFPACK" = "Office 365 E2"
        "ENTERPRISEPACK" = "Office 365 E3"
        "ENTERPRISEWITHSCAL" = "Office 365 E4"
        "ENTERPRISEPREMIUM" = "Office 365 E5"
        "ENTERPRISEPREMIUM_NOPSTNCONF" = "Office 365 E5 (without Audio Conferencing)"
        "DESKLESSPACK" = "Office 365 F3"
        "OFFICESUBSCRIPTION" = "Microsoft 365 Apps for Enterprise"
        
        # Business Plans
        "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "O365_BUSINESS_PREMIUM" = "Microsoft 365 Business Standard"
        "SMB_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "SMB_BUSINESS_PREMIUM" = "Microsoft 365 Business Premium"
        "SPB" = "Microsoft 365 Business Premium"
        
        # Exchange Plans
        "EXCHANGESTANDARD" = "Exchange Online Plan 1"
        "EXCHANGEENTERPRISE" = "Exchange Online Plan 2"
        "EXCHANGEARCHIVE_ADDON" = "Exchange Online Archiving"
        "EXCHANGEDESKLESS" = "Exchange Online Kiosk"
        
        # SharePoint Plans
        "SHAREPOINTSTANDARD" = "SharePoint Online Plan 1"
        "SHAREPOINTENTERPRISE" = "SharePoint Online Plan 2"
        
        # Teams & Communication
        "MCOSTANDARD" = "Skype for Business Online Plan 2"
        "MCOIMP" = "Skype for Business Online Plan 1"
        "TEAMS_EXPLORATORY" = "Microsoft Teams Exploratory"
        "TEAMS1" = "Microsoft Teams"
        "MCOMEETADV" = "Audio Conferencing"
        "PHONESYSTEM_VIRTUALUSER" = "Phone System - Virtual User"
        
        # Project & Visio
        "PROJECTPREMIUM" = "Project Plan 5"
        "PROJECTPROFESSIONAL" = "Project Plan 3"
        "PROJECTESSENTIALS" = "Project Plan 1"
        "VISIOCLIENT" = "Visio Plan 2"
        "VISIOONLINE_PLAN1" = "Visio Plan 1"
        
        # Security & Compliance
        "EMS" = "Enterprise Mobility + Security E3"
        "EMSPREMIUM" = "Enterprise Mobility + Security E5"
        "AAD_PREMIUM" = "Azure Active Directory Premium P1"
        "AAD_PREMIUM_P2" = "Azure Active Directory Premium P2"
        "THREAT_INTELLIGENCE" = "Microsoft Defender for Office 365 Plan 2"
        "INFORMATION_PROTECTION_COMPLIANCE" = "Microsoft 365 E5 Compliance"
        "M365_SECURITY_COMPLIANCE_FOR_FLW" = "Microsoft 365 F5 Security + Compliance Add-on"
        
        # Power Platform
        "POWER_BI_PRO" = "Power BI Pro"
        "POWER_BI_STANDARD" = "Power BI (free)"
        "POWERAPPS_PER_USER" = "Power Apps per user"
        "FLOW_FREE" = "Power Automate Free"
        
        # Dynamics 365
        "DYN365_ENTERPRISE_SALES" = "Dynamics 365 Sales"
        "DYN365_ENTERPRISE_CUSTOMER_SERVICE" = "Dynamics 365 Customer Service"
        
        # Defender
        "MDATP_Server" = "Microsoft Defender for Endpoint Server"
        "WIN_DEF_ATP" = "Microsoft Defender for Endpoint"
        
        # Intune
        "INTUNE_A" = "Microsoft Intune"
        "INTUNE_A_VL" = "Microsoft Intune (Volume License)"
        
        # Education
        "STANDARDPACK_STUDENT" = "Office 365 A1 for students"
        "STANDARDPACK_FACULTY" = "Office 365 A1 for faculty"
        "ENTERPRISEPACK_STUDENT" = "Office 365 A3 for students"
        "ENTERPRISEPACK_FACULTY" = "Office 365 A3 for faculty"
        
        # Frontline Worker
        "ENTERPRISEPACK_F1" = "Microsoft 365 F1"
        "M365_F1_COMM" = "Microsoft 365 F1"
        
        # Developer
        "DEVELOPERPACK" = "Microsoft 365 E3 Developer"
        "DEVELOPERPACK_E5" = "Microsoft 365 E5 Developer"
    }
    
    # Try to map by SkuPartNumber first
    if ($licenseMap.ContainsKey($SkuPartNumber)) {
        return $licenseMap[$SkuPartNumber]
    }
    
    # If not found, return the SkuPartNumber (better than GUID)
    return $SkuPartNumber
}

function Get-LicenseCost {
    param([string]$SkuPartNumber)
    
    # Approximate monthly costs in USD (update with your actual pricing)
    # These are Microsoft list prices - adjust for your EA/CSP discounts
    $pricingMap = @{
        # Microsoft 365
        "SPE_E3" = 36.00
        "SPE_E5" = 57.00
        "SPE_F1" = 10.00
        "SPE_F3" = 12.00
        
        # Office 365
        "STANDARDPACK" = 8.00
        "ENTERPRISEPACK" = 20.00
        "ENTERPRISEPREMIUM" = 35.00
        "DESKLESSPACK" = 10.00
        
        # Business
        "O365_BUSINESS_ESSENTIALS" = 6.00
        "O365_BUSINESS_PREMIUM" = 12.50
        "SMB_BUSINESS_PREMIUM" = 22.00
        
        # Exchange
        "EXCHANGESTANDARD" = 4.00
        "EXCHANGEENTERPRISE" = 8.00
        
        # Project & Visio
        "PROJECTPROFESSIONAL" = 30.00
        "PROJECTPREMIUM" = 55.00
        "VISIOCLIENT" = 15.00
        
        # Power Platform
        "POWER_BI_PRO" = 9.99
        "POWERAPPS_PER_USER" = 20.00
        
        # Security
        "EMS" = 10.60
        "EMSPREMIUM" = 16.40
        "AAD_PREMIUM" = 6.00
        "AAD_PREMIUM_P2" = 9.00
    }
    
    if ($pricingMap.ContainsKey($SkuPartNumber)) {
        return $pricingMap[$SkuPartNumber]
    }
    
    # Default estimate if not in map
    return 15.00
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Duplicate License Assignment Detector" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Ensure export path exists
if (-not (Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Write-Host "Required permissions: User.Read.All, Group.Read.All, AuditLog.Read.All`n" -ForegroundColor Gray

try {
    Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "AuditLog.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host "Connected successfully`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Microsoft Graph" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get all licensed users
Write-Host "Retrieving licensed users..." -ForegroundColor Yellow
Write-Host "Note: Focusing on users with potential duplicates for faster analysis`n" -ForegroundColor Gray

try {
    # Get users with licenses
    $filter = "assignedLicenses/`$count ne 0"
    if (-not $IncludeDisabledAccounts) {
        $filter += " and accountEnabled eq true"
        Write-Host "Filtering to enabled accounts only (use -IncludeDisabledAccounts to include disabled)" -ForegroundColor Gray
    }
    
    $allUsers = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,JobTitle,Department,OfficeLocation,AccountEnabled,AssignedLicenses,LicenseAssignmentStates,SignInActivity" -Filter $filter -ConsistencyLevel eventual -CountVariable userCount
    
    Write-Host "Found $userCount licensed users`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to retrieve users" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Initialize results collection
$duplicates = [System.Collections.Generic.List[object]]::new()
$processedUsers = 0
$usersWithDuplicates = 0

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Analyzing License Assignments" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Process each user
foreach ($user in $allUsers) {
    $processedUsers++
    Write-Progress -Activity "Scanning for Duplicate License Assignments" -Status "Processing $($user.DisplayName)" -PercentComplete (($processedUsers / $userCount) * 100)
    
    # Check if user has LicenseAssignmentStates (indicates how licenses were assigned)
    if (-not $user.LicenseAssignmentStates -or $user.LicenseAssignmentStates.Count -eq 0) {
        continue
    }
    
    # Group assignment states by SkuId to find duplicates
    $licenseGroups = $user.LicenseAssignmentStates | Group-Object SkuId
    
    # Check each license
    foreach ($licenseGroup in $licenseGroups) {
        if ($licenseGroup.Count -gt 1) {
            # This user has multiple assignments of the same SKU
            # Check if there's both a direct and group assignment
            
            $directAssignment = $licenseGroup.Group | Where-Object { -not $_.AssignedByGroup }
            $groupAssignments = $licenseGroup.Group | Where-Object { $_.AssignedByGroup }
            
            if ($directAssignment -and $groupAssignments) {
                # DUPLICATE FOUND: Same license assigned both directly AND via group(s)
                $usersWithDuplicates++
                
                $skuId = $licenseGroup.Name
                
                # Get SKU details for friendly name
                $sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuId -eq $skuId } | Select-Object -First 1
                $friendlyName = if ($sku) {
                    Get-FriendlyLicenseName -SkuId $sku.SkuId -SkuPartNumber $sku.SkuPartNumber
                } else {
                    $skuId
                }
                
                $skuPartNumber = if ($sku) { $sku.SkuPartNumber } else { "Unknown" }
                
                # Get group names for all group assignments
                $groupNames = @()
                $groupIds = @()
                
                foreach ($groupAssignment in $groupAssignments) {
                    try {
                        $group = Get-MgGroup -GroupId $groupAssignment.AssignedByGroup -ErrorAction Stop
                        $groupNames += $group.DisplayName
                        $groupIds += $groupAssignment.AssignedByGroup
                    } catch {
                        $groupNames += "[Unable to retrieve group name]"
                        $groupIds += $groupAssignment.AssignedByGroup
                    }
                }
                
                # Get last sign-in
                $lastSignIn = if ($user.SignInActivity.LastSignInDateTime) {
                    $user.SignInActivity.LastSignInDateTime
                } else {
                    "Never / Not Available"
                }
                
                # Calculate cost if requested
                $monthlyCost = if ($ShowCostEstimate) {
                    Get-LicenseCost -SkuPartNumber $skuPartNumber
                } else {
                    0
                }
                
                $annualCost = $monthlyCost * 12
                
                # Add to results
                $duplicates.Add([PSCustomObject]@{
                    UserName = $user.DisplayName
                    Email = $user.UserPrincipalName
                    JobTitle = $user.JobTitle
                    Department = $user.Department
                    Office = $user.OfficeLocation
                    LicenseName = $friendlyName
                    LicenseSKU = $skuPartNumber
                    DirectlyAssigned = "Yes"
                    GroupAssigned = "Yes"
                    AssignedByGroups = ($groupNames -join "; ")
                    GroupIds = ($groupIds -join "; ")
                    TotalAssignments = $licenseGroup.Count
                    AccountStatus = if ($user.AccountEnabled) { "Enabled" } else { "Disabled" }
                    LastSignIn = $lastSignIn
                    MonthlyCostPerLicense = $monthlyCost
                    AnnualCostPerLicense = $annualCost
                    RecommendedAction = "Remove direct assignment (keep group-based)"
                    UserId = $user.Id
                })
            }
        }
    }
    
    # Throttling protection
    if ($processedUsers % 50 -eq 0) {
        Start-Sleep -Milliseconds 250
    }
}

Write-Progress -Activity "Scanning for Duplicate License Assignments" -Completed

# Generate report
if ($duplicates.Count -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "NO DUPLICATES FOUND" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    
    Write-Host "Great news! No duplicate license assignments detected." -ForegroundColor Green
    Write-Host "All licenses are assigned either directly OR via group, but not both.`n" -ForegroundColor Green
    
    # Create compliance report
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportPath = Join-Path $ExportPath "Duplicate_License_Report_$timestamp.csv"
    
    [PSCustomObject]@{
        AuditDate = Get-Date
        UsersScanned = $userCount
        DuplicatesFound = 0
        Status = "COMPLIANT"
    } | Export-Csv -Path $reportPath -NoTypeInformation
    
    Write-Host "Compliance report exported to: $reportPath" -ForegroundColor Green
    
    Disconnect-MgGraph | Out-Null
    Write-Host "`nDisconnected from Microsoft Graph`n" -ForegroundColor Cyan
    exit 0
}

# Export results
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $ExportPath "Duplicate_License_Report_$timestamp.csv"

$duplicates | Export-Csv -Path $reportPath -NoTypeInformation

# Calculate totals
$totalDuplicateLicenses = $duplicates.Count
$uniqueUsers = ($duplicates | Select-Object -ExpandProperty UserId -Unique).Count
$totalMonthlyCost = if ($ShowCostEstimate) {
    ($duplicates | Measure-Object -Property MonthlyCostPerLicense -Sum).Sum
} else {
    0
}
$totalAnnualCost = $totalMonthlyCost * 12

# Display summary
Write-Host "`n========================================" -ForegroundColor Red
Write-Host "DUPLICATE LICENSE VIOLATIONS FOUND" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Red

Write-Host "Total Users with Duplicates: $uniqueUsers" -ForegroundColor Yellow
Write-Host "Total Duplicate Licenses: $totalDuplicateLicenses" -ForegroundColor Yellow

if ($ShowCostEstimate) {
    Write-Host "`nCost Impact:" -ForegroundColor Yellow
    Write-Host "  Estimated Monthly Waste: `$$($totalMonthlyCost.ToString('N2'))" -ForegroundColor Red
    Write-Host "  Estimated Annual Waste: `$$($totalAnnualCost.ToString('N2'))" -ForegroundColor Red
    Write-Host "  (Based on list prices - adjust for your EA/CSP discounts)" -ForegroundColor Gray
}

Write-Host "`nBy License Type:" -ForegroundColor Yellow
$duplicates | Group-Object LicenseName | Sort-Object Count -Descending | ForEach-Object {
    $cost = if ($ShowCostEstimate) {
        $licenseCost = ($_.Group | Select-Object -First 1).MonthlyCostPerLicense
        " (`$$($licenseCost)/month each)"
    } else {
        ""
    }
    Write-Host "  $($_.Name): $($_.Count) duplicates$cost" -ForegroundColor White
}

Write-Host "`nTop Groups Causing Duplicates:" -ForegroundColor Yellow
# Parse group names (they're joined with "; ")
$allGroupNames = $duplicates | ForEach-Object {
    $_.AssignedByGroups -split "; " | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
$allGroupNames | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) users" -ForegroundColor White
}

Write-Host "`nAccount Status:" -ForegroundColor Yellow
$enabledDuplicates = ($duplicates | Where-Object { $_.AccountStatus -eq "Enabled" }).Count
$disabledDuplicates = ($duplicates | Where-Object { $_.AccountStatus -eq "Disabled" }).Count
Write-Host "  Enabled: $enabledDuplicates" -ForegroundColor $(if ($enabledDuplicates -gt 0) { "Yellow" } else { "White" })
Write-Host "  Disabled: $disabledDuplicates" -ForegroundColor $(if ($disabledDuplicates -gt 0) { "Red" } else { "White" })

if ($disabledDuplicates -gt 0) {
    Write-Host "`nPRIORITY: $disabledDuplicates disabled accounts with duplicate licenses!" -ForegroundColor Red
    Write-Host "Remove ALL licenses from disabled accounts immediately." -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RECOMMENDED ACTIONS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Remove direct assignments (keep group-based licensing)" -ForegroundColor White
Write-Host " - Group-based licensing is automated and easier to manage`n" -ForegroundColor Gray

Write-Host "2. For disabled accounts, remove ALL licenses" -ForegroundColor White
Write-Host " - Reclaim licenses for active users`n" -ForegroundColor Gray

Write-Host "3. Potential savings after cleanup:" -ForegroundColor White
if ($ShowCostEstimate) {
    Write-Host " - Monthly: `$$($totalMonthlyCost.ToString('N2'))" -ForegroundColor Green
    Write-Host " - Annual: `$$($totalAnnualCost.ToString('N2'))" -ForegroundColor Green
} else {
    Write-Host " - Run with -ShowCostEstimate to calculate savings" -ForegroundColor Gray
}

Write-Host "`nDetailed report exported to: $reportPath" -ForegroundColor Green

# Show sample PowerShell commands for remediation
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SAMPLE REMEDIATION COMMANDS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "To remove a direct license assignment:" -ForegroundColor Yellow
Write-Host 'Set-MgUserLicense -UserId "user@domain.com" -RemoveLicenses @("SkuId") -AddLicenses @()' -ForegroundColor Gray

Write-Host "`nTo remove ALL licenses from a disabled user:" -ForegroundColor Yellow
Write-Host '$user = Get-MgUser -UserId "user@domain.com" -Property AssignedLicenses' -ForegroundColor Gray
Write-Host '$skuIds = $user.AssignedLicenses.SkuId' -ForegroundColor Gray
Write-Host 'Set-MgUserLicense -UserId $user.Id -RemoveLicenses $skuIds -AddLicenses @()' -ForegroundColor Gray

Write-Host "`nRefer to the CSV report for specific User IDs and SKU IDs`n" -ForegroundColor White

# Display in GridView
$duplicates | Out-GridView -Title "Duplicate License Assignments - $totalDuplicateLicenses Violations Found"

# Disconnect
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph`n" -ForegroundColor Cyan

#endregion
