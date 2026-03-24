<#
.SYNOPSIS
    Analyze Microsoft 365 license assignments (direct vs group-based) with comprehensive user details

.DESCRIPTION
    Interactive script that analyzes license assignments and reports:
    - Direct assignments vs Group-based assignments
    - Which group assigned the license (if applicable)
    - User details: Name, Email, JobTitle, Department, Office, Account Status
    - Last sign-in date
    - Friendly license names (not SKU IDs)

.PARAMETER ExportPath
    Path to export CSV reports (default: .\Report)

.EXAMPLE
    .\Get-LicenseAssignmentReport.ps1

.EXAMPLE
    .\Get-LicenseAssignmentReport.ps1 -ExportPath "C:\Reports"

.NOTES
    Author: Nathan Forest
    Created: 2026-03-20
    Requires: Microsoft.Graph.Users, Microsoft.Graph.Groups modules
    Permissions: User.Read.All, Group.Read.All, AuditLog.Read.All (for last sign-in)
    
    Features:
    - Interactive menu (specific license, all licenses, or CSV list)
    - SKU ID to friendly name mapping
    - Direct vs Group assignment detection
    - Comprehensive user details
    - Last sign-in tracking
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\Report"
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
        "SPE_F1" = "Microsoft 365 F3"
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

        #Copoilot
        "Microsoft_365_Copilot" = "Copilot for Microsoft 365"
        
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
        "MCOEV" = "Microsoft Teams Phone Standard"
        "Microsoft_Teams_Rooms_Basic" = "Microsoft Teams Rooms Basic"
        "TEAMS_PHONE_STANDARD_FLW_NEW" = "Microsoft Teams Phone Standard for Frontline Workers"
        "MCOCAP" = "Microsoft Teams Shared Devices"
        
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
        "SPE_F5_SECCOMP" = "Microsoft 365 F5 Security + Compliance Add-on"

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
        "MDATP_XPLAT" = "Microsoft Defender for Endpoint"
        
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

function Show-Menu {
    Clear-Host
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "License Assignment Analyzer" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Host "Select analysis mode:`n" -ForegroundColor White
    Write-Host "  1. Analyze a specific license" -ForegroundColor White
    Write-Host "  2. Analyze all licenses" -ForegroundColor White
    Write-Host "  3. Analyze licenses from CSV file" -ForegroundColor White
    Write-Host "  Q. Quit`n" -ForegroundColor White
    
    $selection = Read-Host "Enter your choice (1-3 or Q)"
    return $selection
}

function Get-AvailableLicenses {
    param($SubscribedSkus)
    
    Write-Host "`nAvailable Licenses in Tenant:" -ForegroundColor Yellow
    Write-Host "==============================`n" -ForegroundColor Yellow
    
    $index = 1
    $licenseList = @()
    
    foreach ($sku in $SubscribedSkus) {
        $friendlyName = Get-FriendlyLicenseName -SkuId $sku.SkuId -SkuPartNumber $sku.SkuPartNumber
        $consumed = $sku.ConsumedUnits
        $total = $sku.PrepaidUnits.Enabled
        
        Write-Host "$index. $friendlyName" -ForegroundColor White
        Write-Host "   SKU: $($sku.SkuPartNumber)" -ForegroundColor Gray
        Write-Host "   Assigned: $consumed / $total`n" -ForegroundColor Gray
        
        $licenseList += [PSCustomObject]@{
            Index = $index
            SkuId = $sku.SkuId
            SkuPartNumber = $sku.SkuPartNumber
            FriendlyName = $friendlyName
        }
        
        $index++
    }
    
    return $licenseList
}

function Get-LicenseAssignmentSource {
    param(
        [string]$UserId,
        [string]$SkuId
    )
    
    try {
        # Get user's license assignment states
        $user = Get-MgUser -UserId $UserId -Property "Id,LicenseAssignmentStates" -ErrorAction Stop
        
        if (-not $user.LicenseAssignmentStates) {
            return @{
                AssignmentType = "Unknown"
                GroupName = ""
                GroupId = ""
            }
        }
        
        # Get all assignment states for this specific SKU
        $assignmentStates = $user.LicenseAssignmentStates | Where-Object { $_.SkuId -eq $SkuId }
        
        if (-not $assignmentStates) {
            return @{
                AssignmentType = "Not Assigned"
                GroupName = ""
                GroupId = ""
            }
        }
        
        # Separate direct and group assignments
        $directAssignments = $assignmentStates | Where-Object { -not $_.AssignedByGroup }
        $groupAssignments = $assignmentStates | Where-Object { $_.AssignedByGroup }
        
        # If ONLY group assignments
        if ($groupAssignments -and -not $directAssignments) {
            # Get all group names (filter out nulls/empties)
            $groupNames = @()
            $groupIds = @()
            
            foreach ($assignment in $groupAssignments) {
                if (-not [string]::IsNullOrEmpty($assignment.AssignedByGroup)) {
                    try {
                        $group = Get-MgGroup -GroupId $assignment.AssignedByGroup -ErrorAction Stop
                        $groupNames += $group.DisplayName
                        $groupIds += $assignment.AssignedByGroup
                    } catch {
                        # Group might be deleted or inaccessible
                        $groupNames += "[Deleted or inaccessible group]"
                        $groupIds += $assignment.AssignedByGroup
                    }
                }
            }
            
            return @{
                AssignmentType = "Group"
                GroupName = ($groupNames -join "; ")
                GroupId = ($groupIds -join "; ")
            }
        }
        
        # If ONLY direct assignments
        if ($directAssignments -and -not $groupAssignments) {
            return @{
                AssignmentType = "Direct"
                GroupName = ""
                GroupId = ""
            }
        }
        
        # If BOTH direct and group assignments (duplicate license scenario)
        if ($directAssignments -and $groupAssignments) {
            # This is actually a duplicate - same license from both sources
            $groupNames = @()
            $groupIds = @()
            
            foreach ($assignment in $groupAssignments) {
                if (-not [string]::IsNullOrEmpty($assignment.AssignedByGroup)) {
                    try {
                        $group = Get-MgGroup -GroupId $assignment.AssignedByGroup -ErrorAction Stop
                        $groupNames += $group.DisplayName
                        $groupIds += $assignment.AssignedByGroup
                    } catch {
                        $groupNames += "[Deleted or inaccessible group]"
                        $groupIds += $assignment.AssignedByGroup
                    }
                }
            }
            
            return @{
                AssignmentType = "Both (Direct + Group)"
                GroupName = ($groupNames -join "; ")
                GroupId = ($groupIds -join "; ")
            }
        }
        
        # Fallback
        return @{
            AssignmentType = "Unknown"
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

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "License Assignment Analyzer" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Ensure export path exists
if (-not (Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Write-Host "Required permissions: User.Read.All, Group.Read.All, AuditLog.Read.All`n" -ForegroundColor Gray

try {
    Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "AuditLog.Read.All", "Organization.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host "Connected successfully`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Microsoft Graph" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get all subscribed SKUs
Write-Host "Retrieving tenant licenses..." -ForegroundColor Yellow
try {
    $subscribedSkus = Get-MgSubscribedSku -All -ErrorAction Stop
    Write-Host "Found $($subscribedSkus.Count) license types in tenant`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to retrieve licenses" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Show menu and get user choice
$choice = Show-Menu

$skusToAnalyze = @()
$analysisMode = ""

switch ($choice.ToUpper()) {
    "1" {
        # Specific license
        $analysisMode = "Specific License"
        $licenseList = Get-AvailableLicenses -SubscribedSkus $subscribedSkus
        
        $selection = Read-Host "`nEnter license number to analyze (1-$($licenseList.Count))"
        
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $licenseList.Count) {
            $selectedLicense = $licenseList | Where-Object { $_.Index -eq [int]$selection }
            $skusToAnalyze += $selectedLicense
            Write-Host "`nAnalyzing: $($selectedLicense.FriendlyName)" -ForegroundColor Green
        } else {
            Write-Host "`nInvalid selection" -ForegroundColor Red
            Disconnect-MgGraph | Out-Null
            exit 1
        }
    }
    "2" {
        # All licenses
        $analysisMode = "All Licenses"
        Write-Host "`nAnalyzing all licenses in tenant" -ForegroundColor Green
        
        foreach ($sku in $subscribedSkus) {
            $skusToAnalyze += [PSCustomObject]@{
                SkuId = $sku.SkuId
                SkuPartNumber = $sku.SkuPartNumber
                FriendlyName = Get-FriendlyLicenseName -SkuId $sku.SkuId -SkuPartNumber $sku.SkuPartNumber
            }
        }
    }
    "3" {
        # CSV file
        $analysisMode = "CSV License List"
        $csvPath = Read-Host "`nEnter path to CSV file containing license SKU IDs or names"
        
        if (-not (Test-Path $csvPath)) {
            Write-Host "`nCSV file not found: $csvPath" -ForegroundColor Red
            Disconnect-MgGraph | Out-Null
            exit 1
        }
        
        try {
            $csvData = Import-Csv -Path $csvPath -ErrorAction Stop
            
            # Auto-detect column (SkuPartNumber, SkuId, LicenseName, etc.)
            $columns = $csvData[0].PSObject.Properties.Name
            $skuColumn = $columns | Where-Object { $_ -match 'sku|license' } | Select-Object -First 1
            
            if (-not $skuColumn) {
                $skuColumn = $columns[0]
            }
            
            Write-Host "Using column: $skuColumn" -ForegroundColor Green
            
            foreach ($row in $csvData) {
                $skuValue = $row.$skuColumn
                
                # Try to find matching SKU
                $matchedSku = $subscribedSkus | Where-Object { 
                    $_.SkuId -eq $skuValue -or 
                    $_.SkuPartNumber -eq $skuValue -or
                    (Get-FriendlyLicenseName -SkuId $_.SkuId -SkuPartNumber $_.SkuPartNumber) -like "*$skuValue*"
                }
                
                if ($matchedSku) {
                    $skusToAnalyze += [PSCustomObject]@{
                        SkuId = $matchedSku.SkuId
                        SkuPartNumber = $matchedSku.SkuPartNumber
                        FriendlyName = Get-FriendlyLicenseName -SkuId $matchedSku.SkuId -SkuPartNumber $matchedSku.SkuPartNumber
                    }
                } else {
                    Write-Host "Could not find SKU: $skuValue" -ForegroundColor Yellow
                }
            }
            
            Write-Host "`nFound $($skusToAnalyze.Count) matching licenses from CSV" -ForegroundColor Green
            
        } catch {
            Write-Host "`nError reading CSV file" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Disconnect-MgGraph | Out-Null
            exit 1
        }
    }
    "Q" {
        Write-Host "`nExiting..." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        exit 0
    }
    default {
        Write-Host "`nInvalid choice" -ForegroundColor Red
        Disconnect-MgGraph | Out-Null
        exit 1
    }
}

if ($skusToAnalyze.Count -eq 0) {
    Write-Host "`nNo licenses to analyze" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Get all users with licenses
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Analyzing License Assignments" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Retrieving licensed users..." -ForegroundColor Yellow
$allUsers = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,JobTitle,Department,OfficeLocation,AccountEnabled,AssignedLicenses,LicenseAssignmentStates,SignInActivity" -Filter "assignedLicenses/`$count ne 0" -ConsistencyLevel eventual -CountVariable licensedUserCount

Write-Host "Found $licensedUserCount licensed users`n" -ForegroundColor Green

# Initialize results collection
$results = [System.Collections.Generic.List[object]]::new()
$processedUsers = 0

# Process each user
foreach ($user in $allUsers) {
    $processedUsers++
    Write-Progress -Activity "Analyzing License Assignments" -Status "Processing $($user.DisplayName)" -PercentComplete (($processedUsers / $licensedUserCount) * 100)
    
    # Check if user has any of the licenses we're analyzing
    foreach ($skuToCheck in $skusToAnalyze) {
        $hasLicense = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $skuToCheck.SkuId }
        
        if ($hasLicense) {
            # Get assignment source
            $assignmentInfo = Get-LicenseAssignmentSource -UserId $user.Id -SkuId $skuToCheck.SkuId
            
            # Get last sign-in
            $lastSignIn = if ($user.SignInActivity.LastSignInDateTime) {
                $user.SignInActivity.LastSignInDateTime
            } else {
                "Never / Not Available"
            }
            
            # Add to results
            $results.Add([PSCustomObject]@{
                UserName = $user.DisplayName
                Email = $user.UserPrincipalName
                JobTitle = $user.JobTitle
                Department = $user.Department
                Office = $user.OfficeLocation
                LicenseName = $skuToCheck.FriendlyName
                LicenseSKU = $skuToCheck.SkuPartNumber
                AssignmentType = $assignmentInfo.AssignmentType
                AssignedByGroup = $assignmentInfo.GroupName
                GroupId = $assignmentInfo.GroupId
                AccountStatus = if ($user.AccountEnabled) { "Enabled" } else { "Disabled" }
                LastSignIn = $lastSignIn
                UserId = $user.Id
            })
        }
    }
    
    # Throttling protection
    if ($processedUsers % 100 -eq 0) {
        Start-Sleep -Milliseconds 500
    }
}

Write-Progress -Activity "Analyzing License Assignments" -Completed

# Generate report
if ($results.Count -eq 0) {
    Write-Host "`nNo users found with the selected license(s)" -ForegroundColor Yellow
    Disconnect-MgGraph | Out-Null
    exit 0
}

# Export to CSV
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportFilename = "License_Assignment_Report_$timestamp.csv"
$reportPath = Join-Path $ExportPath $reportFilename

$results | Export-Csv -Path $reportPath -NoTypeInformation

# Display summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "ANALYSIS COMPLETE" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Analysis Mode: $analysisMode" -ForegroundColor White
Write-Host "Total Users Analyzed: $licensedUserCount" -ForegroundColor White
Write-Host "Users with Selected License(s): $($results.Count)" -ForegroundColor White

Write-Host "`nAssignment Type Breakdown:" -ForegroundColor Yellow
$results | Group-Object AssignmentType | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
}

Write-Host "`nAccount Status:" -ForegroundColor Yellow
$enabledCount = ($results | Where-Object { $_.AccountStatus -eq "Enabled" }).Count
$disabledCount = ($results | Where-Object { $_.AccountStatus -eq "Disabled" }).Count
Write-Host "  Enabled: $enabledCount" -ForegroundColor Green
Write-Host "  Disabled: $disabledCount" -ForegroundColor $(if ($disabledCount -gt 0) { "Yellow" } else { "White" })

if ($analysisMode -eq "All Licenses") {
    Write-Host "`nLicenses Found:" -ForegroundColor Yellow
    $results | Group-Object LicenseName | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
    }
    if (($results | Group-Object LicenseName).Count -gt 10) {
        Write-Host "  ... and $(($results | Group-Object LicenseName).Count - 10) more" -ForegroundColor Gray
    }
}

# Group-based assignment details
$groupAssignments = $results | Where-Object { $_.AssignmentType -eq "Group" }
if ($groupAssignments.Count -gt 0) {
    Write-Host "`nTop Groups Assigning Licenses:" -ForegroundColor Yellow
    $groupAssignments | Group-Object AssignedByGroup | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) users" -ForegroundColor White
    }
}

Write-Host "`nReport exported to: $reportPath" -ForegroundColor Green

# Display in GridView
$results | Out-GridView -Title "License Assignment Report - $($results.Count) Assignments"

# Disconnect
Disconnect-MgGraph | Out-Null
Write-Host "`nDisconnected from Microsoft Graph`n" -ForegroundColor Cyan

#endregion
