<#
.SYNOPSIS
    IAM User Deprovisioning Script - Citadel Lab
    Scenario 2: Offboarding workflow with account disable,
    group stripping, OU move, and audit logging.

.PARAMETER SamAccountName
    The SamAccountName of the user to deprovision

.PARAMETER TicketNumber
    Help desk ticket or request number for audit trail

.PARAMETER ApprovedBy
    Name or username of the manager who approved the offboarding

.EXAMPLE
    .\Remove-IamUser.ps1 -SamAccountName "jblake" -TicketNumber "REQ-2001" -ApprovedBy "Administrator"
#>

param (
    [Parameter(Mandatory)] [string]$SamAccountName,
    [Parameter(Mandatory)] [string]$TicketNumber,
    [Parameter(Mandatory)] [string]$ApprovedBy
)

# --- Configuration ---
$LogPath   = "C:\IAMLab\Logs\deprovisioning.log"
$DisabledOU = "OU=Disabled,OU=Users,OU=SLYTECH,DC=slytech,DC=us"

# --- Functions ---
function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $Entry
    Write-Host $Entry
}

# --- Pre-flight ---
Write-Log "--- Deprovisioning started | Ticket: $TicketNumber | Approved by: $ApprovedBy ---"

# Verify user exists
$User = Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -Properties MemberOf, DistinguishedName, DisplayName -ErrorAction SilentlyContinue
if (-not $User) {
    Write-Log "Account '$SamAccountName' not found in AD. Halting." "ERROR"
    exit 1
}

Write-Log "Target account: $SamAccountName | Display name: $($User.DisplayName)"

# --- Step 1: Disable the account ---
try {
    Disable-ADAccount -Identity $SamAccountName
    Write-Log "Account disabled: $SamAccountName"
}
catch {
    Write-Log "Failed to disable account: $_" "ERROR"
    exit 1
}

# --- Step 2: Strip all group memberships ---
$Groups = $User.MemberOf
if ($Groups.Count -eq 0) {
    Write-Log "No group memberships found to remove."
} else {
    foreach ($Group in $Groups) {
        try {
            Remove-ADGroupMember -Identity $Group -Members $SamAccountName -Confirm:$false
            Write-Log "Removed from group: $Group"
        }
        catch {
            Write-Log "Failed to remove from group '$Group': $_" "ERROR"
        }
    }
}

# --- Step 3: Move to Disabled OU ---
try {
    Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledOU
    Write-Log "Account moved to Disabled OU: $DisabledOU"
}
catch {
    Write-Log "Failed to move account to Disabled OU: $_" "ERROR"
}

# --- Step 4: Update description with offboarding date ---
try {
    $OffboardDate = Get-Date -Format "yyyy-MM-dd"
    Set-ADUser -Identity $SamAccountName -Description "OFFBOARDED: $OffboardDate | Ticket: $TicketNumber | Approved: $ApprovedBy"
    Write-Log "Account description updated with offboarding details"
}
catch {
    Write-Log "Failed to update account description: $_" "ERROR"
}

# --- Summary ---
Write-Log "Deprovisioning complete for $($User.DisplayName) ($SamAccountName)"
Write-Log "Ticket: $TicketNumber | Approved by: $ApprovedBy | Retained in Disabled OU for 30 days"
Write-Log "Scheduled delete date: $((Get-Date).AddDays(30).ToString('yyyy-MM-dd'))"
Write-Log "--- Deprovisioning ended ---"

Write-Host ""
Write-Host "Offboarding complete. Account disabled, groups stripped, moved to Disabled OU." -ForegroundColor Yellow
Write-Host "Scheduled for permanent deletion: $((Get-Date).AddDays(30).ToString('yyyy-MM-dd'))" -ForegroundColor Yellow