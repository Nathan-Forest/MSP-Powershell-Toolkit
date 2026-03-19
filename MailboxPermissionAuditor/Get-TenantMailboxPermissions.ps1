<#
.SYNOPSIS
    Tenant-Wide Mailbox Permission Audit
.DESCRIPTION
    Reports all SendAs, FullAccess (Read/Manage), and SendOnBehalf permissions for every mailbox in the tenant
    Generates comprehensive CSV report for security and compliance auditing
.NOTES
    Author: Nathan Forest
    This can take 30-60 minutes for large tenants (1000+ mailboxes)
#>

# Connect to Exchange Online
Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
Connect-ExchangeOnline

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TENANT-WIDE MAILBOX PERMISSION AUDIT" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get all mailboxes
Write-Host "Fetching all mailboxes..." -ForegroundColor Yellow
$allMailboxes = Get-Mailbox -ResultSize Unlimited

Write-Host "Found $($allMailboxes.Count) mailboxes to audit`n" -ForegroundColor Green

# Initialize results
$permissionReport = @()
$progressCount = 0

# Process each mailbox
foreach ($mailbox in $allMailboxes) {
    $progressCount++
    $percentComplete = [math]::Round(($progressCount / $allMailboxes.Count) * 100, 1)
    
    Write-Progress -Activity "Auditing mailbox permissions" `
        -Status "Processing $($mailbox.DisplayName) ($progressCount of $($allMailboxes.Count))" `
        -PercentComplete $percentComplete
    
    # --- Check 1: FullAccess Permissions (Read/Manage) ---
    try {
        $fullAccessPerms = Get-MailboxPermission -Identity $mailbox.UserPrincipalName -ErrorAction Stop | 
            Where-Object { 
                $_.User -notlike "NT AUTHORITY\*" -and 
                $_.User -ne "SELF" -and
                $_.IsInherited -eq $false -and
                $_.Deny -eq $false
            }
        
        foreach ($perm in $fullAccessPerms) {
            $permissionReport += [PSCustomObject]@{
                MailboxName = $mailbox.DisplayName
                MailboxEmail = $mailbox.UserPrincipalName
                MailboxType = $mailbox.RecipientTypeDetails
                PermissionType = "FullAccess (Read/Manage)"
                GrantedTo = $perm.User
                AccessRights = ($perm.AccessRights -join ", ")
                IsInherited = $perm.IsInherited
            }
        }
    }
    catch {
        Write-Host "  Error checking FullAccess for $($mailbox.DisplayName): $_" -ForegroundColor Red
    }
    
    # --- Check 2: SendAs Permissions ---
    try {
        $sendAsPerms = Get-RecipientPermission -Identity $mailbox.UserPrincipalName -ErrorAction Stop | 
            Where-Object { 
                $_.Trustee -notlike "NT AUTHORITY\*" -and
                $_.Trustee -ne "SELF" -and
                $_.AccessRights -contains "SendAs"
            }
        
        foreach ($perm in $sendAsPerms) {
            $permissionReport += [PSCustomObject]@{
                MailboxName = $mailbox.DisplayName
                MailboxEmail = $mailbox.UserPrincipalName
                MailboxType = $mailbox.RecipientTypeDetails
                PermissionType = "SendAs"
                GrantedTo = $perm.Trustee
                AccessRights = "SendAs"
                IsInherited = $perm.IsInherited
            }
        }
    }
    catch {
        Write-Host "  Error checking SendAs for $($mailbox.DisplayName): $_" -ForegroundColor Red
    }
    
    # --- Check 3: SendOnBehalf Permissions ---
    if ($mailbox.GrantSendOnBehalfTo.Count -gt 0) {
        foreach ($delegate in $mailbox.GrantSendOnBehalfTo) {
            $permissionReport += [PSCustomObject]@{
                MailboxName = $mailbox.DisplayName
                MailboxEmail = $mailbox.UserPrincipalName
                MailboxType = $mailbox.RecipientTypeDetails
                PermissionType = "SendOnBehalf"
                GrantedTo = $delegate
                AccessRights = "SendOnBehalf"
                IsInherited = $false
            }
        }
    }
    
    # Small delay every 50 mailboxes to avoid throttling
    if ($progressCount % 50 -eq 0) {
        Start-Sleep -Seconds 2
    }
}

Write-Progress -Activity "Auditing mailbox permissions" -Completed

# Display results
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "AUDIT COMPLETE" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

if ($permissionReport.Count -gt 0) {
    # Summary statistics
    Write-Host "Summary Statistics:" -ForegroundColor Cyan
    Write-Host "  Total mailboxes audited: $($allMailboxes.Count)"
    Write-Host "  Total delegated permissions found: $($permissionReport.Count)" -ForegroundColor Yellow
    Write-Host ""
    
    # Breakdown by permission type
    Write-Host "Permissions by Type:" -ForegroundColor Cyan
    $permissionReport | Group-Object PermissionType | 
        Select-Object Name, Count | 
        Sort-Object Count -Descending |
        Format-Table -AutoSize
    
    # Top 10 most delegated mailboxes
    Write-Host "Top 10 Most Delegated Mailboxes:" -ForegroundColor Cyan
    $permissionReport | Group-Object MailboxEmail | 
        Select-Object Name, Count | 
        Sort-Object Count -Descending | 
        Select-Object -First 10 |
        Format-Table -AutoSize
    
    # Sample of results
    Write-Host "Sample Results (First 20 permissions):" -ForegroundColor Cyan
    $permissionReport | Select-Object -First 20 | 
        Format-Table MailboxName, PermissionType, GrantedTo -AutoSize
    
    # Export to CSV
    $exportPath = ".\TenantMailboxPermissions_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    if (-not (Test-Path ".\")) {
        New-Item -Path ".\" -ItemType Directory -Force | Out-Null
    }
    
    $permissionReport | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host "`n✓ Full report exported to: $exportPath" -ForegroundColor Green
    
    # Open in GridView for interactive filtering
    $permissionReport | Out-GridView -Title "Tenant Mailbox Permissions Audit"
    
} else {
    Write-Host "✓ No delegated mailbox permissions found in tenant" -ForegroundColor Green
    Write-Host "All mailboxes are only accessible by their owners" -ForegroundColor Green
}

# Cleanup
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "`nAudit complete!" -ForegroundColor Cyan
