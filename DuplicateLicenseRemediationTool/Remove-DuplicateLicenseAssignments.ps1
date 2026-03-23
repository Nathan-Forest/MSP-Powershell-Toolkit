<#
.SYNOPSIS
    Bulk remediation tool to remove duplicate direct license assignments

.DESCRIPTION
    Imports duplicate license report and removes direct assignments while keeping
    group-based assignments. Includes safety features:
    - Dry-run mode (preview without making changes)
    - Confirmation prompts
    - Detailed logging
    - Rollback capability
    - Filter options (disabled accounts only, specific licenses, etc.)
    - Progress tracking
    
.PARAMETER CsvPath
    Path to duplicate license report CSV from Find-DuplicateLicenseAssignments.ps1

.PARAMETER DryRun
    Preview changes without actually removing licenses (highly recommended first!)

.PARAMETER DisabledAccountsOnly
    Only remove licenses from disabled accounts (safest option)

.PARAMETER SkipConfirmation
    Skip individual user confirmations (use with caution!)

.PARAMETER LicenseFilter
    Only process specific license types (comma-separated SKU part numbers)

.PARAMETER ExportPath
    Path to export remediation log (default: C:\Temp)

.PARAMETER CreateRollbackFile
    Create rollback script for undoing changes (recommended)

.EXAMPLE
    .\Remove-DuplicateLicenseAssignments.ps1 -CsvPath ".\Report\Duplicate_License_Report.csv" -DryRun
    
.EXAMPLE
    .\Remove-DuplicateLicenseAssignments.ps1 -CsvPath ".\Report\Duplicate_License_Report.csv" -DisabledAccountsOnly

.EXAMPLE
    .\Remove-DuplicateLicenseAssignments.ps1 -CsvPath ".\Report\Duplicate_License_Report.csv" -LicenseFilter "SPE_F3,POWER_BI_PRO"

.EXAMPLE
    .\Remove-DuplicateLicenseAssignments.ps1 -CsvPath ".\Report\Duplicate_License_Report.csv" -CreateRollbackFile -SkipConfirmation

.NOTES
    Author: Nathan Forest
    Created: 2026-03-20
    Requires: Microsoft.Graph.Users module
    Permissions: User.ReadWrite.All (to modify license assignments)
    
    IMPORTANT: Always run with -DryRun first to preview changes!
    
    Safety Features:
    - Dry-run mode (test before executing)
    - Confirmation prompts
    - Detailed logging
    - Rollback file generation
    - Filter options
    - Error handling per user
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$DisabledAccountsOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipConfirmation,
    
    [Parameter(Mandatory = $false)]
    [string]$LicenseFilter,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportPath = ".\Report",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateRollbackFile
)

#Requires -Modules Microsoft.Graph.Users

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    # Also write to log file
    if ($script:logFilePath) {
        Add-Content -Path $script:logFilePath -Value $logMessage
    }
}

function Get-SkuIdFromPartNumber {
    param([string]$SkuPartNumber)
    
    try {
        $sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber } | Select-Object -First 1
        if ($sku) {
            return $sku.SkuId
        }
        return $null
    } catch {
        Write-Log "Error looking up SKU for $SkuPartNumber`: $_" -Level Error
        return $null
    }
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Duplicate License Bulk Remediation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made`n" -ForegroundColor Yellow
}

# Verify CSV file exists
if (-not (Test-Path $CsvPath)) {
    Write-Host "CSV file not found: $CsvPath" -ForegroundColor Red
    exit 1
}

# Ensure export path exists
if (-not (Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
}

# Create log file
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFileName = "License_Remediation_Log_$timestamp.txt"
$script:logFilePath = Join-Path $ExportPath $logFileName

Write-Log "=== License Remediation Started ===" -Level Info
Write-Log "CSV Source: $CsvPath" -Level Info
Write-Log "Dry Run: $DryRun" -Level Info
Write-Log "Disabled Accounts Only: $DisabledAccountsOnly" -Level Info
Write-Log "License Filter: $(if ($LicenseFilter) { $LicenseFilter } else { 'None' })" -Level Info

# Import duplicate license report
Write-Host "Reading duplicate license report..." -ForegroundColor Yellow
try {
    $duplicates = Import-Csv -Path $CsvPath -ErrorAction Stop
    Write-Host "Found $($duplicates.Count) duplicate license assignments in report`n" -ForegroundColor Green
    Write-Log "Imported $($duplicates.Count) records from CSV" -Level Info
} catch {
    Write-Host "Failed to read CSV file" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Failed to import CSV: $_" -Level Error
    exit 1
}

if ($duplicates.Count -eq 0) {
    Write-Host "No duplicates to remediate!" -ForegroundColor Green
    exit 0
}

# Apply filters
$originalCount = $duplicates.Count

if ($DisabledAccountsOnly) {
    $duplicates = $duplicates | Where-Object { $_.AccountStatus -eq "Disabled" }
    Write-Host "Filtering to disabled accounts only: $($duplicates.Count) records" -ForegroundColor Gray
    Write-Log "Filtered to disabled accounts: $($duplicates.Count) records" -Level Info
}

if ($LicenseFilter) {
    $licenseList = $LicenseFilter -split ","
    $duplicates = $duplicates | Where-Object { $licenseList -contains $_.LicenseSKU }
    Write-Host "Filtering to licenses: $LicenseFilter`: $($duplicates.Count) records" -ForegroundColor Gray
    Write-Log "Filtered to specific licenses: $($duplicates.Count) records" -Level Info
}

if ($duplicates.Count -eq 0) {
    Write-Host "`nNo records match your filters" -ForegroundColor Yellow
    Write-Host "Original records: $originalCount" -ForegroundColor Gray
    Write-Host "After filters: 0`n" -ForegroundColor Gray
    exit 0
}

# Display summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "REMEDIATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Records to process: $($duplicates.Count)" -ForegroundColor White

$byLicense = $duplicates | Group-Object LicenseName | Sort-Object Count -Descending
Write-Host "`nBy License Type:" -ForegroundColor Yellow
$byLicense | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
}

$byStatus = $duplicates | Group-Object AccountStatus
Write-Host "`nBy Account Status:" -ForegroundColor Yellow
$byStatus | ForEach-Object {
    $color = if ($_.Name -eq "Disabled") { "Red" } else { "Yellow" }
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $color
}

# Calculate estimated savings
$monthlySavings = ($duplicates | Measure-Object -Property MonthlyCostPerLicense -Sum).Sum
$annualSavings = $monthlySavings * 12

if ($monthlySavings -gt 0) {
    Write-Host "`nEstimated Savings After Remediation:" -ForegroundColor Yellow
    Write-Host "  Monthly: `$$($monthlySavings.ToString('N2'))" -ForegroundColor Green
    Write-Host "  Annual: `$$($annualSavings.ToString('N2'))" -ForegroundColor Green
}

Write-Host "`n========================================`n" -ForegroundColor Cyan

# Final confirmation
if (-not $DryRun -and -not $SkipConfirmation) {
    Write-Host "WARNING: This will remove direct license assignments!" -ForegroundColor Yellow
    Write-Host "Group-based assignments will remain intact.`n" -ForegroundColor Yellow
    
    $confirmation = Read-Host "Do you want to proceed? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "`nRemediation cancelled by user" -ForegroundColor Yellow
        Write-Log "Remediation cancelled by user" -Level Warning
        exit 0
    }
}

# Connect to Microsoft Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Yellow
Write-Host "Required permission: User.ReadWrite.All`n" -ForegroundColor Gray

try {
    if ($DryRun) {
        # Dry run only needs read permissions
        Connect-MgGraph -Scopes "User.Read.All" -NoWelcome -ErrorAction Stop
    } else {
        # Real remediation needs write permissions
        Connect-MgGraph -Scopes "User.ReadWrite.All" -NoWelcome -ErrorAction Stop
    }
    Write-Host "Connected successfully`n" -ForegroundColor Green
    Write-Log "Connected to Microsoft Graph" -Level Success
} catch {
    Write-Host "Failed to connect to Microsoft Graph" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Failed to connect to Graph: $_" -Level Error
    exit 1
}

# Get all SKUs for lookup
Write-Host "Retrieving tenant SKU information..." -ForegroundColor Yellow
try {
    $tenantSkus = Get-MgSubscribedSku -All -ErrorAction Stop
    Write-Host "Found $($tenantSkus.Count) license types in tenant`n" -ForegroundColor Green
} catch {
    Write-Host "Failed to retrieve SKUs" -ForegroundColor Red
    Write-Log "Failed to retrieve SKUs: $_" -Level Error
    Disconnect-MgGraph | Out-Null
    exit 1
}

# Initialize tracking
$results = [System.Collections.Generic.List[object]]::new()
$rollbackCommands = [System.Collections.Generic.List[string]]::new()
$successCount = 0
$failureCount = 0
$skippedCount = 0
$processedCount = 0

# Create rollback file header
if ($CreateRollbackFile -and -not $DryRun) {
    $rollbackPath = Join-Path $ExportPath "Rollback_Script_$timestamp.ps1"
    $rollbackHeader = @"
# Rollback Script - Generated $timestamp
# This script will re-apply licenses that were removed
# USE WITH CAUTION - Review before executing

Connect-MgGraph -Scopes "User.ReadWrite.All"

"@
    Set-Content -Path $rollbackPath -Value $rollbackHeader
    Write-Log "Rollback script: $rollbackPath" -Level Info
}

# Process each duplicate
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PROCESSING LICENSE REMOVALS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($duplicate in $duplicates) {
    $processedCount++
    $userEmail = $duplicate.Email
    $userId = $duplicate.UserId
    $licenseName = $duplicate.LicenseName
    $skuPartNumber = $duplicate.LicenseSKU
    
    Write-Progress -Activity "Processing License Removals" -Status "Processing $userEmail" -PercentComplete (($processedCount / $duplicates.Count) * 100)
    
    Write-Host "[$processedCount/$($duplicates.Count)] $userEmail - $licenseName" -ForegroundColor Cyan
    
    # Get SKU ID
    $skuId = Get-SkuIdFromPartNumber -SkuPartNumber $skuPartNumber
    
    if (-not $skuId) {
        Write-Host "Could not find SKU ID for $skuPartNumber - SKIPPED" -ForegroundColor Red
        Write-Log "Skipped $userEmail - $licenseName`: SKU not found" -Level Warning
        $skippedCount++
        
        $results.Add([PSCustomObject]@{
            UserEmail = $userEmail
            LicenseName = $licenseName
            LicenseSKU = $skuPartNumber
            Action = "SKIPPED"
            Reason = "SKU not found in tenant"
            Timestamp = Get-Date
        })
        continue
    }
    
    if ($DryRun) {
        # Dry run - just preview
        Write-Host "[DRY RUN] Would remove: $licenseName (SKU: $skuPartNumber)" -ForegroundColor Yellow
        Write-Log "DRY RUN - Would remove $licenseName from $userEmail" -Level Info
        
        $successCount++
        
        $results.Add([PSCustomObject]@{
            UserEmail = $userEmail
            LicenseName = $licenseName
            LicenseSKU = $skuPartNumber
            Action = "DRY RUN"
            Reason = "Preview only - no changes made"
            Timestamp = Get-Date
        })
    } else {
        # Real removal
        try {
            # Remove the license
            Set-MgUserLicense -UserId $userId -RemoveLicenses @($skuId) -AddLicenses @() -ErrorAction Stop
            
            Write-Host "Removed direct assignment successfully" -ForegroundColor Green
            Write-Log "SUCCESS - Removed $licenseName from $userEmail" -Level Success
            
            $successCount++
            
            $results.Add([PSCustomObject]@{
                UserEmail = $userEmail
                LicenseName = $licenseName
                LicenseSKU = $skuPartNumber
                Action = "REMOVED"
                Reason = "Direct assignment removed (group assignment retained)"
                Timestamp = Get-Date
            })
            
            # Add to rollback script
            if ($CreateRollbackFile) {
                $rollbackCommand = @"
# Restore $licenseName to $userEmail
Write-Host "Restoring $licenseName to $userEmail"
Set-MgUserLicense -UserId "$userId" -AddLicenses @{SkuId = "$skuId"} -RemoveLicenses @()

"@
                Add-Content -Path $rollbackPath -Value $rollbackCommand
            }
            
        } catch {
            Write-Host "Failed to remove license: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "FAILED - $userEmail - $licenseName`: $_" -Level Error
            
            $failureCount++
            
            $results.Add([PSCustomObject]@{
                UserEmail = $userEmail
                LicenseName = $licenseName
                LicenseSKU = $skuPartNumber
                Action = "FAILED"
                Reason = $_.Exception.Message
                Timestamp = Get-Date
            })
        }
        
        # Throttling protection
        Start-Sleep -Milliseconds 500
    }
}

Write-Progress -Activity "Processing License Removals" -Completed

# Export results
$resultsPath = Join-Path $ExportPath "Remediation_Results_$timestamp.csv"
$results | Export-Csv -Path $resultsPath -NoTypeInformation

# Display final summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "REMEDIATION COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "DRY RUN SUMMARY:" -ForegroundColor Yellow
    Write-Host "  Records Processed: $processedCount" -ForegroundColor White
    Write-Host "  Would be Removed: $successCount" -ForegroundColor Yellow
    Write-Host "  Would be Skipped: $skippedCount" -ForegroundColor Gray
    Write-Host "`nNo actual changes were made. Run without -DryRun to execute.`n" -ForegroundColor Yellow
} else {
    Write-Host "RESULTS:" -ForegroundColor Green
    Write-Host "  Successfully Removed: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "White" })
    Write-Host "  Skipped: $skippedCount" -ForegroundColor Gray
    Write-Host "  Total Processed: $processedCount" -ForegroundColor White
    
    if ($monthlySavings -gt 0 -and $successCount -gt 0) {
        $actualMonthlySavings = ($results | Where-Object { $_.Action -eq "REMOVED" } | Measure-Object -Property { $duplicates | Where-Object { $_.Email -eq $_.UserEmail } | Select-Object -First 1 -ExpandProperty MonthlyCostPerLicense } -Sum).Sum
        $actualAnnualSavings = $actualMonthlySavings * 12
        
        Write-Host "`nACHIEVED SAVINGS:" -ForegroundColor Green
        Write-Host "  Monthly: `$$($actualMonthlySavings.ToString('N2'))" -ForegroundColor Green
        Write-Host "  Annual: `$$($actualAnnualSavings.ToString('N2'))" -ForegroundColor Green
    }
}

Write-Host "`nOUTPUT FILES:" -ForegroundColor Yellow
Write-Host "  Results: $resultsPath" -ForegroundColor White
Write-Host "  Log: $logFilePath" -ForegroundColor White

if ($CreateRollbackFile -and -not $DryRun -and $successCount -gt 0) {
    Write-Host "  Rollback Script: $rollbackPath" -ForegroundColor White
    Write-Host "`nKeep the rollback script in case you need to undo changes!`n" -ForegroundColor Yellow
}

if ($failureCount -gt 0) {
    Write-Host "`n$failureCount license removals failed - check log for details`n" -ForegroundColor Yellow
}

# Display results in GridView
$results | Out-GridView -Title "Remediation Results - $successCount Removed, $failureCount Failed"

# Recommendations
if ($DryRun) {
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Review the dry run results" -ForegroundColor White
    Write-Host "  2. Run without -DryRun to execute actual removals" -ForegroundColor White
    Write-Host "  3. Consider using -CreateRollbackFile for safety`n" -ForegroundColor White
} else {
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Verify group-based assignments are working" -ForegroundColor White
    Write-Host "  2. Run Find-DuplicateLicenseAssignments.ps1 to confirm zero duplicates" -ForegroundColor White
    if ($CreateRollbackFile -and $successCount -gt 0) {
        Write-Host "  3. Test rollback script if needed (review before executing)`n" -ForegroundColor White
    }
}

Write-Log "=== Remediation Complete - Success: $successCount, Failed: $failureCount, Skipped: $skippedCount ===" -Level Info

# Disconnect
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph`n" -ForegroundColor Cyan

#endregion
