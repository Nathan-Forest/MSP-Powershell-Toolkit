# User Mailbox Access Finder

Reverse lookup tool that identifies all mailboxes that specific users have access to. Perfect for user offboarding, security audits, and access reviews when you need to know "what can this person access?"

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Exchange Online](https://img.shields.io/badge/Exchange%20Online-Required-orange)

---

## Overview

**The Problem:**  
When employees leave or change roles, you need to know exactly which mailboxes they can access. Manually checking hundreds of mailboxes is time-consuming and error-prone.

**The Solution:**  
This script takes a CSV list of users and finds every mailbox they have access to across your entire tenant. It's the **reverse** of a full tenant audit - instead of "who has access to this mailbox?", it answers "what mailboxes can this user access?"

**Key Difference from Full Tenant Audit:**
- **Full Tenant Audit:** Scans every mailbox → reports all delegations (slow, comprehensive)
- **This Tool:** Targets specific users → shows only their access (faster, focused)

---

## When to Use This Script

✅ **User Offboarding**
- Employee is leaving - find all mailboxes to revoke access from
- Contractor engagement ending - audit and cleanup

✅ **Role Changes**
- User changing departments - verify appropriate access
- Promotion/demotion - adjust mailbox permissions accordingly

✅ **Security Audits**
- Investigate specific user's access level
- Verify high-privilege accounts don't have excessive mailbox access
- Compliance review for specific individuals

✅ **Access Reviews**
- Quarterly review of executive assistant permissions
- Audit IT admin mailbox access
- Verify service account permissions

---

## When NOT to Use This Script

❌ **Full tenant security audit** → Use [Mailbox Permission Auditor](../MailboxPermissionAuditor/) instead  
❌ **Finding who has access to one mailbox** → Use `Get-MailboxPermission` directly  
❌ **Regular compliance reporting** → Use full tenant audit for complete picture  

---

## Features

✅ **CSV-driven user list** - No script editing required  
✅ **Three permission types** - FullAccess, SendAs, SendOnBehalf  
✅ **Fast targeted scanning** - Only checks permissions for your specified users  
✅ **Professional reporting** - CSV export + interactive GridView  
✅ **Progress tracking** - Real-time progress bar  
✅ **Summary statistics** - How many mailboxes each user can access  

---

## Prerequisites

### Required PowerShell Module
```powershell
Install-Module ExchangeOnlineManagement -Force
```

### Required Permissions
Your account needs:
- **Exchange Administrator** OR
- **Global Reader** OR
- **Global Administrator**

### System Requirements
- PowerShell 5.1 or higher
- Windows 10/11 or Windows Server 2016+
- Internet connectivity to Exchange Online

---

## Installation & Setup

### Step 1: Download the Script
Save `Get-UserMailboxAccess.ps1` to a folder (e.g., `C:\Scripts\MailboxAudit\`)

### Step 2: Create Your User List CSV

Create a file named `UsersToCheck.csv` in `.\` with this format:

```csv
UserPrincipalName
john.smith@company.com
jane.doe@company.com
contractor@company.com
```

**Important:**
- First line must be exactly: `UserPrincipalName`
- One email address per line
- Email addresses must match Azure AD exactly
- Save as CSV format (not Excel .xlsx)

### Example Use Cases for User Lists:

**Offboarding Scenario:**
```csv
UserPrincipalName
departed.employee@company.com
```

**Quarterly Assistant Review:**
```csv
UserPrincipalName
assistant1@company.com
assistant2@company.com
assistant3@company.com
```

**IT Admin Audit:**
```csv
UserPrincipalName
admin1@company.com
admin2@company.com
serviceaccount@company.com
```

---

## Usage

### Basic Usage

```powershell
# Navigate to script folder
cd C:\Scripts\MailboxAudit

# Run the script
.\Get-UserMailboxAccess.ps1
```

**What happens:**
1. Prompts you to sign in to Exchange Online
2. Loads user list from `.UsersToCheck.csv`
3. Fetches all mailboxes in tenant
4. For each mailbox, checks if any of your users have access
5. Shows progress bar
6. Displays summary statistics
7. Exports to CSV: `.\MailboxAccessReport_YYYYMMDD_HHMMSS.csv`
8. Opens interactive GridView for filtering

**Expected Runtime:**
- Depends on total mailboxes in tenant, not number of users checked
- 100 mailboxes = ~2-5 minutes
- 500 mailboxes = ~10-15 minutes
- 2000 mailboxes = ~30-45 minutes

---

## Understanding the Output

### Console Output

```
Fetching all mailboxes...
Found 847 mailboxes. Checking permissions...

[Progress: 78.5%] Processing Mailbox Name (665 of 847)

========================================
MAILBOX ACCESS REPORT
========================================

Summary:
 departed.employee@company.com has access to 12 mailboxes
 contractor@company.com has access to 3 mailboxes

Detailed Results:
User                              MailboxName         PermissionType  AccessRights
----                              -----------         --------------  ------------
departed.employee@company.com     Sales Team          FullAccess      FullAccess
departed.employee@company.com     Support Queue       SendAs          SendAs
contractor@company.com            Projects Mailbox    FullAccess      FullAccess

Report exported to: C:\Temp\MailboxAccessReport_20260318_145230.csv
```

### CSV Report Columns

| Column | Description |
|--------|-------------|
| `User` | Email address of the user being checked |
| `MailboxName` | Display name of mailbox they can access |
| `MailboxEmail` | Email address of the mailbox |
| `PermissionType` | FullAccess, SendAs, or SendOnBehalf |
| `AccessRights` | Specific permissions granted |

---

## Real-World Scenarios

### Scenario 1: Employee Offboarding

**Situation:** Employee John Smith is leaving on Friday. Need to audit and remove all his mailbox access.

**Steps:**
1. Create `UsersToCheck.csv`:
   ```csv
   UserPrincipalName
   john.smith@company.com
   ```

2. Run the script:
   ```powershell
   .\Get-UserMailboxAccess.ps1
   ```

3. Review the output - shows John has access to:
   - Sales Team mailbox (FullAccess)
   - Marketing mailbox (SendAs)
   - CEO mailbox (SendOnBehalf)

4. Remove access before his last day:
   ```powershell
   # FullAccess
   Remove-MailboxPermission -Identity "Sales Team" -User "john.smith@company.com" -AccessRights FullAccess -Confirm:$false
   
   # SendAs
   Remove-RecipientPermission -Identity "Marketing" -Trustee "john.smith@company.com" -AccessRights SendAs -Confirm:$false
   
   # SendOnBehalf
   Set-Mailbox -Identity "CEO" -GrantSendOnBehalfTo @{Remove="john.smith@company.com"}
   ```

5. **Verification:** Run script again - should show 0 mailboxes

---

### Scenario 2: Quarterly Assistant Review

**Situation:** Review which mailboxes each executive assistant can access.

**Steps:**
1. Create `UsersToCheck.csv` with all assistants:
   ```csv
   UserPrincipalName
   assistant.ceo@company.com
   assistant.cfo@company.com
   assistant.coo@company.com
   ```

2. Run the script

3. Review results with management:
   - Does each assistant need access to those mailboxes?
   - Are there any unexpected permissions?
   - Should access be reduced?

4. Document findings for compliance records

---

### Scenario 3: Service Account Audit

**Situation:** Audit service account permissions for security review.

**Steps:**
1. Create `UsersToCheck.csv`:
   ```csv
   UserPrincipalName
   serviceaccount@company.com
   automationbot@company.com
   ```

2. Run script to document all mailbox access

3. Verify access is appropriate for service function

4. Keep CSV report for compliance documentation

---

## Comparison with Other Tools

### vs. Full Tenant Mailbox Permission Auditor

| Feature | User Access Finder (This Tool) | Full Tenant Auditor |
|---------|-------------------------------|---------------------|
| **Primary Question** | "What can these users access?" | "Who has access to all mailboxes?" |
| **Input** | CSV list of specific users | No input needed |
| **Output** | Permissions for specified users only | All delegations tenant-wide |
| **Speed** | Same speed regardless of user count | Slower for large tenants |
| **Best For** | Offboarding, targeted audits | Comprehensive security reviews |
| **Report Size** | Small (only specified users) | Large (all delegations) |

**Use Both Together:**
- **Quarterly:** Run full tenant auditor for comprehensive view
- **Monthly/As-needed:** Run user access finder for specific cases

---

## Customization Options

### Change CSV Location

Edit line 13 in the script:
```powershell
# Change from:
$usersToCheck = Import-Csv ".\UsersToCheck.csv" | Select-Object -ExpandProperty UserPrincipalName

# To your preferred location:
$usersToCheck = Import-Csv "C:\Scripts\MailboxAudit\UsersToCheck.csv" | Select-Object -ExpandProperty UserPrincipalName
```

### Hardcode User List (Skip CSV)

Replace lines 12-13 with:
```powershell
# Hardcoded list - no CSV needed
$usersToCheck = @(
    "user1@company.com",
    "user2@company.com",
    "user3@company.com"
)
```

### Filter by Mailbox Type

To check only shared mailboxes (faster), edit line 21:
```powershell
# Change from:
$allMailboxes = Get-Mailbox -ResultSize Unlimited

# To:
$allMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited
```

---

## Troubleshooting

### "Cannot find path 'C:\Temp\UsersToCheck.csv'"
**Problem:** CSV file doesn't exist at expected location

**Solution:**
1. Create the `C:\Temp` folder if it doesn't exist
2. Create `UsersToCheck.csv` in that folder
3. Or update the script to point to your CSV location

---

### "Property 'UserPrincipalName' cannot be found"
**Problem:** CSV doesn't have correct column header

**Solution:**
1. Open CSV in Notepad (not Excel)
2. First line must be exactly: `UserPrincipalName`
3. Save as UTF-8 encoding

---

### Script finds 0 mailboxes for a user who definitely has access
**Problem:** Email address in CSV doesn't exactly match Azure AD

**Solution:**
1. Verify exact email format:
   ```powershell
   Get-Mailbox -Identity "suspected.user@company.com" | Select UserPrincipalName
   ```
2. Copy the exact UserPrincipalName into your CSV
3. Email addresses are case-sensitive in some scenarios

---

### "You must call the Connect-ExchangeOnline cmdlet"
**Problem:** Not connected to Exchange Online

**Solution:**
```powershell
Connect-ExchangeOnline -UserPrincipalName your.admin@company.com
```

---

### Script runs very slowly
**Problem:** Large tenant with many mailboxes

**Solutions:**
- Run during off-hours
- Consider filtering to only shared mailboxes (see Customization)
- This is normal - script checks every mailbox in tenant
- For 5+ users, this is still faster than checking manually!

---

## Best Practices

### Before Running
✅ Create your CSV with exact email addresses  
✅ Verify you're connected to the correct tenant  
✅ For large tenants, run during off-hours  
✅ Ensure C:\Temp folder exists  

### During Offboarding
✅ Run script before removing user's mailbox  
✅ Document all access found  
✅ Remove permissions before disabling account  
✅ Run script again to verify 0 access  

### For Compliance
✅ Keep CSV reports for audit trail  
✅ Document business justification for access found  
✅ Schedule regular reviews (quarterly for assistants, annually for others)  
✅ Compare reports over time to track access changes  

---

## Output File Locations

Reports are saved to: `.\`

**Filename format:**
- `MailboxAccessReport_YYYYMMDD_HHMMSS.csv`

**Example:** `MailboxAccessReport_20260318_145230.csv`

**Note:** The `.gitignore` file prevents these from being accidentally committed to source control.

---

## Security Considerations

### What This Script Can Reveal

🔴 **High-Risk Findings:**
- Service accounts with FullAccess to executive mailboxes
- Departed employees still retaining access
- Contractors with broad mailbox permissions

🟡 **Medium-Risk Findings:**
- Users with access to mailboxes outside their department
- Assistants with SendAs to multiple executives
- Temporary permissions that weren't removed

🟢 **Expected Findings:**
- Executive assistants with FullAccess to their manager
- Department heads with SendOnBehalf to team mailboxes
- IT admins with appropriate access

---

## Business Impact

**Time Savings:**
- Manual offboarding mailbox check: 2-4 hours
- Automated with this script: 15-30 minutes
- **Savings: 1.5-3.5 hours per offboarding**

**Security Benefits:**
- Identify orphaned permissions before security incidents
- Complete offboarding verification
- Compliance documentation for audits
- Reduced risk of unauthorized access

**Real-World Example:**
During routine quarterly review of 5 executive assistants:
- Discovered 2 former assistants still had FullAccess (role changes from 8 months ago)
- Found 1 contractor with access to 12 mailboxes (contract ended 3 months ago)
- Identified 4 unnecessary shared mailbox delegations

**Result:** Removed 17 unnecessary permissions, preventing potential data breaches and ensuring compliance.

---

## Technical Details

**Language:** PowerShell 5.1+  
**API:** Exchange Online Management PowerShell  
**Authentication:** OAuth 2.0 Modern Authentication  
**Approach:** Reverse lookup (user-centric vs. mailbox-centric)  
**Efficiency:** O(n) where n = total mailboxes (same cost regardless of users checked)  

**Why Reverse Lookup:**
- Checking 5 specific users across 1000 mailboxes
- If we checked each user's permissions individually: 5 separate scans
- This approach: 1 scan of all mailboxes, filter for our 5 users
- Result: Faster and more efficient

---

## Related Tools

Other tools in the [MSP PowerShell Toolkit](../):
- **[Mailbox Permission Auditor](../MailboxPermissionAuditor/)** - Full tenant permission audit
- **[License Group Auditor](../LicenseGroupAuditor/)** - Identify duplicate license assignments
- **SharePoint Storage Monitor** *(coming soon)* - Monitor storage consumption

---

## Version History

**Version 1.0** (March 2026)
- Initial release
- CSV-driven user list
- Three permission types (FullAccess, SendAs, SendOnBehalf)
- GridView and CSV export

---

## Author

**Nathan Forest**  
Support Analyst → Backend Developer  
Brennan IT | Brisbane, Australia

- **LinkedIn:** [linkedin.com/in/nathanforest-b8a0a867](https://linkedin.com/in/nathan-forest-australia)
- **GitHub:** [github.com/Nathan-Forest](https://github.com/Nathan-Forest)

---

## License

MIT License - See [LICENSE](../LICENSE) for details.

---

**Questions or suggestions?** Open an issue or reach out via LinkedIn!

**Need to audit your entire tenant?** Check out the [Mailbox Permission Auditor](../MailboxPermissionAuditor/) for comprehensive reporting!
