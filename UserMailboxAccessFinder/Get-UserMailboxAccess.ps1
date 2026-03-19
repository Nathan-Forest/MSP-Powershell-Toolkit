<#
.SYNOPSIS
    Find all mailboxes that specific users have access to
.DESCRIPTION
    Checks FullAccess, SendAs, and SendOnBehalf permissions for a list of users
.NOTES
    Author: Nathan Forest 
#>

Connect-ExchangeOnline

# List of users to check (can also import from CSV)
$usersToCheck = Import-Csv "C:\Temp\UsersToCheck.csv" | Select-Object -ExpandProperty UserPrincipalName

# Initialize results array
$results = @()

Write-Host "Fetching all mailboxes..." -ForegroundColor Cyan

# Get all mailboxes with pagination
$allMailboxes = Get-Mailbox -ResultSize Unlimited

Write-Host "Found $($allMailboxes.Count) mailboxes. Checking permissions..." -ForegroundColor Yellow

$progressCount = 0

foreach ($mailbox in $allMailboxes) {
    $progressCount++
    Write-Progress -Activity "Checking mailbox permissions" -Status "Processing $($mailbox.DisplayName)" -PercentComplete (($progressCount / $allMailboxes.Count) * 100)
    
    # Get FullAccess permissions
    $fullAccessPerms = Get-MailboxPermission -Identity $mailbox.UserPrincipalName | 
        Where-Object { $_.User -notlike "NT AUTHORITY\*" -and $_.IsInherited -eq $false }
    
    # Get SendAs permissions
    $sendAsPerms = Get-RecipientPermission -Identity $mailbox.UserPrincipalName | 
        Where-Object { $_.Trustee -notlike "NT AUTHORITY\*" }
    
    # Get SendOnBehalf permissions
    $sendOnBehalfPerms = $mailbox.GrantSendOnBehalfTo
    
    # Check if any of our users have access
    foreach ($user in $usersToCheck) {
        
        # Check FullAccess
        $hasFullAccess = $fullAccessPerms | Where-Object { $_.User -eq $user }
        if ($hasFullAccess) {
            $results += [PSCustomObject]@{
                User = $user
                MailboxName = $mailbox.DisplayName
                MailboxEmail = $mailbox.UserPrincipalName
                PermissionType = "FullAccess"
                AccessRights = ($hasFullAccess.AccessRights -join ", ")
            }
        }
        
        # Check SendAs
        $hasSendAs = $sendAsPerms | Where-Object { $_.Trustee -eq $user }
        if ($hasSendAs) {
            $results += [PSCustomObject]@{
                User = $user
                MailboxName = $mailbox.DisplayName
                MailboxEmail = $mailbox.UserPrincipalName
                PermissionType = "SendAs"
                AccessRights = "SendAs"
            }
        }
        
        # Check SendOnBehalf
        if ($sendOnBehalfPerms -contains $user) {
            $results += [PSCustomObject]@{
                User = $user
                MailboxName = $mailbox.DisplayName
                MailboxEmail = $mailbox.UserPrincipalName
                PermissionType = "SendOnBehalf"
                AccessRights = "SendOnBehalf"
            }
        }
    }
}

Write-Progress -Activity "Checking mailbox permissions" -Completed

# Display results
if ($results.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "MAILBOX ACCESS REPORT" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    foreach ($user in $usersToCheck) {
        $userAccess = $results | Where-Object { $_.User -eq $user }
        Write-Host " $user has access to $($userAccess.Count) mailboxes" -ForegroundColor Yellow
    }
    
    Write-Host "`nDetailed Results:" -ForegroundColor Cyan
    $results | Format-Table User, MailboxName, PermissionType, AccessRights -AutoSize
    
    # Export to CSV
    $exportPath = "C:\Temp\MailboxAccessReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host "`nReport exported to: $exportPath" -ForegroundColor Green
    
    # Optional: GridView
    $results | Out-GridView -Title "Mailbox Access Report"
    
} else {
    Write-Host "`nNo mailbox access found for the specified users" -ForegroundColor Yellow
}

Disconnect-ExchangeOnline -Confirm:$false
Write-Host "`nScript complete!" -ForegroundColor Cyan
