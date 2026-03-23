# Duplicate License Bulk Remediation Tool

**Safe, automated removal of duplicate direct license assignments** with dry-run mode, rollback capability, and comprehensive logging.

---

## ⚠️ CRITICAL SAFETY NOTICE

**This script REMOVES license assignments from users.**

**ALWAYS run with `-DryRun` first to preview changes!**

```powershell
# CORRECT - Preview first
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DryRun

# Then execute
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -CreateRollbackFile
```

---

## Overview

This script completes the duplicate license management workflow:

1. **Detect** duplicates → `Find-DuplicateLicenseAssignments.ps1`
2. **Remediate** duplicates → `Remove-DuplicateLicenseAssignments.ps1` ← **This script**
3. **Verify** cleanup → Re-run detection script

**What it does:**
- Imports duplicate license report CSV
- Removes direct license assignments
- Keeps group-based assignments intact
- Logs all actions
- Creates rollback script (optional)

**What it does NOT do:**
- Remove group-based assignments
- Remove all licenses from users
- Make changes in dry-run mode

---

## Key Safety Features

### 🛡️ 1. Dry-Run Mode (Preview Only)
```powershell
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DryRun
```

**Shows what WOULD happen without making changes:**
```
[1/47] john.smith@company.com - Microsoft 365 F3
  ℹ [DRY RUN] Would remove: Microsoft 365 F3 (SKU: SPE_F3)
```

**Always run dry-run first!**

---

### 🔄 2. Rollback Script Generation
```powershell
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -CreateRollbackFile
```

**Generates PowerShell script to undo ALL changes:**
```powershell
# Rollback_Script_20260320_110530.ps1
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Restore Microsoft 365 F3 to john.smith@company.com
Write-Host "Restoring Microsoft 365 F3 to john.smith@company.com"
Set-MgUserLicense -UserId "abc123..." -AddLicenses @{SkuId = "..."} -RemoveLicenses @()
```

**Keep this file safe!** It's your undo button.

---

### 📝 3. Comprehensive Logging
Every action logged to timestamped file:
```
[2026-03-20 11:05:30] [Info] === License Remediation Started ===
[2026-03-20 11:05:35] [Success] SUCCESS - Removed Microsoft 365 F3 from john.smith@company.com
[2026-03-20 11:05:37] [Error] FAILED - jane.doe@company.com - Office 365 E3: User not found
```

**Audit trail for compliance and troubleshooting**

---

### ✅ 4. Confirmation Prompts
```powershell
⚠ WARNING: This will remove direct license assignments!
Group-based assignments will remain intact.

Do you want to proceed? (yes/no):
```

**Type "yes" to proceed** (anything else cancels)

Skip prompts with `-SkipConfirmation` (use carefully!)

---

### 🎯 5. Filtering Options

**Only disabled accounts** (safest for first run):
```powershell
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DisabledAccountsOnly
```

**Specific licenses only:**
```powershell
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -LicenseFilter "SPE_F3,POWER_BI_PRO"
```

---

## Prerequisites

### Required Module
```powershell
Install-Module Microsoft.Graph.Users -Force
```

### Required Permission
- **User.ReadWrite.All** - Required to remove license assignments

**Note:** This is a WRITE permission (higher than read-only tools)

### Minimum Requirements
- PowerShell 5.1 or higher
- Microsoft 365 tenant with duplicates detected
- CSV report from `Find-DuplicateLicenseAssignments.ps1`

---

## Installation

**Prerequisites:**
1. Run `Find-DuplicateLicenseAssignments.ps1` first
2. Generate duplicate license report CSV
3. Review report to confirm duplicates exist

**Then:**
```powershell
# Download remediation script
# Place in same folder as detection script
cd MSP-PowerShell-Toolkit/DuplicateLicenseDetector
```

---

## Usage

### Step-by-Step Workflow

**STEP 1: Detect Duplicates**
```powershell
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate
# Output: Duplicate_License_Report_20260320_105432.csv
```

**STEP 2: Preview Remediation (DRY RUN)**
```powershell
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "C:\Temp\Duplicate_License_Report_20260320_105432.csv" -DryRun
```

Review dry-run output carefully!

**STEP 3: Execute Remediation**
```powershell
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "C:\Temp\Duplicate_License_Report_20260320_105432.csv" -CreateRollbackFile
```

**STEP 4: Verify Cleanup**
```powershell
.\Find-DuplicateLicenseAssignments.ps1
# Should show: "NO DUPLICATES FOUND ✓"
```

---

## Usage Examples

### Example 1: Safe First-Time Remediation

**Most conservative approach:**
```powershell
# Step 1: Detect
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts

# Step 2: Dry run on DISABLED accounts only
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DisabledAccountsOnly -DryRun

# Step 3: Execute on disabled accounts only
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DisabledAccountsOnly -CreateRollbackFile

# Step 4: Verify
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts
```

**Why this is safest:**
- Disabled accounts can't use licenses anyway
- No impact on active users
- Immediate cost savings
- Low risk

---

### Example 2: Full Tenant Cleanup

**After testing on disabled accounts:**
```powershell
# Step 1: Detect all duplicates
.\Find-DuplicateLicenseAssignments.ps1

# Step 2: Full dry run
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DryRun

# Step 3: Execute with rollback
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -CreateRollbackFile

# Step 4: Verify
.\Find-DuplicateLicenseAssignments.ps1
```

---

### Example 3: Specific License Cleanup

**Target high-cost licenses:**
```powershell
# Get report
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate

# Dry run - E3 licenses only
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -LicenseFilter "SPE_E3,ENTERPRISEPACK" -DryRun

# Execute
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -LicenseFilter "SPE_E3,ENTERPRISEPACK" -CreateRollbackFile
```

---

### Example 4: Unattended/Scheduled Remediation

**For automated monthly cleanup:**
```powershell
# Skip confirmations, create rollback
.\Remove-DuplicateLicenseAssignments.ps1 `
    -CsvPath "report.csv" `
    -DisabledAccountsOnly `
    -SkipConfirmation `
    -CreateRollbackFile `
    -ExportPath "C:\Logs"
```

**⚠️ Only use -SkipConfirmation after thorough testing!**

---

## Output

### Console Output

**Dry Run:**
```
========================================
REMEDIATION SUMMARY
========================================

Records to process: 47

By License Type:
  Microsoft 365 F3: 28
  Office 365 E3: 15
  Power BI Pro: 10

Estimated Savings After Remediation:
  Monthly: $635.00
  Annual: $7,620.00

========================================
PROCESSING LICENSE REMOVALS
========================================

[1/47] john.smith@company.com - Microsoft 365 F3
  ℹ [DRY RUN] Would remove: Microsoft 365 F3 (SKU: SPE_F3)

[2/47] jane.doe@company.com - Office 365 E3
  ℹ [DRY RUN] Would remove: Office 365 E3 (SKU: ENTERPRISEPACK)

...

========================================
REMEDIATION COMPLETE
========================================

DRY RUN SUMMARY:
  Records Processed: 47
  Would be Removed: 47
  Would be Skipped: 0

No actual changes were made. Run without -DryRun to execute.
```

---

**Real Execution:**
```
========================================
PROCESSING LICENSE REMOVALS
========================================

[1/47] john.smith@company.com - Microsoft 365 F3
  ✓ Removed direct assignment successfully

[2/47] jane.doe@company.com - Office 365 E3
  ✓ Removed direct assignment successfully

[3/47] bob.wilson@company.com - Power BI Pro
  ✗ Failed to remove license: User not found

...

========================================
REMEDIATION COMPLETE
========================================

RESULTS:
  Successfully Removed: 45
  Failed: 2
  Skipped: 0
  Total Processed: 47

ACHIEVED SAVINGS:
  Monthly: $620.00
  Annual: $7,440.00

OUTPUT FILES:
  Results: C:\Temp\Remediation_Results_20260320_110530.csv
  Log: C:\Temp\License_Remediation_Log_20260320_110530.txt
  Rollback Script: C:\Temp\Rollback_Script_20260320_110530.ps1

  ⚠ Keep the rollback script in case you need to undo changes!

NEXT STEPS:
  1. Verify group-based assignments are working
  2. Run Find-DuplicateLicenseAssignments.ps1 to confirm zero duplicates
  3. Test rollback script if needed (review before executing)
```

---

### Generated Files

**1. Results CSV**
```csv
UserEmail,LicenseName,LicenseSKU,Action,Reason,Timestamp
john.smith@company.com,Microsoft 365 F3,SPE_F3,REMOVED,Direct assignment removed (group assignment retained),2026-03-20 11:05:35
jane.doe@company.com,Office 365 E3,ENTERPRISEPACK,REMOVED,Direct assignment removed (group assignment retained),2026-03-20 11:05:37
bob.wilson@company.com,Power BI Pro,POWER_BI_PRO,FAILED,User not found,2026-03-20 11:05:39
```

**2. Log File**
```
[2026-03-20 11:05:30] [Info] === License Remediation Started ===
[2026-03-20 11:05:30] [Info] CSV Source: C:\Temp\Duplicate_License_Report_20260320_105432.csv
[2026-03-20 11:05:35] [Success] SUCCESS - Removed Microsoft 365 F3 from john.smith@company.com
[2026-03-20 11:05:37] [Success] SUCCESS - Removed Office 365 E3 from jane.doe@company.com
[2026-03-20 11:05:39] [Error] FAILED - bob.wilson@company.com - Power BI Pro: User not found
```

**3. Rollback Script** (if `-CreateRollbackFile` used)
```powershell
# Rollback Script - Generated 2026-03-20 11:05:30
# This script will re-apply licenses that were removed
# USE WITH CAUTION - Review before executing

Connect-MgGraph -Scopes "User.ReadWrite.All"

# Restore Microsoft 365 F3 to john.smith@company.com
Write-Host "Restoring Microsoft 365 F3 to john.smith@company.com"
Set-MgUserLicense -UserId "abc123..." -AddLicenses @{SkuId = "def456..."} -RemoveLicenses @()

# Restore Office 365 E3 to jane.doe@company.com
Write-Host "Restoring Office 365 E3 to jane.doe@company.com"
Set-MgUserLicense -UserId "ghi789..." -AddLicenses @{SkuId = "jkl012..."} -RemoveLicenses @()
```

---

## Parameters Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `-CsvPath` | String | Path to duplicate report CSV | **Required** |
| `-DryRun` | Switch | Preview without making changes | False |
| `-DisabledAccountsOnly` | Switch | Only process disabled accounts | False |
| `-SkipConfirmation` | Switch | Skip "Are you sure?" prompts | False |
| `-LicenseFilter` | String | Comma-separated SKU list | None |
| `-ExportPath` | String | Output directory for logs | C:\Temp |
| `-CreateRollbackFile` | Switch | Generate undo script | False |

---

## Troubleshooting

### "User not found" errors

**Cause:** User was deleted between detection and remediation

**Solution:** This is harmless - license is already gone with the user

---

### "Insufficient privileges" error

**Cause:** Missing `User.ReadWrite.All` permission

**Solution:** 
1. Disconnect: `Disconnect-MgGraph`
2. Reconnect with correct scope: `Connect-MgGraph -Scopes "User.ReadWrite.All"`
3. Or request Global Administrator to grant permission

---

### Rollback script fails

**Cause:** SKU IDs changed or licenses no longer available

**Solution:**
1. Check available licenses: `Get-MgSubscribedSku`
2. Manually verify which licenses to restore
3. Test on one user first

---

### Script times out

**Cause:** Processing many users (500+) with API throttling

**Solution:**
- This is normal behavior
- Script includes built-in delays (500ms per user)
- For large batches, run during off-hours
- Consider processing in smaller batches using filters

---

## Best Practices

### 1. Always Start with Dry Run
```powershell
# CORRECT workflow
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DryRun
# Review output
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -CreateRollbackFile
```

### 2. Test on Disabled Accounts First
```powershell
# Safest first execution
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -DisabledAccountsOnly -CreateRollbackFile
```

### 3. Always Create Rollback Files
```powershell
# Include -CreateRollbackFile for safety
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -CreateRollbackFile
```

### 4. Keep Logs for Compliance
```powershell
# Export to dedicated folder
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath "report.csv" -ExportPath "C:\Compliance\Logs"
```

### 5. Verify After Remediation
```powershell
# Always verify cleanup worked
.\Find-DuplicateLicenseAssignments.ps1
# Should show: "NO DUPLICATES FOUND ✓"
```

---

## Rollback Procedure

**If you need to undo changes:**

### Step 1: Locate Rollback Script
```
C:\Temp\Rollback_Script_20260320_110530.ps1
```

### Step 2: Review Before Executing
```powershell
# Open in editor and verify commands
notepad "C:\Temp\Rollback_Script_20260320_110530.ps1"
```

### Step 3: Execute Rollback
```powershell
# Connect to Graph
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Run rollback script
& "C:\Temp\Rollback_Script_20260320_110530.ps1"
```

### Step 4: Verify Restoration
```powershell
# Check specific users
Get-MgUser -UserId "john.smith@company.com" -Property AssignedLicenses
```

---

## Integration with Detection Script

**Complete workflow:**

```powershell
# 1. Monthly Detection
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate -IncludeDisabledAccounts

# 2. Review Report
# Open CSV, review violations

# 3. Dry Run Remediation
$reportPath = "C:\Temp\Duplicate_License_Report_20260320_105432.csv"
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath $reportPath -DryRun

# 4. Execute Remediation
.\Remove-DuplicateLicenseAssignments.ps1 -CsvPath $reportPath -CreateRollbackFile

# 5. Verify Cleanup
.\Find-DuplicateLicenseAssignments.ps1
```

---

## Scheduled Automation

**Monthly automated cleanup (disabled accounts only):**

```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
-File C:\Scripts\Monthly-License-Cleanup.ps1
"@

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6am

Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName "Monthly License Cleanup" `
    -Description "Automated duplicate license removal"
```

**Monthly-License-Cleanup.ps1:**
```powershell
# Detect duplicates
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts

# Get most recent report
$report = Get-ChildItem "C:\Temp\Duplicate_License_Report_*.csv" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

# Remediate (disabled accounts only, unattended)
.\Remove-DuplicateLicenseAssignments.ps1 `
    -CsvPath $report.FullName `
    -DisabledAccountsOnly `
    -SkipConfirmation `
    -CreateRollbackFile

# Email results to IT team
$results = Import-Csv "C:\Temp\Remediation_Results_*.csv" | Sort-Object Timestamp -Descending | Select-Object -First 1
Send-MailMessage -To "it@company.com" -Subject "License Cleanup Complete" -Attachments $results
```

---

## Security Considerations

### Permission Management
- Script requires `User.ReadWrite.All` (admin permission)
- Only run with approved admin accounts
- Do not save credentials in scripts

### Audit Trail
- All actions logged with timestamps
- Logs include success/failure reasons
- Keep logs for compliance (6-12 months)

### Change Control
- Follow organization's change management process
- Document reason for remediation
- Get approval for bulk changes
- Schedule during maintenance windows

---

## Related Tools

Complete duplicate license management suite:
- **Find-DuplicateLicenseAssignments.ps1** - Detection
- **Remove-DuplicateLicenseAssignments.ps1** - Remediation (this script)
- **Get-LicenseAssignmentReport.ps1** - Comprehensive analysis

[View full MSP PowerShell Toolkit →](https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit)

---

## Contributing

This is part of a personal portfolio project, but feedback is welcome!

**Found a bug?** Open an issue!
**Have a safety suggestion?** Let me know!

---

## License

MIT License - See repository LICENSE file for details.

---

## About the Author

**Nathan Forest**  
Support Analyst → Backend Developer & DevOps Engineer  
Brennan IT | Brisbane, Australia

**Connect:**
- LinkedIn: [linkedin.com/in/nathan-forest-australia](https://linkedin.com/in/nathan-forest-australia)
- GitHub: [github.com/Nathan-Forest](https://github.com/Nathan-Forest)

---

**Questions?** Open an issue on GitHub or reach out via LinkedIn!

**⚠️ REMEMBER: Always run with -DryRun first!**
