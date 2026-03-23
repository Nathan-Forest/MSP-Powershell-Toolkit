# Duplicate License Assignment Detector

**Fast, focused compliance tool** that identifies Microsoft 365 licenses assigned BOTH directly AND via group membership - representing pure waste and immediate cost-saving opportunities.

## Business Problem

**The Issue:**
- Users accidentally receive the same license from both direct assignment AND group membership
- Each duplicate costs your organization $10-$60/month per license
- Typical organizations have 5-15% duplicate license waste
- Manual detection is nearly impossible at scale

**Example:**
```
John Smith has Microsoft 365 F3:
  ✓ Assigned by group: SG-Access-Foreman-DL
  ✗ ALSO directly assigned manually
  
Result: Paying for 2 licenses, using only 1
Cost: $12/month wasted = $144/year per user
```

**Solution:** Automated detection with clear remediation actions and cost impact calculation.

---

## Key Features

### 🎯 **Fast & Focused**
- Scans only for violations (not comprehensive analysis)
- ~5 minutes for 1000 users
- Clear, actionable output

### 💰 **Cost Impact Calculation**
```
Total Duplicate Licenses: 47
Estimated Monthly Waste: $628
Estimated Annual Waste: $7,536

Potential ROI: $7,536 annual savings for 15 minutes of cleanup
```

### 📊 **Comprehensive Reporting**
- User details (name, email, job title, department, office)
- License name (friendly, not SKU IDs)
- Which group(s) assigned the license
- Account status (Enabled/Disabled)
- Last sign-in date
- Cost per duplicate
- Recommended remediation actions

### 🚨 **Priority Flagging**
Highlights **disabled accounts** with duplicate licenses:
```
⚠ PRIORITY: 12 disabled accounts with duplicate licenses!
Remove ALL licenses from disabled accounts immediately.
```

---

## Why Duplicates Happen

**Common Causes:**
1. **Legacy direct assignments** - Licenses assigned before group-based licensing was implemented
2. **Admin errors** - Manually assigning licenses without checking group membership
3. **Migration artifacts** - Direct assignments left over from migrations
4. **Emergency access** - Temporary direct assignments that were never removed
5. **Automation gaps** - Scripts that assign licenses without checking existing assignments

---

## Prerequisites

### Required Modules
```powershell
Install-Module Microsoft.Graph.Users -Force
Install-Module Microsoft.Graph.Groups -Force
```

### Required Permissions
- **User.Read.All** - Read all user properties
- **Group.Read.All** - Read group information
- **AuditLog.Read.All** - Read last sign-in data (optional but recommended)

### Minimum Requirements
- PowerShell 5.1 or higher
- Microsoft 365 tenant
- Global Reader or User Administrator role

---

## Installation

1. **Download the script:**
   ```powershell
   git clone https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit.git
   cd MSP-PowerShell-Toolkit/DuplicateLicenseDetector
   ```

2. **Install required modules:**
   ```powershell
   Install-Module Microsoft.Graph.Users -Force
   Install-Module Microsoft.Graph.Groups -Force
   ```

3. **Verify installation:**
   ```powershell
   Get-Module -ListAvailable Microsoft.Graph.*
   ```

---

## Usage

### Basic Usage

**Default (enabled accounts only):**
```powershell
.\Find-DuplicateLicenseAssignments.ps1
```

**Include disabled accounts:**
```powershell
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts
```

**Show cost estimates:**
```powershell
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate
```

**Everything combined:**
```powershell
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts -ShowCostEstimate -ExportPath ".\Reports"
```

---

## Output

### Console Summary

**When violations found:**
```
========================================
DUPLICATE LICENSE VIOLATIONS FOUND
========================================

Total Users with Duplicates: 47
Total Duplicate Licenses: 53

Cost Impact:
  Estimated Monthly Waste: $635.00
  Estimated Annual Waste: $7,620.00

By License Type:
  Microsoft 365 F3: 28 duplicates ($12/month each)
  Office 365 E3: 15 duplicates ($20/month each)
  Power BI Pro: 10 duplicates ($9.99/month each)

Top Groups Causing Duplicates:
  SG-Access-Foreman-DL: 18 users
  IT-Admins: 12 users
  Frontline-Workers: 9 users

Account Status:
  Enabled: 41
  Disabled: 6

  ⚠ PRIORITY: 6 disabled accounts with duplicate licenses!
  Remove ALL licenses from disabled accounts immediately.

========================================
RECOMMENDED ACTIONS
========================================

1. Remove direct assignments (keep group-based licensing)
   → Group-based licensing is automated and easier to manage

2. For disabled accounts, remove ALL licenses
   → Reclaim licenses for active users

3. Potential savings after cleanup:
   → Monthly: $635.00
   → Annual: $7,620.00

✓ Detailed report exported to: C:\Temp\Duplicate_License_Report_20260320_105432.csv
```

---

**When no violations found:**
```
========================================
NO DUPLICATES FOUND ✓
========================================

Great news! No duplicate license assignments detected.
All licenses are assigned either directly OR via group, but not both.

✓ Compliance report exported to: C:\Temp\Duplicate_License_Report_20260320_105432.csv
```

---

### CSV Report

**File:** `Duplicate_License_Report_YYYYMMDD_HHMMSS.csv`

**Columns:**
- **UserName** - Display name
- **Email** - User principal name
- **JobTitle** - Job title
- **Department** - Department
- **Office** - Office location
- **LicenseName** - Friendly name (e.g., "Microsoft 365 F3")
- **LicenseSKU** - SKU part number
- **DirectlyAssigned** - "Yes" (always, since this is a duplicate report)
- **GroupAssigned** - "Yes" (always, since this is a duplicate report)
- **AssignedByGroups** - Group name(s) that assigned the license
- **GroupIds** - Azure AD group ID(s)
- **TotalAssignments** - Number of times this license is assigned (typically 2)
- **AccountStatus** - "Enabled" or "Disabled"
- **LastSignIn** - Last sign-in date/time or "Never / Not Available"
- **MonthlyCostPerLicense** - Estimated monthly cost
- **AnnualCostPerLicense** - Estimated annual cost
- **RecommendedAction** - Suggested remediation
- **UserId** - Azure AD user object ID

**Sample Data:**
```csv
UserName,Email,LicenseName,DirectlyAssigned,GroupAssigned,AssignedByGroups,AccountStatus,LastSignIn,MonthlyCostPerLicense,RecommendedAction
John Smith,john.smith@company.com,Microsoft 365 F3,Yes,Yes,SG-Access-Foreman-DL,Enabled,2026-03-19T08:45:23Z,12.00,Remove direct assignment (keep group-based)
Jane Doe,jane.doe@company.com,Office 365 E3,Yes,Yes,IT-Admins,Disabled,2025-12-15T14:23:11Z,20.00,Remove direct assignment (keep group-based)
```

---

### GridView Display

Interactive window allows you to:
- ✅ Sort by cost (highest waste first)
- ✅ Filter by license type
- ✅ Filter by department
- ✅ Find all disabled accounts
- ✅ Export filtered results
- ✅ Copy UserIds for bulk remediation scripts

**Tip:** Filter to `AccountStatus = "Disabled"` for immediate priority fixes.

---

## Cost Estimation

### Built-in Pricing

The script includes approximate Microsoft list prices for 30+ common licenses:

| License | Monthly Cost |
|---------|-------------|
| Microsoft 365 E3 | $36.00 |
| Microsoft 365 E5 | $57.00 |
| Microsoft 365 F1 | $10.00 |
| Microsoft 365 F3 | $12.00 |
| Office 365 E3 | $20.00 |
| Power BI Pro | $9.99 |
| Project Plan 3 | $30.00 |
| Visio Plan 2 | $15.00 |

**Note:** These are list prices. Update in the script to match your EA/CSP discounts.

### Customizing Pricing

Edit the `Get-LicenseCost` function:
```powershell
$pricingMap = @{
    "SPE_F3" = 12.00   # Your actual cost
    "SPE_E3" = 36.00   # Your actual cost
    # ... add more
}
```

---

## Common Use Cases

### Use Case 1: Monthly Compliance Check

**Goal:** Identify and fix new duplicates

**Workflow:**
```powershell
# Run monthly on the 1st
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate

# Review violations
# Fix duplicates
# Document savings
```

**Scheduling:**
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\Scripts\Find-DuplicateLicenseAssignments.ps1"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6am

Register-ScheduledTask -Action $action -Trigger $trigger `
    -TaskName "Monthly Duplicate License Check"
```

---

### Use Case 2: Pre-Migration Cleanup

**Goal:** Clean up before migrating to group-based licensing

**Steps:**
```powershell
# 1. Find all duplicates
.\Find-DuplicateLicenseAssignments.ps1

# 2. Document current state
# 3. Remove direct assignments
# 4. Verify groups are assigning correctly
# 5. Re-run to confirm zero duplicates
```

---

### Use Case 3: Cost Optimization Project

**Goal:** Quantify and eliminate license waste

**Steps:**
```powershell
# 1. Run with cost estimates
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate -IncludeDisabledAccounts

# 2. Present findings to management
#    - "We're wasting $7,620/year on duplicate licenses"
#    - "12 disabled accounts still have licenses"

# 3. Get approval for cleanup
# 4. Execute remediation
# 5. Report savings achieved
```

**Business case template:**
```
Current State:
- 47 users with duplicate licenses
- $7,620 annual waste
- 6 disabled accounts with licenses

Proposed Solution:
- Remove direct assignments (2 hours work)
- Migrate to group-based licensing
- Implement monthly monitoring

Expected Outcome:
- $7,620 annual savings
- Automated license management
- Compliance with IT policy
```

---

### Use Case 4: Offboarding Audit

**Goal:** Ensure departing employees don't have duplicate licenses

**Steps:**
```powershell
# Include disabled accounts
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts

# Filter GridView to Disabled accounts
# Remove ALL licenses from disabled accounts
# Reclaim for new hires
```

---

## Remediation Guide

### Step 1: Export the Report
```powershell
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate
```

### Step 2: Prioritize Fixes

**Priority 1 - Disabled Accounts** (Immediate)
- Remove ALL licenses
- Highest ROI (licenses are completely wasted)

**Priority 2 - High-Cost Duplicates** (This week)
- E5, E3, Project, Visio licenses
- Biggest dollar savings

**Priority 3 - Low-Cost Duplicates** (This month)
- F1, F3, E1 licenses
- Still worth fixing

### Step 3: Remove Direct Assignments

**Option A - Manual (Small scale):**
```powershell
# Connect
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Remove direct license (example)
Set-MgUserLicense -UserId "john.smith@company.com" `
    -RemoveLicenses @("cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46") `
    -AddLicenses @()

# Replace "cbdc14ab..." with actual SkuId from your tenant
```

**Option B - Bulk (Large scale):**
```powershell
# Import duplicates report
$duplicates = Import-Csv "C:\Temp\Duplicate_License_Report_20260320_105432.csv"

# Get SKU mappings
$skus = Get-MgSubscribedSku

# Process each duplicate
foreach ($dup in $duplicates) {
    $sku = $skus | Where-Object { $_.SkuPartNumber -eq $dup.LicenseSKU }
    
    Write-Host "Removing direct $($dup.LicenseName) from $($dup.Email)"
    
    Set-MgUserLicense -UserId $dup.UserId `
        -RemoveLicenses @($sku.SkuId) `
        -AddLicenses @()
    
    Start-Sleep -Seconds 2  # Throttling
}
```

### Step 4: Verify Cleanup

```powershell
# Re-run detection
.\Find-DuplicateLicenseAssignments.ps1

# Should show: "NO DUPLICATES FOUND ✓"
```

---

## Troubleshooting

### "No duplicates found" but you know there are some

**Possible causes:**
1. Duplicates only exist on disabled accounts (add `-IncludeDisabledAccounts`)
2. User has multiple group assignments (not detected as duplicate)
3. License was just removed (sync delay)

**Solution:**
```powershell
.\Find-DuplicateLicenseAssignments.ps1 -IncludeDisabledAccounts
```

---

### Script runs slowly

**Expected:**
- 1000 users = ~5 minutes
- 5000 users = ~15 minutes

**Why?** Graph API rate limiting

**Tip:** Run during off-hours for larger tenants

---

### Cost estimates seem wrong

**Solution:** Update pricing in the script:
1. Open script in editor
2. Find `Get-LicenseCost` function
3. Update prices to match your EA/CSP costs
4. Save and re-run

---

### "LastSignIn" shows "Never / Not Available"

**Causes:**
1. Missing `AuditLog.Read.All` permission
2. User has never signed in
3. Sign-in data not available

**Solution:** Request AuditLog permission or ignore this column

---

## Best Practices

### Monthly Monitoring

**Recommended schedule:**
```
Week 1: Run duplicate detector
Week 2: Fix high-priority violations
Week 3: Fix remaining violations  
Week 4: Verify cleanup
```

**Automation:**
```powershell
# Email results to IT team
$results = .\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate

if ($results.Count -gt 0) {
    Send-MailMessage -To "it-team@company.com" `
        -Subject "Duplicate Licenses Found: $($results.Count) violations" `
        -Body "See attached report" `
        -Attachments $reportPath
}
```

---

### Before/After Comparison

**Track improvement:**
```powershell
# Month 1
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate
# Result: 47 duplicates, $7,620/year waste

# Fix violations

# Month 2
.\Find-DuplicateLicenseAssignments.ps1 -ShowCostEstimate
# Result: 0 duplicates, $7,620 saved ✓
```

---

### Integration with ITSM

**Create tickets automatically:**
```powershell
$duplicates = Import-Csv $reportPath

foreach ($dup in $duplicates) {
    # Create ServiceNow ticket
    New-ServiceNowTicket -Title "Remove duplicate license" `
        -Description "User $($dup.Email) has duplicate $($dup.LicenseName)" `
        -Priority "Medium" `
        -AssignedTo "License-Team"
}
```

---

## Performance Tips

### Optimize for Large Tenants

**1. Run on enabled accounts only** (default)
- Skip disabled accounts for faster execution
- Run separate check on disabled accounts quarterly

**2. Schedule during off-hours**
- Less API traffic = faster responses
- Best for 5000+ user tenants

**3. Use report filtering instead of re-running**
- Export once, filter multiple ways in GridView/Excel
- Saves time for different analyses

---

## Related Tools

Other tools in the MSP PowerShell Toolkit:
- **License Assignment Analyzer** - Comprehensive license analysis (all modes)
- **License Group Auditor** - Find duplicate license group assignments
- **JobTitle Security Group Auditor** - Verify dynamic group rules
- **Account Status Checker** - Bulk account verification

[View full MSP PowerShell Toolkit →](https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit)

---

## Roadmap / Future Enhancements

- [ ] Auto-remediation with approval workflow
- [ ] Integration with Change Management systems
- [ ] Historical trending (duplicates over time)
- [ ] Email alerting when new duplicates detected
- [ ] Dashboard visualization (Power BI)
- [ ] Comparison with previous month's report

---

## Contributing

This is part of a personal portfolio project, but feedback is welcome!

**Found a pricing error?** Let me know!
**Have a feature request?** Open an issue!

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

**Hiring for cost optimization or automation roles?** I bring production experience identifying and eliminating waste - let's connect!
