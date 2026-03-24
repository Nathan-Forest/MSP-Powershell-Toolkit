# Teams Voice License & Phone Number Audit

**Audit tool for Microsoft Teams Phone licensing and phone number assignments** - ensures users with phone system licenses actually have phone numbers assigned.

---

## Business Problem

**The Issue:**
- Users get assigned "Telstra Calling for Office 365" (or other phone system licenses)
- But never get a phone number configured
- Result: Paying for phone licenses that aren't being used

**Example:**
```
John Smith:
  ✓ License: Telstra Calling for Office 365 ($10/month)
  ✗ Phone Number: None assigned
  
Result: $120/year wasted on unused license
```

**Solution:** Automated audit that correlates license assignments with actual phone number assignments.

---

## What It Reports

For each user with a phone system license:

✅ **User Details**
- Name, Email, Job Title, Department, Office
- Account status (Enabled/Disabled)

✅ **License Information**
- License name (friendly format)
- Assignment type (Direct or Group-based)
- Which group assigned it (if applicable)

✅ **Phone Number Assignment**
- Whether they have a phone number
- What the number is (if assigned)
- Number type (Calling Plan, Direct Routing, etc.)
- Enterprise Voice status
- Voice routing policy

✅ **Compliance Status**
- "OK - Has Number" = Licensed and configured ✓
- "ATTENTION - License but No Number" = Wasted license ⚠️

---

## Prerequisites

### Required Modules
```powershell
Install-Module Microsoft.Graph.Users -Force
Install-Module MicrosoftTeams -Force
```

### Required Permissions
- **Microsoft Graph:**
  - User.Read.All
  - Group.Read.All
  
- **Microsoft Teams:**
  - Teams Administrator or Global Administrator role (to read phone numbers)

### Minimum Requirements
- PowerShell 5.1 or higher
- Microsoft 365 tenant with Teams Phone licensing
- Rights to connect to Teams PowerShell

---

## Installation

```powershell
# Install modules
Install-Module Microsoft.Graph.Users -Force
Install-Module MicrosoftTeams -Force

# Download script
# Place in your scripts directory
```

---

## Usage

### Basic Usage

**Check Telstra Calling licenses (default):**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1
```

**Include disabled accounts:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1 -IncludeDisabledAccounts
```

**Check ALL phone system licenses:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1 -CheckAllPhoneSystemLicenses
```

**Custom export path:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1 -ExportPath "C:\Reports"
```

---

## Supported Phone System Licenses

### Default Mode (Telstra)
- Telstra Calling for Office 365
- MCOPSTNEAU / MCOPSTNEAU2

### Extended Mode (-CheckAllPhoneSystemLicenses)
- Phone System (MCOEV)
- Phone System - Virtual User
- Domestic Calling Plan (MCOPSTN1)
- International Calling Plan (MCOPSTN2)
- Calling Plan for Australia (MCOPSTNEAU)
- Telstra Calling for Office 365 (MCOPSTNEAU2)
- Teams Phone with Calling Plan (Frontline Worker)
- Common Area Phone (MCOCAP)
- Audio Conferencing (MCOMEETADV)

---

## Output

### Console Summary

```
========================================
AUDIT SUMMARY
========================================

Total Users with Phone Licenses: 47

Phone Number Assignment:
  With Phone Numbers: 35
  Without Phone Numbers: 12

  ⚠ 12 users have phone system licenses but NO phone number assigned!
  This represents potential license waste.

License Assignment Type:
  Group: 32
  Direct: 15

Account Status:
  Enabled: 45
  Disabled: 2

Top Groups Assigning Phone Licenses:
  Voice-Users-Australia: 28 users
  Executive-Teams-Phone: 4 users

✓ Report exported to: .\Report\Teams_Voice_License_Report_20260325_091234.csv
```

---

### CSV Report

**File:** `Teams_Voice_License_Report_YYYYMMDD_HHMMSS.csv`

**Columns:**
- **UserName** - Display name
- **Email** - User principal name
- **JobTitle** - Job title
- **Department** - Department
- **Office** - Office location
- **LicenseName** - Friendly license name
- **LicenseSKU** - SKU part number
- **HasPhoneNumber** - True/False
- **PhoneNumber** - Assigned phone number (or null)
- **NumberType** - Calling Plan, Direct Routing, Hybrid, etc.
- **EnterpriseVoiceEnabled** - True/False
- **VoiceRoutingPolicy** - Voice routing policy name
- **AssignmentType** - Direct or Group
- **AssignedByGroup** - Group name (if group-based)
- **GroupId** - Azure AD group ID
- **AccountStatus** - Enabled or Disabled
- **UserId** - Azure AD object ID
- **Status** - "OK - Has Number" or "ATTENTION - License but No Number"

**Sample Data:**
```csv
UserName,Email,LicenseName,HasPhoneNumber,PhoneNumber,AssignmentType,AssignedByGroup,AccountStatus,Status
John Smith,john.smith@company.com,Telstra Calling for Office 365,True,+61383776600,Group,Voice-Users-Australia,Enabled,OK - Has Number
Jane Doe,jane.doe@company.com,Telstra Calling for Office 365,False,,,Direct,,Enabled,ATTENTION - License but No Number
```

---

## Common Use Cases

### Use Case 1: Find Wasted Phone Licenses

**Goal:** Identify users with phone licenses but no number assigned

**Steps:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1

# Filter GridView to: Status = "ATTENTION - License but No Number"
# Export list
# Remove licenses or assign phone numbers
```

**Typical findings:** 10-20% of phone licenses have no number assigned

---

### Use Case 2: Pre-Deployment Audit

**Goal:** Before deploying phone numbers, check who has licenses

**Steps:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1

# Export users without numbers
# Use as deployment checklist
# Assign numbers to all licensed users
# Re-run to verify
```

---

### Use Case 3: Post-Migration Verification

**Goal:** After migrating from old phone system, verify all users configured

**Steps:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1 -CheckAllPhoneSystemLicenses

# Check that all licensed users have numbers
# Verify number types are correct (Calling Plan vs Direct Routing)
# Confirm voice policies applied
```

---

### Use Case 4: Group-Based Licensing Audit

**Goal:** Verify phone licenses are assigned via groups (not direct)

**Steps:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1

# Filter GridView to: AssignmentType = "Direct"
# Migrate to group-based licensing
# Re-run to confirm all group-based
```

---

### Use Case 5: Disabled Account Cleanup

**Goal:** Find disabled accounts still consuming phone licenses

**Steps:**
```powershell
.\Get-TeamsVoiceLicenseReport.ps1 -IncludeDisabledAccounts

# Filter to: AccountStatus = "Disabled"
# Remove licenses from disabled accounts
# Reclaim for new users
```

---

## Phone Number Types Detected

The script identifies different phone number configurations:

| Number Type | Description | Source Property |
|-------------|-------------|-----------------|
| **Calling Plan** | Microsoft Calling Plan number | TelephoneNumber |
| **Direct Routing / Operator Connect** | Third-party SIP trunk | LineURI |
| **On-Premises (Hybrid)** | Migrated from on-prem Skype | OnPremLineURI |

---

## Understanding the Report

### Status: "OK - Has Number" ✓
User is properly configured:
- Has phone system license
- Has phone number assigned
- Enterprise Voice enabled (if applicable)
- Ready to make/receive calls

### Status: "ATTENTION - License but No Number" ⚠️
User has license but can't make calls:
- Has phone system license (costing money)
- No phone number configured
- **Action needed:** Assign number or remove license

---

## Troubleshooting

### "Telstra Calling license not found in tenant"

**Cause:** Tenant doesn't have this specific license

**Solution:** The script shows available phone licenses:
```powershell
Available phone-related SKUs:
  - MCOEV: Phone System
  - MCOPSTN1: Domestic Calling Plan
  
Tip: Use -CheckAllPhoneSystemLicenses to check all phone licenses
```

---

### "Failed to connect to Microsoft Teams"

**Cause:** MicrosoftTeams module not installed or authentication failed

**Solution:**
```powershell
# Install module
Install-Module MicrosoftTeams -Force

# Reconnect
Disconnect-MicrosoftTeams
Connect-MicrosoftTeams
```

---

### "Could not retrieve phone info for user"

**Cause:** User doesn't exist in Teams or permissions issue

**Solution:**
- User may not be enabled for Teams yet
- Check if user is synced to Teams
- Verify you have Teams Administrator role

---

### Phone numbers not showing

**Cause:** Different number assignment methods

**Solution:** The script checks multiple properties:
- LineURI (Direct Routing)
- OnPremLineURI (Hybrid)
- TelephoneNumber (Calling Plan)

If still not showing, number may be in unusual location or pending provisioning.

---

## Best Practices

### Monthly Phone License Audit

**Recommended workflow:**
```powershell
# 1. Run audit
.\Get-TeamsVoiceLicenseReport.ps1

# 2. Filter to users without numbers
# 3. Investigate each case:
#    - User needs number? → Assign it
#    - User doesn't need phone? → Remove license
# 4. Re-run to verify

# 5. Document savings
```

---

### Before Phone System Deployment

**Preparation checklist:**
```powershell
# 1. Audit current license assignments
.\Get-TeamsVoiceLicenseReport.ps1

# 2. Export users without numbers
$report = Import-Csv "Teams_Voice_License_Report_*.csv"
$needsNumbers = $report | Where-Object { $_.HasPhoneNumber -eq $false }

# 3. Use as deployment worksheet
# 4. Assign numbers
# 5. Verify deployment complete
```

---

### Quarterly Compliance Check

**Compliance verification:**
```powershell
# Check all phone licenses
.\Get-TeamsVoiceLicenseReport.ps1 -CheckAllPhoneSystemLicenses -IncludeDisabledAccounts

# Verify:
# - All licensed users have numbers
# - All group-based assignments (no direct)
# - No disabled accounts with licenses
# - Voice policies applied correctly
```

---

## Integration with Other Tools

**Complete telephony audit workflow:**

1. **License Assignment Analyzer** - Check all license assignments
2. **Duplicate License Detector** - Find duplicate phone licenses
3. **Teams Voice Audit** ← This tool - Verify phone number assignments
4. **Bulk Remediation** - Fix license issues

---

## Performance

**Typical runtimes:**
- 50 users: ~2 minutes
- 100 users: ~4 minutes
- 500 users: ~15 minutes

**Why?** Teams PowerShell cmdlets are slower than Graph API (retrieving phone numbers requires Teams connection)

**Optimization:** Script includes throttling protection (500ms delay every 20 users)

---

## Security Considerations

### Sensitive Data
- Phone numbers are PII (Personal Identifiable Information)
- Store reports securely
- Don't commit CSV files to version control
- Comply with privacy regulations (GDPR, etc.)

### Permissions
- Script uses read-only permissions
- No modifications made to users or licenses
- Safe to run in production

### Audit Trail
- All actions logged to console
- Export includes timestamp
- Keep reports for compliance (recommend 12 months)

---

## Related Tools

Other tools in the MSP PowerShell Toolkit:
- **License Assignment Analyzer** - Comprehensive license analysis
- **Duplicate License Detector** - Find duplicate assignments
- **Bulk Remediation Tool** - Fix license issues
- **JobTitle Group Auditor** - Verify dynamic groups

[View full MSP PowerShell Toolkit →](https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit)

---

## Roadmap / Future Enhancements

- [ ] Add phone number assignment automation
- [ ] Compare against PBX/phone system inventory
- [ ] Historical tracking (month-over-month changes)
- [ ] Email alerting for new unlicensed users
- [ ] Integration with Teams Rooms auditing
- [ ] Emergency location verification (E911)

---

## Contributing

This is part of a personal portfolio project, but feedback is welcome!

**Found a SKU that's not mapped?** Let me know!
**Have a Telstra-specific enhancement?** Open an issue!

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
