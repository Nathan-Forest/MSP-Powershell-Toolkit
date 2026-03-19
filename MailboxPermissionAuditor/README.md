# Mailbox Permission Auditor

Comprehensive PowerShell scripts for auditing delegated mailbox permissions across Microsoft 365 tenants. Identifies FullAccess (Read/Manage), SendAs, and SendOnBehalf permissions for security compliance and access reviews.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Exchange Online](https://img.shields.io/badge/Exchange%20Online-Required-orange)

---

## Overview

These scripts automate the auditing of mailbox delegation across your Microsoft 365 tenant, generating detailed CSV reports for:
- Security audits and compliance reporting
- User offboarding verification
- Least privilege access reviews
- Shared mailbox permission management

**Problem:** Manually checking mailbox permissions across hundreds or thousands of mailboxes is time-prohibitive and error-prone.

**Solution:** Automated scanning with comprehensive reporting, saving 8+ hours per quarterly audit.

---

## Scripts Included

### 1. `Get-TenantMailboxPermissions.ps1` - Comprehensive Tenant-Wide Audit

**Use this when:**
- ✅ You need a complete security audit of ALL mailboxes
- ✅ Performing quarterly compliance reviews
- ✅ Investigating potential unauthorized access
- ✅ Documenting all delegated permissions tenant-wide
- ✅ You have time for a full scan (30-90 minutes depending on tenant size)

**What it audits:**
- All user mailboxes (regular accounts)
- All shared mailboxes
- All room/equipment mailboxes
- All distribution group mailboxes

**Output:**
- Single comprehensive CSV with all permissions
- Summary statistics by permission type
- Top 10 most delegated mailboxes
- Interactive GridView for filtering

**Typical runtime:** 30-90 minutes for large tenants (1000+ mailboxes)

---

### 2. `Get-SharedMailboxPermissions.ps1` - Shared Mailboxes Only

**Use this when:**
- ✅ You only need to audit shared mailboxes (most common use case)
- ✅ Monthly shared mailbox access reviews
- ✅ Quick security checks
- ✅ You need results fast (5-10 minutes)
- ✅ Onboarding/offboarding focused on shared mailbox access

**What it audits:**
- Shared mailboxes only (not user mailboxes)

**Output:**
- Focused CSV report on shared mailbox delegations
- Simpler, faster results
- Interactive GridView for analysis

**Typical runtime:** 5-10 minutes (most tenants have 50-200 shared mailboxes)

---

## Quick Comparison

| Feature | Tenant-Wide Audit | Shared Mailboxes Only |
|---------|-------------------|----------------------|
| **Runtime** | 30-90 minutes | 5-10 minutes |
| **Mailboxes Scanned** | All types | Shared only |
| **Use Case** | Comprehensive security audit | Quick shared mailbox review |
| **When to Use** | Quarterly compliance | Monthly checks, offboarding |
| **Output Size** | Large (1000+ rows typical) | Smaller (100-300 rows typical) |
| **Complexity** | More detailed | Simpler, focused |

**Recommendation:** Start with the **Shared Mailboxes script** for regular monitoring. Use the **Tenant-Wide script** quarterly or when deep-diving security issues.

---

## Prerequisites

### Required PowerShell Module
```powershell
Install-Module ExchangeOnlineManagement -Force
```

### Required Permissions
You must run these scripts with an account that has:
- **Exchange Administrator** OR
- **Global Reader** OR
- **Global Administrator**

### System Requirements
- PowerShell 5.1 or higher
- Windows 10/11 or Windows Server 2016+
- Internet connectivity to Exchange Online

---

## Installation & Setup

1. **Download the scripts** to a folder (e.g., `C:\Scripts\MailboxAudit\`)
2. **Install required module:**
   ```powershell
   Install-Module ExchangeOnlineManagement -Force
   ```
3. **Run the appropriate script** based on your needs

---

## Usage

### Option 1: Comprehensive Tenant-Wide Audit

**When to run:** Quarterly, or when investigating security issues

```powershell
# Navigate to script folder
cd C:\Scripts\MailboxAudit

# Run the comprehensive audit
.\Get-TenantMailboxPermissions.ps1
```

**What happens:**
1. Prompts you to sign in to Exchange Online
2. Fetches all mailboxes in the tenant
3. Checks each mailbox for:
   - FullAccess permissions (Read/Manage)
   - SendAs permissions
   - SendOnBehalf permissions
4. Displays progress percentage
5. Shows summary statistics
6. Exports to CSV: `.\TenantMailboxPermissions_YYYYMMDD_HHMMSS.csv`
7. Opens interactive GridView for filtering

**Expected runtime:** 
- 100 mailboxes = ~10 minutes
- 500 mailboxes = ~30 minutes
- 2000 mailboxes = ~90 minutes

---

### Option 2: Shared Mailboxes Only

**When to run:** Monthly, or during user offboarding

```powershell
# Navigate to script folder
cd C:\Scripts\MailboxAudit

# Run the shared mailbox audit
.\Get-SharedMailboxPermissions.ps1
```

**What happens:**
1. Prompts you to sign in to Exchange Online
2. Fetches only shared mailboxes
3. Checks each for FullAccess and SendAs permissions
4. Shows progress
5. Exports to CSV: `.\SharedMailboxPermissions_YYYYMMDD_HHMMSS.csv`
6. Opens interactive GridView

**Expected runtime:** 5-10 minutes (most tenants)

---

## Understanding the Output

### CSV Report Columns

**Tenant-Wide Script:**
| Column | Description |
|--------|-------------|
| `MailboxName` | Display name of the mailbox |
| `MailboxEmail` | Email address of the mailbox |
| `MailboxType` | UserMailbox, SharedMailbox, RoomMailbox, etc. |
| `PermissionType` | FullAccess, SendAs, or SendOnBehalf |
| `GrantedTo` | User/group who has the permission |
| `AccessRights` | Specific rights granted |
| `IsInherited` | Whether permission is inherited or explicit |

**Shared Mailbox Script:**
| Column | Description |
|--------|-------------|
| `SharedMailbox` | Name of shared mailbox |
| `Email` | Email address |
| `PermissionType` | FullAccess or SendAs |
| `GrantedTo` | Who has access |

---

### Permission Types Explained

#### FullAccess (Read/Manage)
- **What they can do:** Read all emails, send as owner, manage folders, delete items
- **Common use case:** Executive assistants, shared team mailboxes
- **Security risk:** 🔴 **HIGH** - Complete control of mailbox
- **Example:** Assistant managing CEO's inbox

#### SendAs
- **What they can do:** Send emails appearing to come FROM the mailbox
- **Common use case:** Department mailboxes (sales@, support@)
- **Security risk:** 🟡 **MEDIUM** - Can impersonate the mailbox
- **Example:** Sales team member sending from sales@company.com

#### SendOnBehalf
- **What they can do:** Send emails showing "User A on behalf of User B"
- **Common use case:** Assistants sending for executives
- **Security risk:** 🟢 **LOW** - Recipient sees who actually sent
- **Example:** "Assistant on behalf of CEO"

---

## Example Output

### Console Output (Tenant-Wide)
```
========================================
TENANT-WIDE MAILBOX PERMISSION AUDIT
========================================

Fetching all mailboxes...
Found 847 mailboxes to audit

[Progress: 45.3%] Processing John Smith (384 of 847)

========================================
AUDIT COMPLETE
========================================

Summary Statistics:
  Total mailboxes audited: 847
  Total delegated permissions found: 234

Permissions by Type:
Name                          Count
----                          -----
FullAccess (Read/Manage)      156
SendAs                         52
SendOnBehalf                   26

Top 10 Most Delegated Mailboxes:
Name                          Count
----                          -----
sales@company.com             12
support@company.com           8
ceo@company.com               6

✓ Full report exported to: .\TenantMailboxPermissions_20260318_142530.csv
```

---

## Common Use Cases

### Security Audit
**Goal:** Document all delegated access for compliance

**Script to use:** Tenant-Wide Audit  
**Frequency:** Quarterly  
**Action:** Review report, identify over-permissioned accounts, remediate

---

### User Offboarding
**Goal:** Ensure departed employee doesn't retain access to shared mailboxes

**Script to use:** Shared Mailboxes Only  
**Frequency:** Each termination  
**Action:** Filter GridView by departed user's name, remove their permissions

**Steps:**
1. Run `Get-SharedMailboxPermissions.ps1`
2. In GridView, filter "GrantedTo" column for departed user
3. For each row, remove their permission:
   ```powershell
   Remove-MailboxPermission -Identity "sales@company.com" -User "departed.user@company.com" -AccessRights FullAccess
   Remove-RecipientPermission -Identity "sales@company.com" -Trustee "departed.user@company.com" -AccessRights SendAs
   ```

---

### Monthly Shared Mailbox Review
**Goal:** Ensure only current team members have access

**Script to use:** Shared Mailboxes Only  
**Frequency:** Monthly  
**Action:** Review with department managers, remove unnecessary permissions

---

### Least Privilege Assessment
**Goal:** Identify users with too many permissions

**Script to use:** Tenant-Wide Audit  
**Frequency:** Semi-annually  
**Action:** Filter by "GrantedTo" to see which users have access to multiple mailboxes

**Analysis:**
```powershell
# After running audit, analyze the CSV
$report = Import-Csv "C:\Temp\TenantMailboxPermissions_*.csv"

# Find users with access to 5+ mailboxes
$report | Group-Object GrantedTo | 
    Where-Object { $_.Count -ge 5 } | 
    Select-Object Name, Count | 
    Sort-Object Count -Descending
```

---

## Troubleshooting

### "You must call the Connect-ExchangeOnline cmdlet before calling any other cmdlet"
**Problem:** Not connected to Exchange Online

**Solution:**
```powershell
Connect-ExchangeOnline -UserPrincipalName your.admin@domain.com
```

---

### Script runs slowly or times out
**Problem:** Large tenant with throttling

**Solution:**
- Script includes automatic delays every 50 mailboxes
- Run during off-hours for large tenants
- Use **Shared Mailboxes script** for faster results
- Break into batches if tenant has 5000+ mailboxes

---

### "Access Denied" errors
**Problem:** Insufficient permissions

**Solution:**
- Verify your account has Exchange Administrator or Global Reader role
- Disconnect and reconnect: `Disconnect-ExchangeOnline; Connect-ExchangeOnline`

---

### No permissions found (empty report)
**Possible causes:**
- ✅ Good news! No delegated permissions exist (rare)
- ❌ Connected to wrong tenant
- ❌ Permissions are all inherited (script filters these out)

**Verification:**
```powershell
# Check which tenant you're connected to
Get-OrganizationConfig | Select-Object Name, Identity
```

---

## Best Practices

### Before Running
✅ Schedule during off-hours for tenant-wide audits  
✅ Verify you have the right permissions  
✅ Ensure you're connected to the correct tenant  
✅ Confirm C:\Temp folder exists (script will create if missing)  

### After Running
✅ Review the CSV export with stakeholders  
✅ Document findings and remediation actions  
✅ Keep historical reports for trend analysis  
✅ Schedule regular recurring audits  

### Security Recommendations
✅ Remove FullAccess permissions when SendAs is sufficient  
✅ Use SendOnBehalf instead of SendAs when possible  
✅ Regularly review and remove stale delegations  
✅ Document business justification for all FullAccess grants  

---

## Output File Locations

All reports are saved to: `.\`

**Filename format:**
- Tenant-Wide: `TenantMailboxPermissions_YYYYMMDD_HHMMSS.csv`
- Shared Only: `SharedMailboxPermissions_YYYYMMDD_HHMMSS.csv`

**Note:** The `.gitignore` file prevents these from being accidentally committed to source control.

---

## Business Impact

**Time Savings:**
- Manual audit: 8+ hours for 500 mailboxes
- Automated audit: 30 minutes
- **Savings: 7.5 hours per quarterly audit**

**Security Benefits:**
- Identify over-permissioned accounts before security incidents
- Ensure compliance with least privilege policies
- Document all delegated access for auditors
- Quickly verify offboarding completeness

**Real-World Example:**  
Quarterly audit across a 500-mailbox tenant identified:
- 12 departed employees still with FullAccess to shared mailboxes
- 8 users with unnecessary permissions granted years ago
- 3 external contractors with lingering access post-contract

**Result:** Removed 23 unnecessary permissions, reducing security risk and ensuring compliance.

---

## Technical Details

**Language:** PowerShell 5.1+  
**API:** Exchange Online Management PowerShell  
**Authentication:** OAuth 2.0 Modern Authentication  
**Rate Limiting:** Automatic throttling protection (2-second delays every 50 mailboxes)  
**Error Handling:** Try/catch blocks with graceful continuation on per-mailbox failures  

---

## Related Tools

Other tools in the [MSP PowerShell Toolkit](../):
- **[License Group Auditor](../LicenseGroupAuditor/)** - Identify users in multiple license groups
- **SharePoint Storage Monitor** *(coming soon)* - Monitor storage consumption
- **Disabled User Auditor** *(coming soon)* - Find disabled accounts with active resources

---

## Version History

**Version 1.0** (March 2026)
- Initial release
- Tenant-wide audit script
- Shared mailbox focused script
- Comprehensive CSV reporting
- GridView integration

---

## Author

**Nathan Forest**  
Support Analyst → Backend Developer  
Brennan IT | Brisbane, Australia

- **LinkedIn:** [linkedin.com/in/nathan-forest-australia](https://linkedin.com/in/nathan-forest-australia)
- **GitHub:** [github.com/Nathan-Forest](https://github.com/Nathan-Forest)

---

## License

MIT License - See [LICENSE](../LICENSE) for details.

---

**Questions or suggestions?** Open an issue or reach out via LinkedIn!
