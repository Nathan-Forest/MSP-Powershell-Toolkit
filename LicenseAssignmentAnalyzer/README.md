# License Assignment Analyzer

Advanced PowerShell tool for analyzing Microsoft 365 license assignments with **direct vs group-based assignment detection**, friendly license names, and comprehensive user details.

## Overview

This interactive script provides deep insights into how licenses are assigned in your Microsoft 365 tenant:
- ✅ **Direct assignments** - Manually assigned to individual users
- ✅ **Group-based assignments** - Automatically assigned via Azure AD group membership
- ✅ **Group identification** - Shows which group assigned each license
- ✅ **Friendly license names** - "Microsoft 365 E3" instead of "SPE_E3"
- ✅ **Comprehensive user data** - JobTitle, Department, Office, Status, Last Sign-In

---

## Business Problem

**Challenges:**
- Mixed assignment methods (direct + group) create confusion and audit difficulties
- SKU IDs (like "SPE_E3") are cryptic and non-intuitive
- No easy way to identify which groups assign licenses
- Manual audits take hours for large tenants
- Disabled accounts with direct licenses waste money

**Solution:** Automated analysis that provides a complete picture of license assignments with actionable insights for optimization and compliance.

---

## Features

### 🎯 **Three Analysis Modes**

**1. Specific License**
- Interactive menu shows all available licenses in tenant
- Select one license to analyze in detail
- Perfect for targeted audits

**2. All Licenses**
- Comprehensive tenant-wide analysis
- Reports on every license type
- Ideal for quarterly reviews

**3. CSV License List**
- Upload a list of specific licenses to check
- Batch analysis for multiple SKUs
- Great for compliance audits

---

### 📊 **Comprehensive Reporting**

**Output Columns:**
- **UserName** - Display name
- **Email** - User principal name
- **JobTitle** - User's job title
- **Department** - Department name
- **Office** - Office location
- **LicenseName** - Friendly name (e.g., "Microsoft 365 F3")
- **LicenseSKU** - SKU part number (e.g., "SPE_F3")
- **AssignmentType** - "Direct" or "Group"
- **AssignedByGroup** - Group name (if group-based)
- **GroupId** - Azure AD group ID
- **AccountStatus** - "Enabled" or "Disabled"
- **LastSignIn** - Last sign-in date/time
- **UserId** - Azure AD user object ID

---

### 🔍 **License Name Mapping**

Automatically converts 80+ SKU IDs to friendly names:

| SKU ID | Friendly Name |
|--------|---------------|
| SPE_F3 | Microsoft 365 F3 |
| SPE_E3 | Microsoft 365 E3 |
| SPE_E5 | Microsoft 365 E5 |
| ENTERPRISEPACK | Office 365 E3 |
| POWER_BI_PRO | Power BI Pro |
| VISIOCLIENT | Visio Plan 2 |
| PROJECTPROFESSIONAL | Project Plan 3 |
| ... and 70+ more |

If a SKU isn't mapped, displays the SKU PartNumber (still better than a GUID!).

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
- **Organization.Read.All** - Read tenant licenses

### Minimum Requirements
- PowerShell 5.1 or higher
- Microsoft 365 tenant
- Global Reader, Reports Reader, or User Administrator role

---

## Installation

1. **Download the script:**
   ```powershell
   # Clone from GitHub
   git clone https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit.git
   cd MSP-PowerShell-Toolkit/LicenseAssignmentAnalyzer
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

**Run the script:**
```powershell
.\Get-LicenseAssignmentReport.ps1
```

**You'll see an interactive menu:**
```
========================================
License Assignment Analyzer
========================================

Select analysis mode:

  1. Analyze a specific license
  2. Analyze all licenses
  3. Analyze licenses from CSV file
  Q. Quit

Enter your choice (1-3 or Q):
```

---

### Mode 1: Specific License

**Steps:**
1. Choose option `1`
2. View list of all licenses in your tenant
3. Enter the number of the license to analyze
4. Script analyzes only that license

**Example:**
```
Available Licenses in Tenant:
==============================

1. Microsoft 365 F3
   SKU: SPE_F3
   Assigned: 247 / 500

2. Microsoft 365 E3
   SKU: SPE_E3
   Assigned: 89 / 100

3. Power BI Pro
   SKU: POWER_BI_PRO
   Assigned: 45 / 50

Enter license number to analyze (1-3): 1

✓ Analyzing: Microsoft 365 F3
```

---

### Mode 2: All Licenses

**Steps:**
1. Choose option `2`
2. Script analyzes all license types in tenant
3. Comprehensive report generated

**Best for:**
- Quarterly license audits
- Tenant-wide optimization projects
- Understanding overall license distribution

**Runtime:** 5-15 minutes for large tenants (1000+ users)

---

### Mode 3: CSV License List

**Steps:**
1. Create a CSV file with licenses to check
2. Choose option `3`
3. Enter path to CSV file
4. Script analyzes only listed licenses

**CSV Format:**
```csv
SkuPartNumber
SPE_F3
ENTERPRISEPACK
POWER_BI_PRO
```

**Alternative column names supported:**
- `SkuId`
- `LicenseName`
- `License`

**Example:**
```powershell
Enter path to CSV file containing license SKU IDs or names: C:\Temp\licenses.csv

✓ Using column: SkuPartNumber
✓ Found 3 matching licenses from CSV
```

---

## Output

### Console Summary

```
========================================
ANALYSIS COMPLETE
========================================

Analysis Mode: Specific License
Total Users Analyzed: 512
Users with Selected License(s): 247

Assignment Type Breakdown:
  Group: 198
  Direct: 49

Account Status:
  Enabled: 235
  Disabled: 12

Top Groups Assigning Licenses:
  SG-Access-Foreman-DL: 67 users
  SG-Access-Site-Manager-SP: 43 users
  Frontline-Workers: 88 users

✓ Report exported to: .\License_Assignment_Report_20260320_101534.csv
```

---

### CSV Report

**File:** `License_Assignment_Report_YYYYMMDD_HHMMSS.csv`

**Sample data:**
```csv
UserName,Email,JobTitle,Department,Office,LicenseName,LicenseSKU,AssignmentType,AssignedByGroup,GroupId,AccountStatus,LastSignIn,UserId
John Smith,john.smith@company.com,Foreman,Operations,Brisbane,Microsoft 365 F3,SPE_F3,Group,SG-Access-Foreman-DL,abc123...,Enabled,2026-03-19T08:45:23Z,def456...
Jane Doe,jane.doe@company.com,Site Manager,Operations,Sydney,Microsoft 365 F3,SPE_F3,Direct,,,,Enabled,2026-03-20T07:12:45Z,ghi789...
Bob Wilson,bob.wilson@company.com,Admin,IT,Brisbane,Microsoft 365 E3,SPE_E3,Group,IT-Admins,jkl012...,Enabled,2026-03-20T09:34:12Z,mno345...
```

---

### GridView Display

Interactive window allows you to:
- ✅ Filter by any column
- ✅ Sort by AssignmentType, Department, Status, etc.
- ✅ Search for specific users or groups
- ✅ Copy selected rows
- ✅ Export filtered results

**Tip:** Filter to `AssignmentType = "Direct"` to find candidates for group-based licensing migration.

---

## Common Use Cases

### Use Case 1: Find Direct Assignments for Migration

**Goal:** Migrate direct assignments to group-based licensing

**Steps:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Choose: 1. Specific license
# Select: Microsoft 365 F3
# Filter GridView: AssignmentType = "Direct"
# Export list of users to migrate
```

**Business Impact:** Automated license management, easier administration

---

### Use Case 2: Identify Wasted Licenses

**Goal:** Find disabled accounts with direct licenses

**Steps:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Choose: 2. All licenses
# Filter GridView: AccountStatus = "Disabled" AND AssignmentType = "Direct"
# Remove licenses from disabled accounts
```

**Business Impact:** Immediate cost savings (reclaim licenses)

---

### Use Case 3: Audit Specific Licenses for Compliance

**Goal:** Check who has Power BI Pro or Project licenses

**CSV File (`premium-licenses.csv`):**
```csv
SkuPartNumber
POWER_BI_PRO
PROJECTPROFESSIONAL
VISIOCLIENT
```

**Steps:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Choose: 3. CSV file
# Enter: C:\Temp\premium-licenses.csv
# Review who has premium licenses
```

**Business Impact:** Compliance verification, cost optimization

---

### Use Case 4: Department-Based License Distribution

**Goal:** See which departments use which licenses

**Steps:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Choose: 2. All licenses
# Import CSV in Excel
# Create pivot table: Rows=Department, Columns=LicenseName, Values=Count
```

**Business Impact:** Strategic planning, budgeting insights

---

### Use Case 5: Group Licensing Audit

**Goal:** Verify group-based licensing is working correctly

**Steps:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Choose: 1. Specific license
# Filter: AssignmentType = "Group"
# Verify correct groups are assigning licenses
```

**Business Impact:** Ensure automation is working as expected

---

## Advanced Features

### Last Sign-In Tracking

**Requires:** `AuditLog.Read.All` permission

Shows when users last signed in:
- Identify inactive licensed users
- Find accounts that haven't been used in 90+ days
- Optimize license allocation

**If permission is missing:** Shows "Never / Not Available"

---

### Throttling Protection

**Built-in delays:**
- 500ms pause every 100 users
- 200ms pause for assignment source lookups
- Prevents Graph API throttling errors

**For large tenants (5000+ users):**
- Script may take 20-30 minutes
- This is normal and expected
- Progress bar shows current status

---

### Error Handling

**Graceful failures:**
- Can't retrieve group name? Shows "[Unable to retrieve group name]" with Group ID
- User deleted during processing? Skips and continues
- Permission denied? Shows "Error" in AssignmentType
- Graph API timeout? Retries automatically

---

## Troubleshooting

### "Connect-MgGraph : Insufficient privileges"

**Solution:** You need higher permissions. Ask your admin for:
- Global Reader role (recommended)
- OR custom role with User.Read.All, Group.Read.All, AuditLog.Read.All

---

### "No users found with the selected license(s)"

**Possible causes:**
1. License really isn't assigned to anyone
2. Filter is excluding all users
3. Connected to wrong tenant

**Solution:** 
- Verify license is actually in use
- Check `Get-MgSubscribedSku` shows the SKU
- Confirm tenant with `Get-MgOrganization`

---

### Script runs very slowly

**Expected behavior for:**
- 1000+ users = 10-15 minutes
- 5000+ users = 20-30 minutes

**Why?** Graph API rate limiting and assignment source lookups

**Solution:** Be patient, progress bar shows status. Consider running after hours.

---

### "LastSignIn" shows "Never / Not Available"

**Causes:**
1. Missing `AuditLog.Read.All` permission
2. Sign-in data not available for user
3. User has never signed in

**Solution:** Request AuditLog permission or ignore this column

---

### CSV import fails with "Column not found"

**Solution:** Script auto-detects common column names, but if you use a custom column:
- Rename your column to: `SkuPartNumber`, `SkuId`, or `LicenseName`
- OR the script will try to use the first column

---

## Performance Tips

### Optimize for Large Tenants

**1. Use Specific License mode instead of All Licenses**
```powershell
# Faster: Analyze just F3 licenses
# Choose option 1, select F3

# Slower: Analyze all licenses
# Choose option 2
```

**2. Run during off-hours**
- Less API traffic = faster responses
- Better for 5000+ user tenants

**3. Use CSV mode for targeted audits**
- Only analyze licenses you care about
- Skip unused licenses

---

## Best Practices

### Monthly License Optimization

**Workflow:**
```powershell
# 1. Run monthly report
.\Get-LicenseAssignmentReport.ps1  # All licenses

# 2. Filter to disabled accounts with direct licenses
# 3. Remove licenses from disabled accounts
# 4. Identify direct assignments → candidates for group-based licensing
# 5. Review inactive users (LastSignIn > 90 days ago)
```

**Cost Savings:** Typically 5-15% license reclamation

---

### Before Group-Based Licensing Migration

**Audit current state:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Choose: Specific license
# Document all direct assignments
# Create migration plan
# Verify groups exist
```

**After migration:**
```powershell
.\Get-LicenseAssignmentReport.ps1
# Verify AssignmentType = "Group" for migrated users
# Confirm correct groups are assigning licenses
```

---

### Compliance Auditing

**Quarterly compliance check:**
```powershell
# Create CSV with licenses requiring audit trail
# Run script with CSV mode
# Export report
# Review AssignedByGroup matches policy
# Document findings
```

---

## Roadmap / Future Enhancements

- [ ] Add license cost calculation
- [ ] Show license usage trends over time
- [ ] Export to Excel with formatting
- [ ] Email alerting for anomalies
- [ ] Auto-remediation for disabled accounts
- [ ] Integration with ServiceNow/Jira
- [ ] Dashboard visualization (Power BI)
- [ ] Compare before/after migration reports

---

## Related Tools

Other tools in my MSP PowerShell Toolkit:
- **JobTitle Security Group Auditor** - Audit dynamic group memberships
- **License Group Auditor** - Find duplicate license group assignments ($2,300/year savings)
- **Mailbox Permission Auditor** - Security compliance for Exchange Online
- **Account Status Checker** - Bulk user status verification

[View full MSP PowerShell Toolkit →](https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit)

---

## Contributing

This is part of a personal portfolio project, but feedback and suggestions are welcome!

**Found a SKU that's not mapped?** Let me know and I'll add it!

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
