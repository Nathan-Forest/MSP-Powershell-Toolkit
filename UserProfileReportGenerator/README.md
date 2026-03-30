# User Profile Report Generator

**Comprehensive user profile audit tool** - generates detailed HTML reports for offboarding, security reviews, and user lifecycle management with operator-friendly interactive prompts.

---

## Business Problem

**The Challenge:**
When offboarding users or conducting security audits, you need answers to dozens of questions:
- What licenses does this user have?
- Which mailboxes can they access?
- What Teams do they own?
- Who has access to their calendar?
- What devices are registered?
- Are they forwarding email externally?

**Manual Process:**
- Check 10+ different admin portals
- Query multiple PowerShell modules
- Document findings in Word/Excel
- Takes 30-60 minutes per user
- Easy to miss critical details

**Solution:** Automated comprehensive profile report in **2-5 minutes** with complete offboarding checklist and interactive operator prompts.

---

## What It Reports (14 Sections)

### **1. Basic Information** ✅
- Name, email, job title, department
- Office location, phone numbers
- Employee ID, account creation date
- Account status (enabled/disabled)
- On-prem sync status

### **2. Authentication & Security** 🔐
- Last sign-in date/time
- Last password change
- MFA status (enabled/disabled)
- MFA methods configured
- Admin roles assigned

### **3. License Assignments** 📜
- All licenses assigned
- Direct vs Group assignment
- Which group assigned each license
- Monthly cost per license
- **Total monthly license cost**

### **4. Group Memberships** 👥
Organized by type:
- **Security Groups** (count and list)
- **Microsoft 365 Groups** (count and list)
- **Distribution Lists** (count and list)

### **5. Mailbox Access** 📧 **← Interactive!**
**Operator chooses scope:**
- **[1] Shared Mailboxes Only** (Recommended - Fast)
- **[2] All Mailboxes** (Comprehensive - Slow)
- **[3] Skip** (Fastest)

Reports:
- All mailboxes user can access
- Permission types (FullAccess, SendAs, SendOnBehalf)
- Mailbox types (User, Shared, Room, Equipment)

### **6. Calendar Delegates** 📅
- Who has access to user's calendar
- Permission levels (Editor, Delegate, etc.)

### **7. Mail Forwarding Configuration** 📨
- **External forwarding status** (critical for security!)
- Forwarding address (if enabled)
- Auto-reply/OOF status

### **8. Microsoft Teams** 💬
- All Teams user is member of
- Teams where user is **Owner** (important for handoff!)
- Archived vs Active Teams

### **9. OneDrive Storage** 💾
- Storage used / total quota
- Percentage used
- OneDrive URL

### **10. Registered Devices** 💻
- All devices (computers, phones, tablets)
- Operating system & version
- Compliant status
- Managed status (Intune)
- Last sign-in per device

### **11. Management Hierarchy** 👔
- **Manager** (name, email, job title)
- **Direct Reports** (count and list)

### **12. Admin Roles** ⚠️
- All administrative roles assigned
- **Flagged prominently** (security risk)

### **13. Application Access** 🔗
- Third-party SaaS applications
- Enterprise app assignments

### **14. SharePoint Sites Owned** 📁
- Sites where user is primary owner
- Site URLs and creation dates

**Plus: Automatic Offboarding Checklist** customized to findings!

---

## Key Features

### **🎯 Interactive Operator Prompts**
**NEW!** Operator-friendly menu for mailbox checking:
- Clear descriptions of each option
- Estimated runtime shown
- Informed choice before long operations
- HTML report reflects mode used

### **⚡ Smart Performance**
- Flexible mailbox checking (Shared/All/Skip)
- OneDrive via SharePoint admin (works in MSP environments)
- Progress indicators with ETA
- Throttling protection

### **🛡️ Production Quality**
- Comprehensive error handling
- Continues on failures
- Detailed HTML output
- Professional formatting

### **📊 Business Value**
- License cost calculation
- Security risk flagging (external forwarding, admin roles)
- Automatic offboarding checklist
- Complete audit trail

---

## Prerequisites

### Required Modules
```powershell
Install-Module Microsoft.Graph.Users -Force
Install-Module Microsoft.Graph.Groups -Force
Install-Module Microsoft.Graph.Identity.SignIns -Force
Install-Module Microsoft.Graph.Sites -Force
Install-Module Microsoft.Online.SharePoint.PowerShell -Force
Install-Module ExchangeOnlineManagement -Force
Install-Module MicrosoftTeams -Force
```

### Required Permissions

**Microsoft Graph API:**
- User.Read.All
- Group.Read.All
- AuditLog.Read.All
- Sites.Read.All
- RoleManagement.Read.Directory

**SharePoint Online:**
- SharePoint Administrator (for OneDrive access)

**Exchange Online:**
- Exchange Administrator (or View-Only Organization Management)

**Microsoft Teams:**
- Teams Administrator or Global Administrator

### Minimum Requirements
- PowerShell 5.1 or higher
- Microsoft 365 tenant
- Permissions to connect to all services

---

## Installation

```powershell
# Install all required modules
Install-Module Microsoft.Graph.Users -Force
Install-Module Microsoft.Graph.Groups -Force
Install-Module Microsoft.Graph.Identity.SignIns -Force
Install-Module Microsoft.Graph.Sites -Force
Install-Module Microsoft.Online.SharePoint.PowerShell -Force
Install-Module ExchangeOnlineManagement -Force
Install-Module MicrosoftTeams -Force

# Download script
# Place in your scripts directory
```

---

## Usage

### Basic Usage

**Generate report:**
```powershell
.\Get-UserProfileReport.ps1 -UserEmail "john.smith@company.com"
```

**Generate and auto-open in browser:**
```powershell
.\Get-UserProfileReport.ps1 -UserEmail "john.smith@company.com" -OpenReport
```

**Custom output location:**
```powershell
.\Get-UserProfileReport.ps1 -UserEmail "john.smith@company.com" -ExportPath "C:\Reports"
```

---

## Interactive Mailbox Check

**During report generation, you'll see:**

```
[5/14] Checking mailbox access permissions...

========================================
Mailbox Access Check Options
========================================

This section checks which mailboxes the user has access to.
Choose the scope of the check:

  [1] Shared Mailboxes Only (Recommended - Fast)
      Checks: Shared mailboxes (support@, info@, etc.)
      Runtime: 2-15 minutes (depending on tenant size)
      Coverage: ~95% of typical offboarding scenarios

  [2] All Mailboxes (Comprehensive - Slow)
      Checks: ALL mailboxes (users, shared, rooms, equipment)
      Runtime: 10 minutes - 2 hours (depending on tenant size)
      Coverage: 100% comprehensive audit

  [3] Skip Mailbox Check (Fastest)
      Skips mailbox checking entirely
      Runtime: Instant
      Coverage: None (can run separately later)

Enter your choice (1, 2, or 3):
```

### **Which Option to Choose:**

**Option 1 - Shared Mailboxes Only** ✅ **RECOMMENDED**
- **Use for:** Normal offboarding, quick audits
- **Checks:** Shared mailboxes (support@, sales@, info@, etc.)
- **Finds:** 95% of real-world mailbox access
- **Runtime:** 2-15 minutes for most tenants

**Option 2 - All Mailboxes** ⚠️
- **Use for:** Security audits, compliance reviews, executive offboarding
- **Checks:** Every mailbox in the tenant
- **Finds:** 100% comprehensive
- **Runtime:** 10 minutes to 2+ hours (depends on tenant size)

**Option 3 - Skip** ⏭️
- **Use for:** Very large tenants, quick profile lookups
- **Checks:** Nothing
- **Runtime:** Instant
- **Note:** Can run dedicated mailbox audit separately later

---

## Performance

### **Typical Runtime by Tenant Size**

| Tenant Size | Total Mailboxes | Shared MBs | Option 1 Runtime | Option 2 Runtime |
|-------------|-----------------|------------|------------------|------------------|
| **Small** (< 200) | 150-200 | 20-40 | 1-3 min | 3-5 min |
| **Medium** (200-1000) | 500-1000 | 50-150 | 3-8 min | 10-25 min |
| **Large** (1000-5000) | 2000-5000 | 200-500 | 8-20 min | 30-90 min |
| **Enterprise** (5000+) | 5000+ | 500-1000+ | 15-30 min | 1-3 hours |

**Note:** Runtime heavily depends on number of SHARED mailboxes:
- **Well-designed tenants:** 10-15% shared mailboxes
- **Poorly-designed tenants:** 50-70% shared mailboxes (much slower!)

### **Overall Report Generation Time**

**Without mailbox check (Option 3):**
- Small/Medium tenants: 30-90 seconds
- Large/Enterprise tenants: 1-2 minutes

**With Shared Mailboxes (Option 1):**
- Small/Medium tenants: 2-10 minutes
- Large/Enterprise tenants: 10-30 minutes

**With All Mailboxes (Option 2):**
- Small tenants: 3-10 minutes
- Medium tenants: 15-30 minutes
- Large tenants: 30-120 minutes
- Enterprise tenants: 1-3+ hours

---

## Output Format

### **Professional HTML Report**

**Features:**
- Clean, modern design
- Color-coded status badges
- Organized sections with headers
- Expandable tables
- Print-friendly layout
- Summary boxes for critical info
- **Customized offboarding checklist**
- **Shows which mailbox check mode was used**

**Example Sections:**

```
========================================
USER PROFILE REPORT
========================================

John Smith
john.smith@company.com
Status: ENABLED ✓
Report Generated: 2026-03-25 10:30:15

📋 BASIC INFORMATION
  Display Name: John Smith
  Job Title: Senior Developer
  Department: Engineering
  Office: Brisbane
  Mobile Phone: +61 4XX XXX XXX
  Account Created: 2019-03-15

🔐 AUTHENTICATION & SECURITY
  Last Sign-In: 2026-03-25 08:45:23
  Last Password Change: 2025-12-10
  MFA Status: ENABLED ✓
  MFA Methods: Microsoft Authenticator, SMS
  Admin Roles: None

📜 LICENSE ASSIGNMENTS
  Total Monthly Cost: $45.00
  
  ├─ Microsoft 365 E3 (Group: LIC_E3_Users) - $36.00
  ├─ Power BI Pro (Direct) - $13.00
  └─ Visio Plan 2 (Group: LIC_Visio_Engineering) - $15.00

📧 MAILBOX ACCESS
  Check Scope: [Shared Mailboxes Only] ✓
  
  Has Access To (5 shared mailboxes):
    ├─ support@company.com (FullAccess)
    ├─ sales@company.com (FullAccess, SendAs)
    └─ ... (3 more)
    
  Note: Only shared mailboxes checked.

💬 MICROSOFT TEAMS
  Member of 6 Teams:
    ├─ Engineering General (Member)
    ├─ Project Phoenix (OWNER) ← Important!
    └─ ... (4 more)

✅ OFFBOARDING CHECKLIST
  ☐ Remove from 8 Security Groups
  ☐ Transfer access to 5 shared mailboxes
  ☐ Reassign ownership of 2 Teams ← Critical!
  ☐ Transfer 1 SharePoint site
  ☐ Transfer 45.2 GB OneDrive content
  ☐ Remove 2 calendar delegates
  ☐ Disable external forwarding (Currently OK ✓)
  ☐ Wipe 3 registered devices
  ☐ Remove admin roles (None)
  ☐ Reassign 3 direct reports
  ☐ Disable account
  ☐ Convert mailbox to shared
```

---

## Use Cases

### Use Case 1: Employee Offboarding

**Scenario:** IT manager leaving company, need complete handoff plan

**Steps:**
```powershell
# 1. Generate comprehensive report
.\Get-UserProfileReport.ps1 -UserEmail "itmanager@company.com" -OpenReport

# When prompted for mailbox check:
# Choose: [1] Shared Mailboxes Only (fast, covers typical access)

# 2. Review report sections:
#    - Admin Roles (CRITICAL - needs immediate reassignment)
#    - Teams Ownership (2 teams to reassign)
#    - SharePoint Sites (3 sites to transfer)
#    - Mailbox Access (can access 5 shared mailboxes)
#    - Direct Reports (5 people to reassign)

# 3. Use offboarding checklist to track completion
# 4. Save report for compliance/audit trail
```

**Result:** Complete offboarding in 15-30 minutes vs 2-3 hours manually

---

### Use Case 2: Security Audit

**Scenario:** User flagged in security review, need complete access audit

**Steps:**
```powershell
# Generate report
.\Get-UserProfileReport.ps1 -UserEmail "suspicious.user@company.com"

# When prompted for mailbox check:
# Choose: [2] All Mailboxes (comprehensive security audit)

# Review security-critical sections:
#   - External Forwarding (is it enabled?)
#   - Admin Roles (do they have elevated access?)
#   - MFA Status (is it configured?)
#   - Devices (unmanaged devices?)
#   - Application Access (unusual SaaS apps?)
#   - Last Sign-In (when last active?)
```

**Result:** Complete security posture in 10-30 minutes

---

### Use Case 3: Quick Profile Lookup

**Scenario:** Need quick info about user during support call

**Steps:**
```powershell
# Generate fast report
.\Get-UserProfileReport.ps1 -UserEmail "user@company.com"

# When prompted for mailbox check:
# Choose: [3] Skip (instant report)

# Get key info in 30-60 seconds:
#   - Account status
#   - Licenses
#   - Groups
#   - Manager
#   - Last sign-in
```

**Result:** Quick reference without waiting for mailbox check

---

### Use Case 4: Executive Offboarding

**Scenario:** C-level executive leaving, need complete audit

**Steps:**
```powershell
# Generate comprehensive report
.\Get-UserProfileReport.ps1 -UserEmail "ceo@company.com" -ExportPath "C:\VIP_Reports"

# When prompted for mailbox check:
# Choose: [2] All Mailboxes (find everything)

# Critical items for executives:
#   - Admin roles (often have elevated access)
#   - Teams ownership (company-wide teams)
#   - SharePoint sites (executive-level sites)
#   - Calendar delegates (EA access)
#   - External forwarding (data exfiltration risk)
```

**Result:** Nothing missed for critical users

---

## Troubleshooting

### "OneDrive not found" or "Access denied"

**Cause:** OneDrive not provisioned or URL construction issue

**Solution:**
```powershell
# Verify OneDrive URL format
$email = "user@company.com"
$tenantName = ($email.Split('@')[1]).Split('.')[0]
$username = $email.Replace('@', '_').Replace('.', '_')
$expectedUrl = "https://$tenantName-my.sharepoint.com/personal/$username"

# Try to access manually
Get-SPOSite -Identity $expectedUrl -Detailed
```

**If OneDrive truly not provisioned:**
- User may never have accessed OneDrive
- Report will show "Not Provisioned" status
- This is normal for some users

---

### Mailbox check very slow

**Cause:** Large number of shared mailboxes or tenant with unusual architecture

**Symptoms:**
- Option 1 (Shared Only) taking 30+ minutes
- Tenant has 1000+ shared mailboxes

**Example:** One enterprise tenant had 4100 shared mailboxes (70% of total) - very unusual!

**Solutions:**
1. **Use Option 3 (Skip)** - Get instant report
2. **Run overnight** - Choose Option 2 and let it run
3. **Use dedicated tool** - Run separate comprehensive mailbox audit later
4. **Document the issue** - This indicates architectural problems with the tenant

**Note:** Well-designed tenants have 10-20% shared mailboxes. If you're seeing 50-70%, the tenant has configuration issues.

---

### "Failed to connect to Microsoft Teams"

**Cause:** Teams module not connected or permissions issue

**Solution:**
```powershell
# Reconnect to Teams
Disconnect-MicrosoftTeams
Connect-MicrosoftTeams

# Verify permissions
Get-Team -User "test@company.com"
```

**Note:** Script will continue even if Teams connection fails, just skips Teams section

---

### "Failed to connect to SharePoint Online"

**Cause:** SharePoint module not installed or connection issue

**Solution:**
```powershell
# Install module
Install-Module Microsoft.Online.SharePoint.PowerShell -Force

# Connect manually
$tenantName = "yourcompany"
Connect-SPOService -Url "https://$tenantName-admin.sharepoint.com"
```

---

## Best Practices

### **1. Choose the Right Mailbox Check Mode**

**For typical offboarding:**
- Use **Option 1** (Shared Mailboxes Only)
- Fast and covers 95% of cases
- 2-15 minutes for most tenants

**For security audits:**
- Use **Option 2** (All Mailboxes)
- Comprehensive but slower
- Worth the wait for complete picture

**For quick lookups:**
- Use **Option 3** (Skip)
- Instant report
- Run dedicated mailbox audit separately if needed

---

### **2. Large Tenant Considerations**

**If you have 1000+ mailboxes:**
- Test with Option 3 first (see base runtime)
- Choose Option 1 and monitor progress
- If taking too long, cancel and use dedicated tool
- Document tenant architecture issues (70% shared mailboxes is broken!)

**If you have 5000+ mailboxes:**
- Default to Option 3 (Skip) for daily use
- Run Option 2 overnight for comprehensive audits
- Consider creating cached results (run weekly, reuse)

---

### **3. Save Reports for Audit Trail**

```powershell
# Organize by date and user
$date = Get-Date -Format 'yyyy-MM'
.\Get-UserProfileReport.ps1 -UserEmail "user@domain.com" -ExportPath "C:\OffboardingReports\$date"
```

**Retention:** Keep for 6-12 months minimum (compliance)

---

### **4. Use for Onboarding Templates**

```powershell
# Generate report for similar role
.\Get-UserProfileReport.ps1 -UserEmail "current.developer@company.com"

# Use as template for new hire:
#   - Same groups
#   - Same licenses
#   - Same Teams membership
#   - Same mailbox access
```

---

### **5. Flag Critical Items**

**Always review these sections first:**
- ⚠️ **Admin Roles** - Must remove before disabling account
- ⚠️ **External Forwarding** - Data exfiltration risk
- ⚠️ **Teams Ownership** - Must reassign or Teams become orphaned
- ⚠️ **SharePoint Sites Owned** - Must transfer ownership

---

## Security Considerations

### **Sensitive Data in Reports**

**What's Included:**
- Email addresses
- Phone numbers
- Job titles, departments
- Group memberships
- Mailbox access details
- Device information

**Best Practices:**
- Store reports in secure location
- Don't email reports unencrypted
- Delete after offboarding complete (or archive securely)
- Follow data retention policies
- Don't commit to version control

---

### **Admin Permissions Required**

**Why High Permissions Needed:**
- Script needs to read ALL mailbox permissions
- Needs to check ALL SharePoint sites for ownership
- Requires admin-level Graph API access
- Needs SharePoint admin for OneDrive

**Recommendation:**
- Run from admin workstation
- Use privileged identity management (PIM) if available
- Don't run from shared/untrusted systems

---

## Integration with Other Tools

**Complete User Lifecycle Suite:**

**Onboarding:**
- Use profile as template for access provisioning
- Match groups/licenses of similar role

**During Employment:**
- License optimization (see duplicate licenses)
- Access reviews (quarterly profile audits)

**Offboarding:**
- **This tool** - Complete handoff plan ← **Primary use case**
- Mailbox Permission Auditor - Verify access removed
- License cleanup tools - Reclaim licenses

**Related Tools in MSP Toolkit:**
- Duplicate License Detector (license cleanup)
- License Assignment Analyzer (license reporting)
- User Mailbox Access Finder (dedicated mailbox auditing)
- Mailbox Permission Auditor (verify access removal)

---

## Known Limitations

### **SharePoint Sites - Ownership Only**

**What's Included:**
- Sites where user is primary owner

**What's NOT Included:**
- Sites where user just has permissions
- Sites where user is member but not owner

**Why:** Checking ALL site permissions would require scanning every site in tenant (hours for large tenants)

**Workaround:** For complete site access audit, use SharePoint admin center or dedicated site permissions tool

---

### **Mailbox Access - Performance Limited**

**Reality:**
- Checking 5000+ mailboxes will take 1+ hours
- This is API throughput limitation, not script issue
- No way around it for comprehensive checks

**Solution:**
- Use Option 1 (Shared Only) for daily use
- Use Option 3 (Skip) for very large tenants
- Run Option 2 overnight for complete audits
- Use dedicated mailbox audit tool separately

---

## Roadmap / Future Enhancements

Potential additions:
- [ ] PDF export option
- [ ] Email delivery of reports
- [ ] Compare two users (role transition)
- [ ] Batch mode (multiple users)
- [ ] Historical comparison (access changes over time)
- [ ] Parallel processing (PowerShell 7+) for mailbox checks
- [ ] Cached mailbox results (run weekly, reuse)

---

## Related Tools

Other tools in the MSP PowerShell Toolkit:
- **License Assignment Analyzer** - Comprehensive license reporting
- **Duplicate License Detector** - Find license waste
- **Bulk Remediation Tool** - Fix license issues
- **Mailbox Permission Auditor** - Deep mailbox access analysis
- **User Mailbox Access Finder** - Dedicated mailbox auditing
- **Teams Voice License Audit** - Phone number assignments

[View full MSP PowerShell Toolkit →](https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit)

---

## FAQ

**Q: Why does the mailbox check take so long?**

A: For large tenants (1000+ mailboxes), checking permissions requires 2 API calls per mailbox. Even optimized, this hits API rate limits. Solution: Use Option 1 (Shared Only) or Option 3 (Skip).

---

**Q: Can I run this unattended/scheduled?**

A: Not currently - the interactive prompt requires operator input. Future version may add `-Unattended` parameter. For now, use separate dedicated tools for scheduled audits.

---

**Q: What if my tenant has 70% shared mailboxes?**

A: This is a tenant architecture issue (should be 10-20% shared). For these broken tenants, use Option 3 (Skip) for fast reports and run comprehensive mailbox audits separately/overnight.

---

**Q: Why skip Teams or OneDrive sections?**

A: If modules fail to connect, script continues without them. You'll see warnings but get a partial report. Better than complete failure.

---

**Q: How accurate is the license cost calculation?**

A: Based on common list prices. Actual costs vary by EA/CSP agreements. Use as estimate, not exact billing.

---

## Contributing

This is part of a personal portfolio project, but feedback is welcome!

**Found a bug?** Open an issue!
**Missing critical info?** Let me know!
**Have a feature request?** Suggest it!

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

**⚠️ IMPORTANT:** Always review reports before taking action. This tool provides information, but human judgment is required for offboarding decisions.

**💡 TIP:** For your first run, choose Option 1 (Shared Mailboxes Only) - it's fast and covers most scenarios!
