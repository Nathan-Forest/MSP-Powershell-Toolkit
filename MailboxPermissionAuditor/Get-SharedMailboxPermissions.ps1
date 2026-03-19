<#
.SYNOPSIS
    Shared Mailbox Permission Audit
.DESCRIPTION
    Faster audit focusing only on shared mailboxes
.NOTES
    Author: Nathan Forest
#>

Connect-ExchangeOnline

Write-Host "Auditing shared mailbox permissions...`n" -ForegroundColor Cyan

# Get only shared mailboxes
$sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited

Write-Host "Found $($sharedMailboxes.Count) shared mailboxes`n" -ForegroundColor Yellow

$results = @()
$count = 0

foreach ($mailbox in $sharedMailboxes) {
    $count++
    Write-Host "[$count/$($sharedMailboxes.Count)] Checking: $($mailbox.DisplayName)" -ForegroundColor Cyan
    
    # FullAccess
    $fullAccess = Get-MailboxPermission -Identity $mailbox.UserPrincipalName | 
    Where-Object { $_.User -notlike "NT AUTHORITY\*" -and $_.IsInherited -eq $false }
    
    foreach ($perm in $fullAccess) {
        $results += [PSCustomObject]@{
            SharedMailbox  = $mailbox.DisplayName
            Email          = $mailbox.UserPrincipalName
            PermissionType = "FullAccess"
            GrantedTo      = $perm.User
        }
    }
    
    # SendAs
    $sendAs = Get-RecipientPermission -Identity $mailbox.UserPrincipalName | 
    Where-Object { $_.Trustee -notlike "NT AUTHORITY\*" }
    
    foreach ($perm in $sendAs) {
        $results += [PSCustomObject]@{
            SharedMailbox  = $mailbox.DisplayName
            Email          = $mailbox.UserPrincipalName
            PermissionType = "SendAs"
            GrantedTo      = $perm.Trustee
        }
    }
}

# Display and export
Write-Host "`nFound $($results.Count) delegated permissions" -ForegroundColor Yellow
$results | Format-Table -AutoSize

$exportPath = ".\SharedMailboxPermissions_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "`n Exported to: $exportPath" -ForegroundColor Green

#$results | Out-GridView -Title "Shared Mailbox Permissions"

Disconnect-ExchangeOnline -Confirm:$false