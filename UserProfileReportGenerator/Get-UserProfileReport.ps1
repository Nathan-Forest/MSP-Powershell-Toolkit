<#
.SYNOPSIS
    Generate comprehensive user profile report for offboarding and auditing

.DESCRIPTION
    Creates detailed HTML report covering:
    - Basic profile information
    - Authentication & security status
    - License assignments (direct vs group)
    - Group memberships (all types)
    - Mailbox access permissions
    - Calendar delegates
    - Mail forwarding rules
    - Microsoft Teams membership
    - OneDrive storage usage
    - Registered devices
    - Manager & direct reports
    - Admin roles
    - Application access
    - SharePoint sites owned
    - Sign-in activity summary
    
    Designed for offboarding, security audits, and compliance reviews.

.PARAMETER UserEmail
    Email address of user to profile

.PARAMETER ExportPath
    Path to save HTML report (default: .\Reports)

.PARAMETER OpenReport
    Open HTML report in browser after generation

.EXAMPLE
    .\Get-UserProfileReport.ps1 -UserEmail "john.smith@company.com"

.EXAMPLE
    .\Get-UserProfileReport.ps1 -UserEmail "john.smith@company.com" -OpenReport

.NOTES
    Author: Nathan Forest
    Created: 2026-03-25
    
    Required Modules:
    - Microsoft.Graph.Users
    - Microsoft.Graph.Groups
    - Microsoft.Graph.Identity.SignIns
    - Microsoft.Graph.Sites
    - ExchangeOnlineManagement
    - MicrosoftTeams
    
    Permissions Required:
    - User.Read.All
    - Group.Read.All
    - AuditLog.Read.All
    - Sites.Read.All
    - Exchange Administrator (or equivalent)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UserEmail,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\Reports",
    
    [Parameter(Mandatory = $false)]
    [switch]$OpenReport
)

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Groups, ExchangeOnlineManagement

#region Helper Functions

function Get-FriendlyLicenseName {
    param([string]$SkuPartNumber)
    
    $licenseMap = @{
        "SPE_E3" = "Microsoft 365 E3"
        "SPE_E5" = "Microsoft 365 E5"
        "SPE_F3" = "Microsoft 365 F3"
        "ENTERPRISEPACK" = "Office 365 E3"
        "ENTERPRISEPREMIUM" = "Office 365 E5"
        "SPB" = "Microsoft 365 Business Premium"
        "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
        "POWER_BI_PRO" = "Power BI Pro"
        "POWER_BI_STANDARD" = "Power BI (free)"
        "PROJECTPROFESSIONAL" = "Project Plan 3"
        "VISIOCLIENT" = "Visio Plan 2"
        "MCOEV" = "Phone System"
        "TEAMS1" = "Microsoft Teams"
    }
    
    if ($licenseMap.ContainsKey($SkuPartNumber)) {
        return $licenseMap[$SkuPartNumber]
    }
    return $SkuPartNumber
}

function Get-LicenseMonthlyCost {
    param([string]$SkuPartNumber)
    
    $costMap = @{
        "SPE_E3" = 36.00
        "SPE_E5" = 57.00
        "SPE_F3" = 10.00
        "ENTERPRISEPACK" = 23.00
        "ENTERPRISEPREMIUM" = 38.00
        "SPB" = 22.00
        "O365_BUSINESS_ESSENTIALS" = 6.00
        "POWER_BI_PRO" = 13.00
        "PROJECTPROFESSIONAL" = 55.00
        "VISIOCLIENT" = 15.00
        "MCOEV" = 10.00
    }
    
    if ($costMap.ContainsKey($SkuPartNumber)) {
        return $costMap[$SkuPartNumber]
    }
    return 0
}

function Get-LicenseAssignmentSource {
    param(
        [string]$UserId,
        [string]$SkuId
    )
    
    try {
        $user = Get-MgUser -UserId $UserId -Property "LicenseAssignmentStates" -ErrorAction Stop
        
        if ($user.LicenseAssignmentStates) {
            $assignmentStates = $user.LicenseAssignmentStates | Where-Object { $_.SkuId -eq $SkuId }
            
            if ($assignmentStates) {
                $directAssignments = $assignmentStates | Where-Object { -not $_.AssignedByGroup }
                $groupAssignments = $assignmentStates | Where-Object { $_.AssignedByGroup }
                
                if ($groupAssignments -and -not $directAssignments) {
                    $groupNames = @()
                    foreach ($assignment in $groupAssignments) {
                        if (-not [string]::IsNullOrEmpty($assignment.AssignedByGroup)) {
                            try {
                                $group = Get-MgGroup -GroupId $assignment.AssignedByGroup -ErrorAction Stop
                                $groupNames += $group.DisplayName
                            } catch {
                                $groupNames += "[Deleted group]"
                            }
                        }
                    }
                    return @{
                        Type = "Group"
                        Source = ($groupNames -join ", ")
                    }
                }
                elseif ($directAssignments -and -not $groupAssignments) {
                    return @{
                        Type = "Direct"
                        Source = ""
                    }
                }
                else {
                    $groupNames = @()
                    foreach ($assignment in $groupAssignments) {
                        if (-not [string]::IsNullOrEmpty($assignment.AssignedByGroup)) {
                            try {
                                $group = Get-MgGroup -GroupId $assignment.AssignedByGroup -ErrorAction Stop
                                $groupNames += $group.DisplayName
                            } catch {
                                $groupNames += "[Deleted group]"
                            }
                        }
                    }
                    return @{
                        Type = "Both"
                        Source = ($groupNames -join ", ")
                    }
                }
            }
        }
        
        return @{
            Type = "Direct"
            Source = ""
        }
    } catch {
        return @{
            Type = "Unknown"
            Source = ""
        }
    }
}

function ConvertTo-ReadableSize {
    param([long]$Bytes)
    
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "User Profile Report Generator" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Target User: $UserEmail" -ForegroundColor White
Write-Host "Report will be saved to: $ExportPath`n" -ForegroundColor Gray

# Ensure export path exists
if (-not (Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
}

# Initialize data collection object
$reportData = @{
    GeneratedDate = Get-Date
    UserEmail = $UserEmail
    User = $null
    Licenses = @()
    Groups = @{
        Security = @()
        Distribution = @()
        Microsoft365 = @()
    }
    MailboxAccess = @()
    CalendarDelegates = @()
    ForwardingRules = @{}
    Teams = @()
    Devices = @()
    Manager = $null
    DirectReports = @()
    AdminRoles = @()
    Applications = @()
    SharePointSites = @()
    OneDriveStorage = @{}
    SignInActivity = @{}
    MFAStatus = @{}
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
try {
    Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "AuditLog.Read.All", "Sites.Read.All", "RoleManagement.Read.Directory" -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Microsoft Graph" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Connect to Exchange Online
Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
try {
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    Write-Host "Connected to Exchange Online`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect to Exchange Online" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Connect to Teams
Write-Host "Connecting to Microsoft Teams..." -ForegroundColor Yellow
try {
    Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
    Write-Host "Connected to Microsoft Teams`n" -ForegroundColor Green
} catch {
    Write-Host "Could not connect to Microsoft Teams - Teams data will be skipped" -ForegroundColor Yellow
    $teamsConnected = $false
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Collecting User Profile Data" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

#endregion

#region Basic User Information

Write-Host "[1/14] Retrieving basic user information..." -ForegroundColor Yellow

try {
    $reportData.User = Get-MgUser -UserId $UserEmail -Property "Id,DisplayName,UserPrincipalName,Mail,JobTitle,Department,OfficeLocation,MobilePhone,BusinessPhones,EmployeeId,CreatedDateTime,AccountEnabled,OnPremisesSyncEnabled,AssignedLicenses,LicenseAssignmentStates" -ErrorAction Stop
    Write-Host "Basic information retrieved`n" -ForegroundColor Green
} catch {
    Write-Host "User not found: $UserEmail" -ForegroundColor Red
    Disconnect-MgGraph | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

#endregion

#region Authentication & Security

Write-Host "[2/14] Checking authentication and security status..." -ForegroundColor Yellow

# Last sign-in
try {
    $signInActivity = Get-MgUser -UserId $reportData.User.Id -Property "SignInActivity" -ErrorAction Stop
    $reportData.SignInActivity = @{
        LastSignIn = $signInActivity.SignInActivity.LastSignInDateTime
        LastNonInteractiveSignIn = $signInActivity.SignInActivity.LastNonInteractiveSignInDateTime
    }
} catch {
    $reportData.SignInActivity = @{
        LastSignIn = $null
        LastNonInteractiveSignIn = $null
    }
}

# MFA status
try {
    $authMethods = Get-MgUserAuthenticationMethod -UserId $reportData.User.Id -ErrorAction Stop
    $reportData.MFAStatus = @{
        Methods = @()
        IsEnabled = $authMethods.Count -gt 1  # More than just password
    }
    
    foreach ($method in $authMethods) {
        $methodType = $method.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', ''
        if ($methodType -ne 'passwordAuthenticationMethod') {
            $reportData.MFAStatus.Methods += $methodType
        }
    }
} catch {
    $reportData.MFAStatus = @{
        Methods = @()
        IsEnabled = $false
    }
}

# Password last changed
try {
    $passwordProfile = Get-MgUser -UserId $reportData.User.Id -Property "LastPasswordChangeDateTime" -ErrorAction Stop
    $reportData.LastPasswordChange = $passwordProfile.LastPasswordChangeDateTime
} catch {
    $reportData.LastPasswordChange = $null
}

Write-Host "Authentication status retrieved`n" -ForegroundColor Green

#endregion

#region Licenses

Write-Host "[3/14] Analyzing license assignments..." -ForegroundColor Yellow

try {
    $tenantSkus = Get-MgSubscribedSku -All
    
    foreach ($license in $reportData.User.AssignedLicenses) {
        $sku = $tenantSkus | Where-Object { $_.SkuId -eq $license.SkuId } | Select-Object -First 1
        
        if ($sku) {
            $assignmentInfo = Get-LicenseAssignmentSource -UserId $reportData.User.Id -SkuId $license.SkuId
            
            $reportData.Licenses += [PSCustomObject]@{
                Name = Get-FriendlyLicenseName -SkuPartNumber $sku.SkuPartNumber
                SKU = $sku.SkuPartNumber
                AssignmentType = $assignmentInfo.Type
                AssignedBy = $assignmentInfo.Source
                MonthlyCost = Get-LicenseMonthlyCost -SkuPartNumber $sku.SkuPartNumber
            }
        }
    }
    
    Write-Host "Found $($reportData.Licenses.Count) licenses`n" -ForegroundColor Green
} catch {
    Write-Host "Could not retrieve license information`n" -ForegroundColor Yellow
}

#endregion

#region Group Memberships

Write-Host "[4/14] Retrieving group memberships..." -ForegroundColor Yellow

try {
    $userGroups = Get-MgUserMemberOf -UserId $reportData.User.Id -All
    
    foreach ($group in $userGroups) {
        $groupDetails = Get-MgGroup -GroupId $group.Id -Property "DisplayName,GroupTypes,MailEnabled,SecurityEnabled,Mail"
        
        if ($groupDetails.GroupTypes -contains "Unified") {
            $reportData.Groups.Microsoft365 += $groupDetails
        }
        elseif ($groupDetails.MailEnabled -and -not $groupDetails.SecurityEnabled) {
            $reportData.Groups.Distribution += $groupDetails
        }
        elseif ($groupDetails.SecurityEnabled) {
            $reportData.Groups.Security += $groupDetails
        }
    }
    
    $totalGroups = $reportData.Groups.Security.Count + $reportData.Groups.Distribution.Count + $reportData.Groups.Microsoft365.Count
    Write-Host "Found $totalGroups groups`n" -ForegroundColor Green
} catch {
    Write-Host "Could not retrieve group memberships`n" -ForegroundColor Yellow
}

#endregion

#region Mailbox Access

Write-Host "[5/14] Checking mailbox access permissions..." -ForegroundColor Yellow

# Interactive prompt for mailbox check
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Mailbox Access Check Options" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This section checks which mailboxes the user has access to." -ForegroundColor White
Write-Host "Choose the scope of the check:`n" -ForegroundColor White

Write-Host "  [1] Shared Mailboxes Only (Recommended - Fast)" -ForegroundColor Green
Write-Host "      Checks: Shared mailboxes (support@, info@, etc.)" -ForegroundColor Gray
Write-Host "      Runtime: 2-15 minutes (depending on tenant size)" -ForegroundColor Gray
Write-Host "      Coverage: ~95% of typical offboarding scenarios`n" -ForegroundColor Gray

Write-Host "  [2] All Mailboxes (Comprehensive - Slow)" -ForegroundColor Yellow
Write-Host "      Checks: ALL mailboxes (users, shared, rooms, equipment)" -ForegroundColor Gray
Write-Host "      Runtime: 10 minutes - 2 hours (depending on tenant size)" -ForegroundColor Gray
Write-Host "      Coverage: 100% comprehensive audit`n" -ForegroundColor Gray

Write-Host "  [3] Skip Mailbox Check (Fastest)" -ForegroundColor Gray
Write-Host "      Skips mailbox checking entirely" -ForegroundColor Gray
Write-Host "      Runtime: Instant" -ForegroundColor Gray
Write-Host "      Coverage: None (can run separately later)`n" -ForegroundColor Gray

# Get user choice
do {
    $choice = Read-Host "Enter your choice (1, 2, or 3)"
} while ($choice -notin @('1', '2', '3'))

Write-Host "`n========================================`n" -ForegroundColor Cyan

# Store choice for HTML report
$reportData.MailboxAccessMode = switch ($choice) {
    '1' { 'Shared Mailboxes Only' }
    '2' { 'All Mailboxes (Comprehensive)' }
    '3' { 'Skipped' }
}

# Execute based on choice
if ($choice -eq '3') {
    # SKIP - No mailbox check
    Write-Host "Mailbox access check skipped (user chose to skip)`n" -ForegroundColor Gray
    $reportData.MailboxAccessSkipped = $true
    
} elseif ($choice -eq '1') {
    # SHARED MAILBOXES ONLY
    Write-Host "Checking shared mailboxes only..." -ForegroundColor Yellow
    
    try {
        $sharedMailboxes = Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -Properties DisplayName,PrimarySmtpAddress,RecipientTypeDetails,GrantSendOnBehalfTo -ErrorAction Stop
        
        Write-Host "Found $($sharedMailboxes.Count) shared mailboxes to check" -ForegroundColor White
        
        # Warning for large number of shared mailboxes
        if ($sharedMailboxes.Count -gt 1000) {
            Write-Host "`nWARNING: This tenant has $($sharedMailboxes.Count) shared mailboxes!" -ForegroundColor Yellow
            Write-Host "This is unusually high and may indicate architectural issues." -ForegroundColor Yellow
            Write-Host "Checking all of them may take 30-60 minutes.`n" -ForegroundColor Yellow
        }
        
        $accessCount = 0
        $processedCount = 0
        $startTime = Get-Date
        
        foreach ($mailbox in $sharedMailboxes) {
            $processedCount++
            
            # Progress indicator
            if ($processedCount % 50 -eq 0) {
                $elapsed = (Get-Date) - $startTime
                $rate = $processedCount / $elapsed.TotalSeconds
                $remaining = ($sharedMailboxes.Count - $processedCount) / $rate
                $eta = [TimeSpan]::FromSeconds($remaining)
                
                Write-Host "  Progress: $processedCount / $($sharedMailboxes.Count) | Found: $accessCount | ETA: $($eta.ToString('mm\:ss'))" -ForegroundColor Gray
            }
            
            $permissions = @()
            
            # Check SendOnBehalf (no API call - already in object!)
            if ($mailbox.GrantSendOnBehalfTo -and $mailbox.GrantSendOnBehalfTo -contains $UserEmail) {
                $permissions += "SendOnBehalf"
            }
            
            # Check FullAccess
            try {
                $fullAccess = Get-EXOMailboxPermission -Identity $mailbox.PrimarySmtpAddress -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        $_.User -eq $UserEmail -and 
                        $_.User -notlike "NT AUTHORITY\*" -and 
                        $_.AccessRights -contains "FullAccess" 
                    }
                if ($fullAccess) { $permissions += "FullAccess" }
            } catch { }
            
            # Check SendAs
            try {
                $sendAs = Get-EXORecipientPermission -Identity $mailbox.PrimarySmtpAddress -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        $_.Trustee -eq $UserEmail -and 
                        $_.AccessRights -contains "SendAs" 
                    }
                if ($sendAs) { $permissions += "SendAs" }
            } catch { }
            
            # Add to results if has permissions
            if ($permissions.Count -gt 0) {
                $reportData.MailboxAccess += [PSCustomObject]@{
                    Mailbox = $mailbox.DisplayName
                    Email = $mailbox.PrimarySmtpAddress
                    Type = $mailbox.RecipientTypeDetails
                    Permissions = ($permissions -join ", ")
                }
                $accessCount++
            }
            
            # Throttling protection
            if ($processedCount % 20 -eq 0) {
                Start-Sleep -Milliseconds 200
            }
        }
        
        $totalTime = (Get-Date) - $startTime
        Write-Host "`nFound access to $accessCount shared mailboxes" -ForegroundColor Green
        Write-Host "Time taken: $($totalTime.ToString('mm\:ss'))" -ForegroundColor Gray
        Write-Host "Scope: Shared mailboxes only ($($sharedMailboxes.Count) checked)`n" -ForegroundColor Gray
        
    } catch {
        Write-Host "Failed to check shared mailboxes: $($_.Exception.Message)`n" -ForegroundColor Red
    }
    
} else {
    # ALL MAILBOXES (COMPREHENSIVE)
    Write-Host "Checking ALL mailboxes (comprehensive)..." -ForegroundColor Yellow
    
    try {
        $allMailboxes = Get-EXOMailbox -ResultSize Unlimited -Properties DisplayName,PrimarySmtpAddress,RecipientTypeDetails,GrantSendOnBehalfTo -ErrorAction Stop
        
        Write-Host "Found $($allMailboxes.Count) mailboxes to check" -ForegroundColor White
        Write-Host "This may take a while for large tenants...`n" -ForegroundColor Yellow
        
        $accessCount = 0
        $processedCount = 0
        $startTime = Get-Date
        
        foreach ($mailbox in $allMailboxes) {
            $processedCount++
            
            # Progress with ETA
            if ($processedCount % 100 -eq 0) {
                $elapsed = (Get-Date) - $startTime
                $rate = $processedCount / $elapsed.TotalSeconds
                $remaining = ($allMailboxes.Count - $processedCount) / $rate
                $eta = [TimeSpan]::FromSeconds($remaining)
                
                Write-Host "  Progress: $processedCount / $($allMailboxes.Count) | Found: $accessCount | ETA: $($eta.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
            }
            
            # Skip user's own mailbox
            if ($mailbox.PrimarySmtpAddress -eq $UserEmail) { continue }
            
            $permissions = @()
            
            # Check SendOnBehalf (no API call)
            if ($mailbox.GrantSendOnBehalfTo -and $mailbox.GrantSendOnBehalfTo -contains $UserEmail) {
                $permissions += "SendOnBehalf"
            }
            
            # Check FullAccess
            try {
                $fullAccess = Get-EXOMailboxPermission -Identity $mailbox.PrimarySmtpAddress -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        $_.User -eq $UserEmail -and 
                        $_.User -notlike "NT AUTHORITY\*" -and 
                        $_.AccessRights -contains "FullAccess" 
                    }
                if ($fullAccess) { $permissions += "FullAccess" }
            } catch { }
            
            # Check SendAs
            try {
                $sendAs = Get-EXORecipientPermission -Identity $mailbox.PrimarySmtpAddress -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        $_.Trustee -eq $UserEmail -and 
                        $_.AccessRights -contains "SendAs" 
                    }
                if ($sendAs) { $permissions += "SendAs" }
            } catch { }
            
            # Add to results
            if ($permissions.Count -gt 0) {
                $reportData.MailboxAccess += [PSCustomObject]@{
                    Mailbox = $mailbox.DisplayName
                    Email = $mailbox.PrimarySmtpAddress
                    Type = $mailbox.RecipientTypeDetails
                    Permissions = ($permissions -join ", ")
                }
                $accessCount++
            }
            
            # Throttling protection
            if ($processedCount % 20 -eq 0) {
                Start-Sleep -Milliseconds 200
            }
        }
        
        $totalTime = (Get-Date) - $startTime
        Write-Host "`nFound access to $accessCount mailboxes" -ForegroundColor Green
        Write-Host "  Time taken: $($totalTime.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        Write-Host "  Scope: All mailboxes ($($allMailboxes.Count) checked)`n" -ForegroundColor Gray
        
    } catch {
        Write-Host "Failed to check mailboxes: $($_.Exception.Message)`n" -ForegroundColor Red
    }
}

#endregion


#region Calendar Delegates

Write-Host "[6/14] Checking calendar delegate access..." -ForegroundColor Yellow

try {
    $calendarPerms = Get-MailboxFolderPermission -Identity "$($UserEmail):\Calendar" -ErrorAction Stop | Where-Object { $_.User -notlike "Default" -and $_.User -notlike "Anonymous" }
    
    foreach ($perm in $calendarPerms) {
        $reportData.CalendarDelegates += [PSCustomObject]@{
            User = $perm.User
            AccessRights = ($perm.AccessRights -join ", ")
        }
    }
    
    Write-Host "Found $($reportData.CalendarDelegates.Count) calendar delegates`n" -ForegroundColor Green
} catch {
    Write-Host "Could not check calendar permissions`n" -ForegroundColor Yellow
}

#endregion

#region Mail Forwarding Rules

Write-Host "[7/14] Checking mail forwarding configuration..." -ForegroundColor Yellow

try {
    $mailbox = Get-Mailbox -Identity $UserEmail -ErrorAction Stop
    
    $reportData.ForwardingRules = @{
        ForwardingEnabled = (-not [string]::IsNullOrEmpty($mailbox.ForwardingAddress) -or -not [string]::IsNullOrEmpty($mailbox.ForwardingSmtpAddress))
        ForwardingAddress = $mailbox.ForwardingAddress
        ForwardingSmtpAddress = $mailbox.ForwardingSmtpAddress
        DeliverToMailboxAndForward = $mailbox.DeliverToMailboxAndForward
        AutoReplyEnabled = $false
    }
    
    # Check auto-reply
    try {
        $autoReply = Get-MailboxAutoReplyConfiguration -Identity $UserEmail -ErrorAction Stop
        $reportData.ForwardingRules.AutoReplyEnabled = $autoReply.AutoReplyState -ne "Disabled"
    } catch { }
    
    Write-Host "Forwarding configuration retrieved`n" -ForegroundColor Green
} catch {
    Write-Host "Could not check forwarding rules`n" -ForegroundColor Yellow
}

#endregion

#region Teams Membership

Write-Host "[8/14] Retrieving Microsoft Teams membership..." -ForegroundColor Yellow

if ($teamsConnected -ne $false) {
    try {
        $userTeams = Get-Team -User $UserEmail -ErrorAction Stop
        
        foreach ($team in $userTeams) {
            # Check if user is owner
            $owners = Get-TeamUser -GroupId $team.GroupId -Role Owner -ErrorAction SilentlyContinue
            $isOwner = $owners.User -contains $UserEmail
            
            $reportData.Teams += [PSCustomObject]@{
                TeamName = $team.DisplayName
                IsOwner = $isOwner
                Archived = $team.Archived
            }
        }
        
        Write-Host "Found $($reportData.Teams.Count) Teams`n" -ForegroundColor Green
    } catch {
        Write-Host "Could not retrieve Teams membership`n" -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipped (Teams not connected)`n" -ForegroundColor Yellow
}

#endregion

#region OneDrive Storage

Write-Host "[9/14] Checking OneDrive storage usage..." -ForegroundColor Yellow

try {
    # Construct OneDrive URL from user email
    # Format: https://tenant-my.sharepoint.com/personal/firstname_lastname_domain_com
    
    # Get tenant name from user's email domain
    $domain = $UserEmail.Split('@')[1]
    $tenantName = $domain.Split('.')[0]
    
    # Sanitize username for OneDrive URL format
    $username = $UserEmail.Replace('@', '_').Replace('.', '_')
    
    # Construct OneDrive URL
    $oneDriveUrl = "https://$tenantName-my.sharepoint.com/personal/$username"
    
    Write-Host "  OneDrive URL: $oneDriveUrl" -ForegroundColor Gray
    
    # Try to get OneDrive site using SharePoint admin cmdlets
    try {
        # Connect to SharePoint Online admin (if not already connected)
        # Note: You'll need to add this module requirement at the top
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue
        
        # Check if already connected
        $adminUrl = "https://$tenantName-admin.sharepoint.com"
        
        try {
            $null = Get-SPOSite -Identity $oneDriveUrl -ErrorAction Stop
        } catch {
            # Not connected, connect now
            Write-Host "  Connecting to SharePoint Online..." -ForegroundColor Yellow
            Connect-SPOService -Url $adminUrl -ErrorAction Stop
        }
        
        # Get OneDrive site details
        $oneDriveSite = Get-SPOSite -Identity $oneDriveUrl -Detailed -ErrorAction Stop
        
        if ($oneDriveSite) {
            # Storage quota is in MB, convert to bytes for consistency
            $usedBytes = $oneDriveSite.StorageUsageCurrent * 1MB
            $totalBytes = $oneDriveSite.StorageQuota * 1MB
            $remainingBytes = $totalBytes - $usedBytes
            
            $reportData.OneDriveStorage = @{
                Used = $usedBytes
                Total = $totalBytes
                Remaining = $remainingBytes
                State = if ($usedBytes -gt ($totalBytes * 0.9)) { "Warning" } else { "Normal" }
                UsedReadable = ConvertTo-ReadableSize -Bytes $usedBytes
                TotalReadable = ConvertTo-ReadableSize -Bytes $totalBytes
                OneDriveUrl = $oneDriveUrl
            }
            
            Write-Host "OneDrive usage: $($reportData.OneDriveStorage.UsedReadable) / $($reportData.OneDriveStorage.TotalReadable)`n" -ForegroundColor Green
        }
        
    } catch {
        # OneDrive might not be provisioned yet
        if ($_.Exception.Message -like "*does not exist*" -or $_.Exception.Message -like "*Cannot get site*") {
            Write-Host "OneDrive not provisioned for this user`n" -ForegroundColor Yellow
            
            $reportData.OneDriveStorage = @{
                Used = 0
                Total = 0
                Remaining = 0
                State = "Not Provisioned"
                UsedReadable = "N/A"
                TotalReadable = "N/A"
                OneDriveUrl = $oneDriveUrl
            }
        } else {
            # Other error
            Write-Host "Could not retrieve OneDrive storage: $($_.Exception.Message)`n" -ForegroundColor Yellow
            
            $reportData.OneDriveStorage = @{
                Used = 0
                Total = 0
                Remaining = 0
                State = "Error"
                UsedReadable = "Unknown"
                TotalReadable = "Unknown"
                OneDriveUrl = $oneDriveUrl
            }
        }
    }
    
} catch {
    Write-Host "Could not construct OneDrive URL: $($_.Exception.Message)`n" -ForegroundColor Yellow
    
    $reportData.OneDriveStorage = @{
        Used = 0
        Total = 0
        Remaining = 0
        State = "Error"
        UsedReadable = "Unknown"
        TotalReadable = "Unknown"
        OneDriveUrl = ""
    }
}

#endregion

#region Registered Devices

Write-Host "[10/14] Retrieving registered devices..." -ForegroundColor Yellow

try {
    $devices = Get-MgUserRegisteredDevice -UserId $reportData.User.Id -All -ErrorAction Stop
    
    foreach ($device in $devices) {
        $deviceDetails = Get-MgDevice -DeviceId $device.Id -ErrorAction SilentlyContinue
        
        if ($deviceDetails) {
            $reportData.Devices += [PSCustomObject]@{
                DisplayName = $deviceDetails.DisplayName
                OS = $deviceDetails.OperatingSystem
                OSVersion = $deviceDetails.OperatingSystemVersion
                IsCompliant = $deviceDetails.IsCompliant
                IsManaged = $deviceDetails.IsManaged
                ApproximateLastSignIn = $deviceDetails.ApproximateLastSignInDateTime
            }
        }
    }
    
    Write-Host "Found $($reportData.Devices.Count) devices`n" -ForegroundColor Green
} catch {
    Write-Host "Could not retrieve device information`n" -ForegroundColor Yellow
}

#endregion

#region Manager and Direct Reports

Write-Host "[11/14] Checking manager and direct reports..." -ForegroundColor Yellow

try {
    $manager = Get-MgUserManager -UserId $reportData.User.Id -ErrorAction SilentlyContinue
    if ($manager) {
        $managerDetails = Get-MgUser -UserId $manager.Id -Property "DisplayName,Mail,JobTitle" -ErrorAction Stop
        $reportData.Manager = $managerDetails
    }
} catch { }

try {
    $directReports = Get-MgUserDirectReport -UserId $reportData.User.Id -All -ErrorAction Stop
    foreach ($report in $directReports) {
        $reportDetails = Get-MgUser -UserId $report.Id -Property "DisplayName,Mail,JobTitle" -ErrorAction SilentlyContinue
        if ($reportDetails) {
            $reportData.DirectReports += $reportDetails
        }
    }
    
    Write-Host "Manager: $(if ($reportData.Manager) { $reportData.Manager.DisplayName } else { 'None' })" -ForegroundColor Green
    Write-Host "Direct Reports: $($reportData.DirectReports.Count)`n" -ForegroundColor Green
} catch {
    Write-Host "Could not retrieve management hierarchy`n" -ForegroundColor Yellow
}

#endregion

#region Admin Roles

Write-Host "[12/14] Checking administrative role assignments..." -ForegroundColor Yellow

try {
    $roleAssignments = Get-MgUserMemberOf -UserId $reportData.User.Id -All | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' }
    
    foreach ($role in $roleAssignments) {
        $roleDetails = Get-MgDirectoryRole -DirectoryRoleId $role.Id -ErrorAction SilentlyContinue
        if ($roleDetails) {
            $reportData.AdminRoles += $roleDetails.DisplayName
        }
    }
    
    if ($reportData.AdminRoles.Count -gt 0) {
        Write-Host "Found $($reportData.AdminRoles.Count) admin roles`n" -ForegroundColor Yellow
    } else {
        Write-Host "No admin roles assigned`n" -ForegroundColor Green
    }
} catch {
    Write-Host "Could not check admin roles`n" -ForegroundColor Yellow
}

#endregion

#region Application Access

Write-Host "[13/14] Retrieving application access..." -ForegroundColor Yellow

try {
    $appAssignments = Get-MgUserAppRoleAssignment -UserId $reportData.User.Id -All -ErrorAction Stop
    
    foreach ($assignment in $appAssignments) {
        try {
            $servicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $assignment.ResourceId -ErrorAction SilentlyContinue
            if ($servicePrincipal -and $servicePrincipal.DisplayName -notlike "Office 365*" -and $servicePrincipal.DisplayName -notlike "Microsoft*") {
                $reportData.Applications += $servicePrincipal.DisplayName
            }
        } catch { }
    }
    
    $reportData.Applications = $reportData.Applications | Sort-Object -Unique
    Write-Host "Found access to $($reportData.Applications.Count) applications`n" -ForegroundColor Green
} catch {
    Write-Host "Could not retrieve application access`n" -ForegroundColor Yellow
}

#endregion

#region SharePoint Sites Owned

Write-Host "[14/14] Checking SharePoint sites owned..." -ForegroundColor Yellow

try {
    $sites = Get-MgSite -Search "*" -All -Property "id,name,webUrl,createdDateTime" -ErrorAction Stop
    
    $ownedCount = 0
    foreach ($site in $sites) {
        try {
            $owner = Get-MgSiteOwner -SiteId $site.Id -ErrorAction SilentlyContinue
            if ($owner.Mail -eq $UserEmail) {
                $reportData.SharePointSites += [PSCustomObject]@{
                    Name = $site.Name
                    Url = $site.WebUrl
                    Created = $site.CreatedDateTime
                }
                $ownedCount++
            }
        } catch { }
        
        # Throttling
        if (($sites.IndexOf($site) + 1) % 20 -eq 0) {
            Start-Sleep -Milliseconds 300
        }
    }
    
    Write-Host "Found $ownedCount SharePoint sites owned`n" -ForegroundColor Green
} catch {
    Write-Host "Could not retrieve SharePoint site ownership`n" -ForegroundColor Yellow
}

#endregion

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Generating HTML Report" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

#region Generate HTML Report

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sanitizedEmail = $UserEmail -replace '@', '_at_' -replace '\.', '_'
$reportFileName = "UserProfile_${sanitizedEmail}_${timestamp}.html"
$reportPath = Join-Path $ExportPath $reportFileName

# Calculate total license cost
$totalMonthlyCost = ($reportData.Licenses | Measure-Object -Property MonthlyCost -Sum).Sum

# HTML Template
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>User Profile Report - $($reportData.User.DisplayName)</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #0078d4;
            border-bottom: 3px solid #0078d4;
            padding-bottom: 10px;
        }
        h2 {
            color: #333;
            margin-top: 30px;
            border-left: 4px solid #0078d4;
            padding-left: 10px;
        }
        .summary-box {
            background-color: #f0f8ff;
            border-left: 4px solid #0078d4;
            padding: 15px;
            margin: 20px 0;
        }
        .warning-box {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }
        .danger-box {
            background-color: #f8d7da;
            border-left: 4px solid #dc3545;
            padding: 15px;
            margin: 20px 0;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 200px 1fr;
            gap: 10px;
            margin: 15px 0;
        }
        .info-label {
            font-weight: bold;
            color: #555;
        }
        .info-value {
            color: #333;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th {
            background-color: #0078d4;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: bold;
        }
        .badge-success {
            background-color: #28a745;
            color: white;
        }
        .badge-warning {
            background-color: #ffc107;
            color: #333;
        }
        .badge-danger {
            background-color: #dc3545;
            color: white;
        }
        .badge-info {
            background-color: #17a2b8;
            color: white;
        }
        .badge-secondary {
            background-color: #6c757d;
            color: white;
        }
        .section {
            margin: 30px 0;
        }
        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #777;
            font-size: 12px;
        }
        ul {
            margin: 10px 0;
            padding-left: 20px;
        }
        li {
            margin: 5px 0;
        }
        @media print {
            body {
                background-color: white;
            }
            .container {
                box-shadow: none;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>User Profile Report</h1>
        
        <div class="summary-box">
            <h3 style="margin-top: 0;">$($reportData.User.DisplayName)</h3>
            <div class="info-grid">
                <div class="info-label">Email:</div>
                <div class="info-value">$($reportData.User.UserPrincipalName)</div>
                
                <div class="info-label">Status:</div>
                <div class="info-value">
                    $(if ($reportData.User.AccountEnabled) { 
                        '<span class="badge badge-success">ENABLED</span>' 
                    } else { 
                        '<span class="badge badge-danger">DISABLED</span>' 
                    })
                </div>
                
                <div class="info-label">Report Generated:</div>
                <div class="info-value">$($reportData.GeneratedDate.ToString('yyyy-MM-dd HH:mm:ss'))</div>
            </div>
        </div>

        <div class="section">
            <h2>Basic Information</h2>
            <div class="info-grid">
                <div class="info-label">Display Name:</div>
                <div class="info-value">$($reportData.User.DisplayName)</div>
                
                <div class="info-label">Job Title:</div>
                <div class="info-value">$(if ($reportData.User.JobTitle) { $reportData.User.JobTitle } else { '<em>Not set</em>' })</div>
                
                <div class="info-label">Department:</div>
                <div class="info-value">$(if ($reportData.User.Department) { $reportData.User.Department } else { '<em>Not set</em>' })</div>
                
                <div class="info-label">Office:</div>
                <div class="info-value">$(if ($reportData.User.OfficeLocation) { $reportData.User.OfficeLocation } else { '<em>Not set</em>' })</div>
                
                <div class="info-label">Mobile Phone:</div>
                <div class="info-value">$(if ($reportData.User.MobilePhone) { $reportData.User.MobilePhone } else { '<em>Not set</em>' })</div>
                
                <div class="info-label">Business Phone:</div>
                <div class="info-value">$(if ($reportData.User.BusinessPhones) { $reportData.User.BusinessPhones -join ', ' } else { '<em>Not set</em>' })</div>
                
                <div class="info-label">Employee ID:</div>
                <div class="info-value">$(if ($reportData.User.EmployeeId) { $reportData.User.EmployeeId } else { '<em>Not set</em>' })</div>
                
                <div class="info-label">Account Created:</div>
                <div class="info-value">$($reportData.User.CreatedDateTime.ToString('yyyy-MM-dd'))</div>
                
                <div class="info-label">Synced from On-Prem:</div>
                <div class="info-value">$(if ($reportData.User.OnPremisesSyncEnabled) { 'Yes' } else { 'No' })</div>
            </div>
        </div>

        <div class="section">
            <h2>Authentication & Security</h2>
            <div class="info-grid">
                <div class="info-label">Last Sign-In:</div>
                <div class="info-value">$(if ($reportData.SignInActivity.LastSignIn) { $reportData.SignInActivity.LastSignIn.ToString('yyyy-MM-dd HH:mm:ss') } else { '<em>Never</em>' })</div>
                
                <div class="info-label">Last Password Change:</div>
                <div class="info-value">$(if ($reportData.LastPasswordChange) { $reportData.LastPasswordChange.ToString('yyyy-MM-dd') } else { '<em>Unknown</em>' })</div>
                
                <div class="info-label">MFA Status:</div>
                <div class="info-value">
                    $(if ($reportData.MFAStatus.IsEnabled) { 
                        '<span class="badge badge-success">ENABLED</span>' 
                    } else { 
                        '<span class="badge badge-danger">NOT ENABLED</span>' 
                    })
                </div>
                
                <div class="info-label">MFA Methods:</div>
                <div class="info-value">
                    $(if ($reportData.MFAStatus.Methods.Count -gt 0) { 
                        ($reportData.MFAStatus.Methods -replace 'AuthenticationMethod', '' -join ', ') 
                    } else { 
                        '<em>None configured</em>' 
                    })
                </div>
                
                <div class="info-label">Admin Roles:</div>
                <div class="info-value">
                    $(if ($reportData.AdminRoles.Count -gt 0) { 
                        '<span class="badge badge-warning">' + ($reportData.AdminRoles -join '</span> <span class="badge badge-warning">') + '</span>'
                    } else { 
                        '<em>None</em>' 
                    })
                </div>
            </div>
        </div>

        <div class="section">
            <h2>License Assignments</h2>
            $(if ($reportData.Licenses.Count -gt 0) {
                "<p><strong>Total Monthly Cost:</strong> `$$($totalMonthlyCost.ToString('N2'))</p>
                <table>
                    <tr>
                        <th>License Name</th>
                        <th>Assignment Type</th>
                        <th>Assigned By</th>
                        <th>Monthly Cost</th>
                    </tr>"
                foreach ($license in $reportData.Licenses) {
                    $assignmentBadge = switch ($license.AssignmentType) {
                        "Group" { '<span class="badge badge-success">Group</span>' }
                        "Direct" { '<span class="badge badge-warning">Direct</span>' }
                        "Both" { '<span class="badge badge-danger">Both (Duplicate!)</span>' }
                        default { '<span class="badge badge-secondary">Unknown</span>' }
                    }
                    "<tr>
                        <td>$($license.Name)</td>
                        <td>$assignmentBadge</td>
                        <td>$(if ($license.AssignedBy) { $license.AssignedBy } else { '-' })</td>
                        <td>`$$($license.MonthlyCost.ToString('N2'))</td>
                    </tr>"
                }
                "</table>"
            } else {
                "<p><em>No licenses assigned</em></p>"
            })
        </div>

        <div class="section">
            <h2>Group Memberships</h2>
            
            <h3>Security Groups ($($reportData.Groups.Security.Count))</h3>
            $(if ($reportData.Groups.Security.Count -gt 0) {
                "<ul>"
                foreach ($group in ($reportData.Groups.Security | Sort-Object DisplayName)) {
                    "<li>$($group.DisplayName)</li>"
                }
                "</ul>"
            } else {
                "<p><em>No security group memberships</em></p>"
            })
            
            <h3>Microsoft 365 Groups ($($reportData.Groups.Microsoft365.Count))</h3>
            $(if ($reportData.Groups.Microsoft365.Count -gt 0) {
                "<ul>"
                foreach ($group in ($reportData.Groups.Microsoft365 | Sort-Object DisplayName)) {
                    "<li>$($group.DisplayName)$(if ($group.Mail) { " ($($group.Mail))" })</li>"
                }
                "</ul>"
            } else {
                "<p><em>No Microsoft 365 group memberships</em></p>"
            })
            
            <h3>Distribution Lists ($($reportData.Groups.Distribution.Count))</h3>
            $(if ($reportData.Groups.Distribution.Count -gt 0) {
                "<ul>"
                foreach ($group in ($reportData.Groups.Distribution | Sort-Object DisplayName)) {
                    "<li>$($group.DisplayName)$(if ($group.Mail) { " ($($group.Mail))" })</li>"
                }
                "</ul>"
            } else {
                "<p><em>No distribution list memberships</em></p>"
            })
        </div>

        <div class="section">
    <h2>Mailbox Access</h2>
    
    <!-- Show which mode was used -->
    <div class="info-grid" style="margin-bottom: 20px;">
        <div class="info-label">Check Scope:</div>
        <div class="info-value">
            $(if ($reportData.MailboxAccessMode -eq 'Shared Mailboxes Only') {
                '<span class="badge badge-success">Shared Mailboxes Only</span>'
            } elseif ($reportData.MailboxAccessMode -eq 'All Mailboxes (Comprehensive)') {
                '<span class="badge badge-info">All Mailboxes (Comprehensive)</span>'
            } else {
                '<span class="badge badge-secondary">Skipped</span>'
            })
        </div>
    </div>
    
    $(if ($reportData.MailboxAccessSkipped) {
        # Skipped mode
        "<div class='warning-box'>
            <p><strong>Mailbox Access Check Skipped</strong></p>
            <p>The mailbox access check was skipped during report generation.</p>
            <p>To check mailbox access, re-run the report and select option 1 or 2.</p>
            <p>Alternatively, use the dedicated 'User Mailbox Access Finder' tool for comprehensive mailbox auditing.</p>
        </div>"
    } elseif ($reportData.MailboxAccess.Count -gt 0) {
        # Has mailbox access
        "<table>
            <tr>
                <th>Mailbox</th>
                <th>Email</th>
                <th>Type</th>
                <th>Permissions</th>
            </tr>"
        foreach ($access in ($reportData.MailboxAccess | Sort-Object Mailbox)) {
            "<tr>
                <td>$($access.Mailbox)</td>
                <td>$($access.Email)</td>
                <td>$($access.Type)</td>
                <td>$($access.Permissions)</td>
            </tr>"
        }
        "</table>"
        
        # Add note if SharedOnly mode
        if ($reportData.MailboxAccessMode -eq 'Shared Mailboxes Only') {
            "<p><small><em>Note: Only shared mailboxes were checked. Other user mailboxes were not included in this scope.</em></small></p>"
        }
    } else {
        # No access found
        if ($reportData.MailboxAccessMode -eq 'Shared Mailboxes Only') {
            "<p><em>No shared mailbox access permissions found.</em></p>
            <p><small><em>Note: Only shared mailboxes were checked. To check all mailboxes, re-run with comprehensive mode.</em></small></p>"
        } else {
            "<p><em>No mailbox access permissions found (owns own mailbox only).</em></p>"
        }
    })
    
    <h3>Calendar Delegates</h3>
    $(if ($reportData.CalendarDelegates.Count -gt 0) {
        "<table>
            <tr>
                <th>User</th>
                <th>Access Rights</th>
            </tr>"
        foreach ($delegate in $reportData.CalendarDelegates) {
            "<tr>
                <td>$($delegate.User)</td>
                <td>$($delegate.AccessRights)</td>
            </tr>"
        }
        "</table>"
    } else {
        "<p><em>No calendar delegates</em></p>"
    })
    
    <h3>Forwarding Configuration</h3>
    <div class="info-grid">
        <div class="info-label">External Forwarding:</div>
        <div class="info-value">
            $(if ($reportData.ForwardingRules.ForwardingEnabled) { 
                '<span class="badge badge-warning">ENABLED</span><br>To: ' + 
                $(if ($reportData.ForwardingRules.ForwardingSmtpAddress) { 
                    $reportData.ForwardingRules.ForwardingSmtpAddress 
                } else { 
                    $reportData.ForwardingRules.ForwardingAddress 
                })
            } else { 
                '<span class="badge badge-success">DISABLED</span>' 
            })
        </div>
        
        <div class="info-label">Auto-Reply:</div>
        <div class="info-value">
            $(if ($reportData.ForwardingRules.AutoReplyEnabled) { 
                '<span class="badge badge-info">ENABLED</span>' 
            } else { 
                '<span class="badge badge-secondary">DISABLED</span>' 
            })
        </div>
    </div>
</div>
            
            <h3>Calendar Delegates</h3>
            $(if ($reportData.CalendarDelegates.Count -gt 0) {
                "<table>
                    <tr>
                        <th>User</th>
                        <th>Access Rights</th>
                    </tr>"
                foreach ($delegate in $reportData.CalendarDelegates) {
                    "<tr>
                        <td>$($delegate.User)</td>
                        <td>$($delegate.AccessRights)</td>
                    </tr>"
                }
                "</table>"
            } else {
                "<p><em>No calendar delegates</em></p>"
            })
            
            <h3>Forwarding Configuration</h3>
            <div class="info-grid">
                <div class="info-label">External Forwarding:</div>
                <div class="info-value">
                    $(if ($reportData.ForwardingRules.ForwardingEnabled) { 
                        '<span class="badge badge-warning">ENABLED</span><br>To: ' + 
                        $(if ($reportData.ForwardingRules.ForwardingSmtpAddress) { 
                            $reportData.ForwardingRules.ForwardingSmtpAddress 
                        } else { 
                            $reportData.ForwardingRules.ForwardingAddress 
                        })
                    } else { 
                        '<span class="badge badge-success">DISABLED</span>' 
                    })
                </div>
                
                <div class="info-label">Auto-Reply:</div>
                <div class="info-value">
                    $(if ($reportData.ForwardingRules.AutoReplyEnabled) { 
                        '<span class="badge badge-info">ENABLED</span>' 
                    } else { 
                        '<span class="badge badge-secondary">DISABLED</span>' 
                    })
                </div>
            </div>
        </div>

        <div class="section">
            <h2>Microsoft Teams</h2>
            $(if ($reportData.Teams.Count -gt 0) {
                "<table>
                    <tr>
                        <th>Team Name</th>
                        <th>Role</th>
                        <th>Status</th>
                    </tr>"
                foreach ($team in ($reportData.Teams | Sort-Object TeamName)) {
                    "<tr>
                        <td>$($team.TeamName)</td>
                        <td>$(if ($team.IsOwner) { '<span class="badge badge-warning">Owner</span>' } else { '<span class="badge badge-info">Member</span>' })</td>
                        <td>$(if ($team.Archived) { '<span class="badge badge-secondary">Archived</span>' } else { '<span class="badge badge-success">Active</span>' })</td>
                    </tr>"
                }
                "</table>"
            } else {
                "<p><em>No Teams memberships</em></p>"
            })
        </div>

        <div class="section">
            <h2>OneDrive Storage</h2>
            $(if ($reportData.OneDriveStorage.Used) {
                "<div class='info-grid'>
                    <div class='info-label'>Storage Used:</div>
                    <div class='info-value'>$($reportData.OneDriveStorage.UsedReadable) / $($reportData.OneDriveStorage.TotalReadable)</div>
                    
                    <div class='info-label'>Percentage Used:</div>
                    <div class='info-value'>$(([math]::Round(($reportData.OneDriveStorage.Used / $reportData.OneDriveStorage.Total) * 100, 2)))%</div>
                </div>"
            } else {
                "<p><em>OneDrive information not available</em></p>"
            })
        </div>

        <div class="section">
            <h2>Registered Devices</h2>
            $(if ($reportData.Devices.Count -gt 0) {
                "<table>
                    <tr>
                        <th>Device Name</th>
                        <th>Operating System</th>
                        <th>Compliant</th>
                        <th>Managed</th>
                        <th>Last Sign-In</th>
                    </tr>"
                foreach ($device in ($reportData.Devices | Sort-Object ApproximateLastSignIn -Descending)) {
                    "<tr>
                        <td>$($device.DisplayName)</td>
                        <td>$($device.OS) $($device.OSVersion)</td>
                        <td>$(if ($device.IsCompliant) { '<span class="badge badge-success">Yes</span>' } else { '<span class="badge badge-danger">No</span>' })</td>
                        <td>$(if ($device.IsManaged) { '<span class="badge badge-success">Yes</span>' } else { '<span class="badge badge-secondary">No</span>' })</td>
                        <td>$(if ($device.ApproximateLastSignIn) { $device.ApproximateLastSignIn.ToString('yyyy-MM-dd HH:mm') } else { '<em>Unknown</em>' })</td>
                    </tr>"
                }
                "</table>"
            } else {
                "<p><em>No registered devices</em></p>"
            })
        </div>

        <div class="section">
            <h2>Management Hierarchy</h2>
            
            <h3>Manager</h3>
            $(if ($reportData.Manager) {
                "<div class='info-grid'>
                    <div class='info-label'>Name:</div>
                    <div class='info-value'>$($reportData.Manager.DisplayName)</div>
                    
                    <div class='info-label'>Email:</div>
                    <div class='info-value'>$($reportData.Manager.Mail)</div>
                    
                    <div class='info-label'>Job Title:</div>
                    <div class='info-value'>$(if ($reportData.Manager.JobTitle) { $reportData.Manager.JobTitle } else { '<em>Not set</em>' })</div>
                </div>"
            } else {
                "<p><em>No manager assigned</em></p>"
            })
            
            <h3>Direct Reports ($($reportData.DirectReports.Count))</h3>
            $(if ($reportData.DirectReports.Count -gt 0) {
                "<ul>"
                foreach ($report in ($reportData.DirectReports | Sort-Object DisplayName)) {
                    "<li><strong>$($report.DisplayName)</strong>$(if ($report.JobTitle) { " - $($report.JobTitle)" }) ($($report.Mail))</li>"
                }
                "</ul>"
            } else {
                "<p><em>No direct reports</em></p>"
            })
        </div>

        <div class="section">
            <h2>Application Access</h2>
            $(if ($reportData.Applications.Count -gt 0) {
                "<ul>"
                foreach ($app in ($reportData.Applications | Sort-Object)) {
                    "<li>$app</li>"
                }
                "</ul>"
            } else {
                "<p><em>No third-party applications assigned</em></p>"
            })
        </div>

        <div class="section">
            <h2>SharePoint Sites Owned</h2>
            $(if ($reportData.SharePointSites.Count -gt 0) {
                "<table>
                    <tr>
                        <th>Site Name</th>
                        <th>URL</th>
                        <th>Created</th>
                    </tr>"
                foreach ($site in ($reportData.SharePointSites | Sort-Object Name)) {
                    "<tr>
                        <td>$($site.Name)</td>
                        <td><a href='$($site.Url)' target='_blank'>$($site.Url)</a></td>
                        <td>$(if ($site.Created) { $site.Created.ToString('yyyy-MM-dd') } else { '<em>Unknown</em>' })</td>
                    </tr>"
                }
                "</table>"
            } else {
                "<p><em>No SharePoint sites owned</em></p>
                <p><small><em>Note: This report only shows sites where the user is the primary owner. Use SharePoint admin center for complete site access audit.</em></small></p>"
            })
        </div>

        <div class="section">
    <h2>Offboarding Checklist</h2>
    <div class="warning-box">
        <p><strong>Important:</strong> Review all sections above before proceeding with offboarding.</p>
    </div>
    <ul>
        <li>☐ Remove from all Security Groups ($($reportData.Groups.Security.Count) groups)</li>
        <li>☐ Transfer mailbox access permissions 
            $(if ($reportData.MailboxAccessSkipped) {
                "(Skipped in report - check manually or re-run report)"
            } elseif ($reportData.MailboxAccessMode -eq 'Shared Mailboxes Only') {
                "($($reportData.MailboxAccess.Count) shared mailboxes - Note: Only shared mailboxes checked)"
            } else {
                "($($reportData.MailboxAccess.Count) mailboxes)"
            })
        </li>
        <li>☐ Reassign Teams ownership ($(($reportData.Teams | Where-Object { $_.IsOwner }).Count) teams owned)</li>
        <li>☐ Transfer SharePoint site ownership ($($reportData.SharePointSites.Count) sites owned)</li>
        <li>☐ Transfer OneDrive content ($($reportData.OneDriveStorage.UsedReadable) used)</li>
        <li>☐ Remove calendar delegates ($($reportData.CalendarDelegates.Count) delegates)</li>
        <li>☐ Disable external mail forwarding $(if ($reportData.ForwardingRules.ForwardingEnabled) { '(Currently ENABLED!)' } else { '(OK)' })</li>
        <li>☐ Wipe registered devices ($($reportData.Devices.Count) devices)</li>
        <li>☐ Remove admin roles $(if ($reportData.AdminRoles.Count -gt 0) { "($($reportData.AdminRoles.Count) roles assigned!)" } else { '(None)' })</li>
        <li>☐ Reassign direct reports to new manager ($($reportData.DirectReports.Count) reports)</li>
        <li>☐ Remove application licenses</li>
        <li>☐ Disable user account</li>
        <li>☐ Convert mailbox to shared (if needed)</li>
        <li>☐ Document handoff completion</li>
    </ul>
</div>

        <div class="footer">
            <p>Report generated: $($reportData.GeneratedDate.ToString('yyyy-MM-dd HH:mm:ss'))</p>
            <p>Generated by: User Profile Report Tool v1.0</p>
            <p>MSP PowerShell Toolkit | Nathan Forest</p>
        </div>
    </div>
</body>
</html>
"@

# Save HTML report
$html | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "HTML report generated successfully!`n" -ForegroundColor Green
Write-Host "Report saved to: $reportPath`n" -ForegroundColor Cyan

#endregion

#region Cleanup

Disconnect-MgGraph | Out-Null
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
if ($teamsConnected -ne $false) {
    Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "Disconnected from services`n" -ForegroundColor Gray

#endregion

#region Open Report

if ($OpenReport) {
    Write-Host "Opening report in browser...`n" -ForegroundColor Yellow
    Start-Process $reportPath
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PROFILE REPORT COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

#endregion
