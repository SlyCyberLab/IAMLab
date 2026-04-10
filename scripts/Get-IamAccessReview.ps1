<#
.SYNOPSIS
    IAM Quarterly Access Review Script - Citadel Lab
    Scenario 4: Pulls all domain users with group memberships,
    last logon, and account status. Flags stale accounts.
    Outputs a formatted CSV report for manager review.

.PARAMETER OutputPath
    Path to save the CSV report. Defaults to C:\IAMLab\Reports\

.PARAMETER StaleDays
    Number of days without logon to flag as stale. Defaults to 90.

.EXAMPLE
    .\Get-IamAccessReview.ps1
    .\Get-IamAccessReview.ps1 -StaleDays 30
#>

param (
    [string]$OutputPath = "C:\IAMLab\Reports",
    [int]$StaleDays = 90
)

# --- Configuration ---
$LogPath    = "C:\IAMLab\Logs\access-review.log"
$ReportDate = Get-Date -Format "yyyy-MM-dd"
$ReportFile = "$OutputPath\AccessReview-$ReportDate.csv"
$SearchBase = "OU=SLYTECH,DC=slytech,DC=us"

# --- Functions ---
function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $Entry
    Write-Host $Entry
}

# --- Pre-flight ---
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Write-Log "--- Access review started | Stale threshold: $StaleDays days ---"

# --- Pull all users ---
$Users = Get-ADUser -Filter * `
    -SearchBase $SearchBase `
    -Properties DisplayName, SamAccountName, Department, Title, `
                Enabled, LastLogonDate, MemberOf, Description, `
                PasswordLastSet, Created

Write-Log "Total accounts found: $($Users.Count)"

# --- Build report rows ---
$Report = foreach ($User in $Users) {

    # Resolve group names from DNs
    $Groups = ($User.MemberOf | ForEach-Object {
        (($_ -split ',')[0] -replace 'CN=','')
    }) -join '; '

    # Determine stale status
    $DaysSinceLogon = $null
    $StaleFlag = "No"

    if ($User.LastLogonDate) {
        $DaysSinceLogon = (New-TimeSpan -Start $User.LastLogonDate -End (Get-Date)).Days
        if ($DaysSinceLogon -ge $StaleDays) {
            $StaleFlag = "YES - REVIEW"
        }
    } else {
        $StaleFlag = "YES - NEVER LOGGED ON"
    }

    # Build row
    [PSCustomObject]@{
        DisplayName      = $User.DisplayName
        SamAccountName   = $User.SamAccountName
        Department       = $User.Department
        Title            = $User.Title
        Enabled          = $User.Enabled
        Created          = $User.Created
        LastLogon        = $User.LastLogonDate
        DaysSinceLogon   = $DaysSinceLogon
        StaleFlag        = $StaleFlag
        GroupMemberships = $Groups
        Description      = $User.Description
    }
}

# --- Export to CSV ---
$Report | Export-Csv -Path $ReportFile -NoTypeInformation
Write-Log "Report exported: $ReportFile"

# --- Console summary ---
$TotalUsers   = $Report.Count
$EnabledUsers = ($Report | Where-Object { $Enabled -eq $true }).Count
$StaleUsers   = ($Report | Where-Object { $StaleFlag -ne "No" }).Count

Write-Log "Total users reviewed: $TotalUsers"
Write-Log "Stale or never logged on: $($Report | Where-Object { $_.StaleFlag -ne 'No' } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Log "--- Access review complete ---"

# --- Print to screen ---
Write-Host ""
Write-Host "Access Review Report: $ReportDate" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan
$Report | Format-Table DisplayName, Department, Enabled, LastLogon, StaleFlag, GroupMemberships -AutoSize
Write-Host ""
Write-Host "Full report saved to: $ReportFile" -ForegroundColor Green