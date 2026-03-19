# MSP PowerShell Automation Toolkit

Production-grade PowerShell automation tools for Microsoft 365 administration, cost optimization, and compliance auditing in multi-tenant MSP environments.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Microsoft 365](https://img.shields.io/badge/Microsoft%20365-Automation-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

This toolkit contains automation scripts built and tested across multiple client tenants during my work as a Support Analyst at Brennan IT. Each tool addresses real-world challenges in managing Microsoft 365 environments at scale.

**Business Impact:**
- 💰 Reduced license costs by identifying duplicate assignments
- 🔒 Automated security compliance auditing across multi-tenant environments
- ⚡ Saved hundreds of IT hours through automated reporting
- 📊 Enabled data-driven decision making for cost optimization

---

## Available Tools

### 🔍 [License Group Auditor](./LicenseGroupAuditor/)

**Problem:** Users accidentally added to multiple license groups consume duplicate licenses, wasting budget and exhausting license pools.

**Solution:** Automated detection of users in 2+ license groups with CSV reporting and cost analysis.

**Key Features:**
- CSV-driven configuration (no script editing required)
- Multi-tenant support for MSP environments
- Calculates potential cost savings
- Professional reporting with GridView and CSV export
- Comprehensive error handling and validation

**Business Impact:** Identified 23 users with duplicate licenses across one 500-user tenant, saving ~$2,300/year in unnecessary Microsoft 365 costs.

**Tech Stack:** Microsoft Graph API, Group-based Licensing, PowerShell 5.1+

**[View Full Documentation →](./LicenseGroupAuditor/README.md)**

---

### 📬 [Mailbox Permission Auditor](./MailboxPermissionAuditor/)

**Problem:** Manual auditing of mailbox permissions across hundreds of mailboxes is time-prohibitive and error-prone.

**Solution:** Automated permission reporting with dual scripts - comprehensive tenant-wide audit and focused shared mailbox review.

**Key Features:**
- Two scripts: Full tenant audit OR shared mailboxes only
- Reports FullAccess, SendAs, and SendOnBehalf permissions
- Throttling protection for large tenants (1000+ mailboxes)
- Interactive GridView and professional CSV exports
- Security risk levels for each permission type

**Business Impact:** Reduced quarterly compliance audits from 8 hours to 30 minutes. Identified 23 unnecessary permissions across one tenant during offboarding audit.

**Tech Stack:** Exchange Online PowerShell, OAuth 2.0, CSV reporting

**[View Full Documentation →](./MailboxPermissionAuditor/README.md)**

---

## Coming Soon

Additional automation tools currently in development:
- 📊 SharePoint Storage Monitor - Proactive storage monitoring with automated alerts
- 👤 Disabled User Auditor - Identify disabled accounts with active licenses and storage

---

## Prerequisites

All tools in this toolkit require:
- **PowerShell:** 5.1 or higher
- **Modules:** Tool-specific (Microsoft.Graph, ExchangeOnlineManagement, etc.)
- **Permissions:** Global Reader or specific admin roles (documented per tool)
- **Environment:** Windows 10/11 or Windows Server 2016+

## Quick Start

```powershell
# Clone the repository
git clone https://github.com/Nathan-Forest/MSP-PowerShell-Toolkit.git

# Navigate to a specific tool
cd MSP-PowerShell-Toolkit/LicenseGroupAuditor

# Install required modules (example for License Group Auditor)
Install-Module Microsoft.Graph -Force

# Follow tool-specific README for configuration and usage
```

## Design Philosophy

All tools in this toolkit share common principles:

✅ **CSV-driven configuration** - Operators update configuration files, not scripts  
✅ **Multi-tenant support** - Easily adapt for different client environments  
✅ **Production-tested** - Battle-tested across real MSP client tenants  
✅ **Comprehensive error handling** - Graceful failures with informative messages  
✅ **Professional reporting** - Executive-ready HTML emails and CSV exports  
✅ **Well-documented** - Complete READMEs with troubleshooting guides  

## Use Cases

**For MSPs:**
- Client onboarding audits
- Monthly compliance reporting
- Cost optimization initiatives
- License reclamation projects
- Security and access reviews

**For IT Teams:**
- Security audits and compliance
- User offboarding automation
- Proactive capacity monitoring
- Budget justification with data
- Least privilege access reviews

## Project Background

These tools were developed during my transition from IT infrastructure support to backend development and DevOps engineering. They represent:

- **Real-world automation** solving actual business problems
- **Production quality** with error handling and retry logic
- **Professional documentation** for team adoption
- **Scalable design** tested across multi-tenant environments

Each tool saves hours of manual work while providing actionable insights for cost reduction and compliance.

## Technical Skills Demonstrated

- Microsoft Graph API integration
- Exchange Online PowerShell
- OAuth 2.0 authentication and delegated permissions
- CSV data processing and validation
- Error handling with retry logic and throttling protection
- Professional HTML email generation
- Multi-tenant architecture patterns
- Production-grade PowerShell scripting
- Interactive data presentation with GridView

## About the Author

**Nathan Forest**  
Support Analyst → Backend Developer  
Brennan IT | Brisbane, Australia

I'm transitioning from 20+ years in IT infrastructure and automation into backend development and DevOps engineering. My background includes:

- **Current:** Building PowerShell automation for MSP multi-tenant environments
- **Developing:** Full-stack applications in C# and TypeScript
- **Experience:** Network engineering, vertical rescue instructor, emergency response
- **Portfolio:** Production automation tools and full-stack development projects

**Connect:**
- **LinkedIn:** [linkedin.com/in/nathanforest-b8a0a867](https://linkedin.com/in/nathan-forest-australia)
- **GitHub:** [github.com/Nathan-Forest](https://github.com/Nathan-Forest)

## Contributing

This is a personal portfolio project, but suggestions and feedback are welcome! Feel free to:
- Open an issue for bugs or feature requests
- Suggest improvements via pull request
- Share your own use cases or success stories

## License

MIT License - See [LICENSE](./LICENSE) for details.

---

## Repository Structure

```
MSP-PowerShell-Toolkit/
├── README.md                          ← You are here
├── LICENSE
├── .gitignore
│
├── LicenseGroupAuditor/               ← Available now
│   ├── README.md
│   ├── Check-DuplicateLicenseGroups.ps1
│   └── groupstocheck.example.csv
│
└── MailboxPermissionAuditor/          ← Available now
    ├── README.md
    ├── .gitignore
    ├── Get-TenantMailboxPermissions.ps1
    └── Get-SharedMailboxPermissions.ps1
```

---

## Quick Tool Comparison

| Tool | Purpose | Runtime | Best For |
|------|---------|---------|----------|
| **License Group Auditor** | Find duplicate license assignments | 2-5 min | Cost optimization |
| **Mailbox Permission Auditor** | Security & compliance review | 5-90 min | Access auditing |

---

**Questions or interested in collaboration?** Reach out via LinkedIn or open an issue!

**Hiring for DevOps/Automation roles?** I bring production automation experience, infrastructure knowledge, and modern development skills (C#, PowerShell, TypeScript). Let's connect!
