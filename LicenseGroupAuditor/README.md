# License Group Duplicate Detection Tool

## Overview
This PowerShell script identifies users who are members of multiple license assignment groups in Microsoft 365. Being in multiple groups can result in duplicate license assignments, wasting money and consuming your license pool unnecessarily.

**⚠️ DO NOT EDIT THE SCRIPT FILE DIRECTLY**  
All configuration is done through the `groupstocheck.csv` file. Editing the script can break functionality.

---

## What This Script Does

✅ Connects to your Microsoft 365 tenant  
✅ Checks membership across all license groups you specify  
✅ Identifies users in 2 or more groups  
✅ Exports results to CSV for review  
✅ Calculates potential license savings  

---

## Prerequisites

### Required PowerShell Modules
The script requires the Microsoft Graph PowerShell module. Install it once:

```powershell
Install-Module Microsoft.Graph -Force -AllowClobber
```

### Required Permissions
You must run this script with an account that has:
- Global Reader **OR**
- Groups Administrator **OR**
- User Administrator

---

## Setup Instructions

### Step 1: Create Your Groups List

1. Create a file named **`groupstocheck.csv`** in the same folder as the script
2. Use this exact format (first line must be `GroupName`):

```csv
GroupName
License_Staff
License_Volunteers
License_Contractor
License_Retail
```

**Important Notes:**
- The first line **must** be `GroupName` (this is the column header)
- Group names must **exactly match** what's in Azure AD (case-sensitive)
- One group name per line
- No blank lines in the middle of the list
- Save as CSV format (not Excel .xlsx)

### Step 2: Place Files in Same Folder

Your folder should contain:
```
📁 LicenseGroupAudit
   ├── Check-DuplicateLicenseGroups.ps1  (the script - DON'T EDIT)
   └── groupstocheck.csv                  (your group list - EDIT THIS)
```

---

## How to Run the Script

### Option 1: Right-click Method (Easiest)
1. Right-click on `Check-DuplicateLicenseGroups.ps1`
2. Select **"Run with PowerShell"**
3. Sign in when prompted
4. Wait for the script to complete

### Option 2: PowerShell Window Method
1. Open PowerShell
2. Navigate to the script folder:
   ```powershell
   cd "C:\Path\To\LicenseGroupAudit"
   ```
3. Run the script:
   ```powershell
   .\Check-DuplicateLicenseGroups.ps1
   ```

### Option 3: PowerShell ISE Method
1. Open PowerShell ISE
2. Open the script file
3. Press **F5** to run

---

## What to Expect

### During Execution
```
Importing license groups from CSV...
Loaded 10 license groups from CSV
Groups to check:
  - License_EA_QLD_Staff
  - License_EA_QLD_Volunteers
  ...

Connecting to Microsoft Graph...
[Browser window opens for authentication]

Checking group: License_EA_QLD_Staff
  Found 45 members
Checking group: License_EA_QLD_Volunteers
  Found 123 members
...

========================================
ANALYSIS COMPLETE
========================================

⚠️  FOUND 15 USERS IN MULTIPLE LICENSE GROUPS
```

### Output Files
The script creates a CSV report in the same folder:
- **Filename format:** `DuplicateLicenseGroups_YYYYMMDD_HHMMSS.csv`
- **Example:** `DuplicateLicenseGroups_20260318_143052.csv`

**CSV contains:**
- User Display Name
- User Email (UserPrincipalName)
- Number of Groups
- List of Groups
- Issue Description

---

## Understanding the Results

### Summary Section
```
Summary by Group Count:
Groups    Count
------    -----
3         2      ← 2 users are in 3 groups (worst offenders)
2         13     ← 13 users are in 2 groups
```

### Detailed Results
```
DisplayName      UserPrincipalName              GroupCount  Groups
-----------      -----------------              ----------  ------
John Smith       john.smith@tennant.org.au      3           License_Staff; License_Volunteers; License_D_D365
Jane Doe         jane.doe@tennant.org.au        2           License_Retail; License_QLD_PowerAppsPremium
```

### Potential Savings
```
💰 Potential License Optimization:
   Users should be in 1 group each
   Extra group memberships to remove: 17
```

This shows how many group memberships could be removed to eliminate duplicates.

---

## Adding or Removing Groups

### To Add a Group
1. Open `groupstocheck.csv`
2. Add a new line with the exact group name
3. Save the file
4. Run the script again

**Example:**
```csv
GroupName
License_QLD_Staff
License_QLD_Volunteers
License_QLD_NewGroup    ← Add here
```

### To Remove a Group
1. Open `groupstocheck.csv`
2. Delete the line with that group name
3. Save the file
4. Run the script again

### To Check a Different Client
1. Create a new CSV file with that client's groups
2. **Option A:** Rename your CSV files:
   - `groupstocheck_ClientA.csv`
   - `groupstocheck_ClientB.csv`
3. **Option B:** Edit line 12 in the script to point to the new CSV:
   ```powershell
   $csvPath = ".\groupstocheck_ClientB.csv"
   ```

---

## Troubleshooting

### "CSV file not found"
**Problem:** The script can't find `groupstocheck.csv`

**Solution:**
- Make sure the CSV file is in the **same folder** as the script
- Check the filename is exactly `groupstocheck.csv` (not `groupstocheck.csv.txt`)
- Check for typos in the filename

---

### "No groups found in CSV file"
**Problem:** The CSV is empty or formatted incorrectly

**Solution:**
- Open the CSV in Notepad (not Excel)
- First line must be exactly: `GroupName`
- Make sure there are group names below the header
- Remove any blank lines

**Correct format:**
```
GroupName
License_QLD_Staff
License_QLD_Volunteers
```

**Incorrect format:**
```
GroupName

License_QLD_Staff

License_QLD_Volunteers
```

---

### "Group not found in Azure AD"
**Problem:** A group name in your CSV doesn't exist in Azure AD

**Solution:**
- Check the exact spelling in Azure AD admin center
- Group names are **case-sensitive**: `License_QLD_staff` ≠ `License_QLD_Staff`
- Remove old/deleted groups from your CSV

---

### "Access Denied" or "Insufficient Privileges"
**Problem:** Your account doesn't have permission

**Solution:**
- Ask your Global Admin to grant you one of these roles:
  - Global Reader
  - Groups Administrator
  - User Administrator
- Disconnect and reconnect: `Disconnect-MgGraph` then re-run the script

---

### Script Runs but Shows 0 Users
**Possible causes:**
- ✅ Good news! No users are in multiple groups (licensing is clean)
- ❌ Group names in CSV don't match Azure AD (check spelling/case)
- ❌ Groups are empty (no members assigned yet)

---

## Best Practices

### Before Running
✅ Test on a small CSV first (2-3 groups)  
✅ Verify group names match Azure AD exactly  
✅ Make sure you have the right permissions  

### After Running
✅ Review the CSV export before making changes  
✅ Identify why users are in multiple groups (deliberate vs. mistake)  
✅ Remove users from extra groups carefully  
✅ Keep a copy of the report for audit purposes  

### Regular Maintenance
✅ Run monthly to catch new duplicate assignments  
✅ Update your CSV when groups are added/removed  
✅ Document which groups should never overlap  

---

## Common Use Cases

### New Client Onboarding
1. Create `groupstocheck_ClientName.csv` with their license groups
2. Run the script to establish baseline
3. Clean up any duplicates found
4. Schedule monthly audits

### License Optimization Project
1. Add **all** license groups to CSV
2. Run the script
3. Sort results by GroupCount (highest first)
4. Focus on users in 3+ groups first
5. Calculate savings and report to management

### Troubleshooting License Issues
1. User reports "too many licenses" or license errors
2. Add their relevant groups to CSV
3. Run script to see if they're in multiple groups
4. Remove from extra groups

---

## File Locations

### Script Execution Files
- **Script:** `Check-DuplicateLicenseGroups.ps1` (DO NOT EDIT)
- **Configuration:** `groupstocheck.csv` (EDIT THIS)

### Output Files
- **Reports:** `DuplicateLicenseGroups_*.csv` (generated in same folder)

### Recommended Folder Structure
```
C:\Scripts\LicenseAuditing\
├── Check-DuplicateLicenseGroups.ps1
├── groupstocheck.csv
├── Reports\
│   ├── DuplicateLicenseGroups_20260318_143052.csv
│   └── DuplicateLicenseGroups_20260315_091234.csv
```

---

## Support

### For Technical Issues
- **Module installation errors:** Ensure you run PowerShell as Administrator
- **Authentication issues:** Check your account has the required roles
- **Script errors:** Do NOT edit the script - check your CSV formatting

### For Questions
Contact your IT administrator or the script maintainer with:
- Screenshot of the error
- Copy of your `groupstocheck.csv` (remove sensitive data)
- Output from running `Get-Module Microsoft.Graph -ListAvailable`

---

## Version History

**Version 1.0** (March 2026)
- Initial release
- CSV-based group configuration
- Multi-group detection
- CSV export functionality

---

## Quick Reference Card

| Task | Action |
|------|--------|
| **Add a group** | Edit `groupstocheck.csv`, add new line |
| **Remove a group** | Edit `groupstocheck.csv`, delete line |
| **Run the script** | Right-click → "Run with PowerShell" |
| **View results** | Open the generated CSV file |
| **Different client** | Create new CSV, update script line 12 |
| **Troubleshoot** | Check CSV format: must start with `GroupName` |

---

## Important Warnings

⚠️ **DO NOT:**
- Edit the `.ps1` script file directly
- Delete the first line (`GroupName`) from the CSV
- Add extra columns to the CSV without updating the script
- Run this on production during business hours (first time)

✅ **DO:**
- Test with a small group list first
- Keep backups of your CSV files
- Document your group naming conventions
- Review results before taking action

---

## License & Credits

**Created by:** Nathan Forest  
**Organization:** Brennan IT  
**Purpose:** License optimization and compliance  
**Last Updated:** March 2026  

---

**Questions?** Review the Troubleshooting section above or contact your IT administrator.
