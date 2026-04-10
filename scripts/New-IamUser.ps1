<#
.SYNOPSIS
    IAM User Provisioning Script - Citadel Lab
    Scenario 1: New hire account creation with OU placement,
    group assignment, and audit logging.

.PARAMETER FirstName
    User's first name

.PARAMETER LastName
    User's last name

.PARAMETER Department
    Department name. Accepted values: Sales, IT

.PARAMETER Title
    Job title

.PARAMETER Manager
    SamAccountName of the user's manager

.PARAMETER TicketNumber
    Help desk ticket or request number for audit trail

.EXAMPLE
    .\New-IamUser.ps1 -FirstName "Jane" -LastName "Doe" -Department "Sales" -Title "Account Executive" -Manager "jsmith" -TicketNumber "REQ-1042"
#>

param (
    [Parameter(Mandatory)] [string]$FirstName,
    [Parameter(Mandatory)] [string]$LastName,
    [Parameter(Mandatory)] [ValidateSet("Sales","IT")] [string]$Department,
    [Parameter(Mandatory)] [string]$Title,
    [Parameter(Mandatory)] [string]$Manager,
    [Parameter(Mandatory)] [string]$TicketNumber
)

# --- Configuration ---
$Domain         = "slytech.us"
$LogPath        = "C:\IAMLab\Logs\provisioning.log"
$TempPassword   = ConvertTo-SecureString "Welcome@Lab2025!" -AsPlainText -Force

# OU paths by department
$UserOUMap = @{
    "Sales" = "OU=Sales,OU=Users,OU=SLYTECH,DC=slytech,DC=us"
    "IT"    = "OU=IT,OU=Users,OU=SLYTECH,DC=slytech,DC=us"
}

# Role group by department
$RoleGroupMap = @{
    "Sales" = "Sales-Users"
    "IT"    = "IT-Users"
}

# Default resource groups by department
$ResourceGroupMap = @{
    "Sales" = @("FileShare-Sales-RW")
    "IT"    = @("FileShare-IT-RW", "FileShare-Sales-Read")
}

# --- Functions ---
function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $Entry
    Write-Host $Entry
}

# --- Pre-flight ---
if (-not (Test-Path "C:\IAMLab\Logs")) {
    New-Item -ItemType Directory -Path "C:\IAMLab\Logs" -Force | Out-Null
}

Write-Log "--- Provisioning started | Ticket: $TicketNumber ---"

# Build standard username: first initial + last name, lowercase
$SamAccountName = ($FirstName.Substring(0,1) + $LastName).ToLower()
$UPN            = "$SamAccountName@$Domain"
$DisplayName    = "$FirstName $LastName"

Write-Log "Target account: $SamAccountName | Department: $Department | Title: $Title"

# Check for duplicate
if (Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue) {
    Write-Log "CONFLICT: Account $SamAccountName already exists. Halting." "ERROR"
    exit 1
}

# Validate manager exists
$ManagerObj = Get-ADUser -Filter { SamAccountName -eq $Manager } -ErrorAction SilentlyContinue
if (-not $ManagerObj) {
    Write-Log "Manager account '$Manager' not found in AD. Halting." "ERROR"
    exit 1
}

# --- Create user ---
try {
    New-ADUser `
        -SamAccountName     $SamAccountName `
        -UserPrincipalName  $UPN `
        -GivenName          $FirstName `
        -Surname            $LastName `
        -DisplayName        $DisplayName `
        -Name               $DisplayName `
        -Title              $Title `
        -Department         $Department `
        -Manager            $ManagerObj `
        -Path               $UserOUMap[$Department] `
        -AccountPassword    $TempPassword `
        -ChangePasswordAtLogon $true `
        -Enabled            $true

    Write-Log "Account created: $SamAccountName in $($UserOUMap[$Department])"
}
catch {
    Write-Log "Failed to create account: $_" "ERROR"
    exit 1
}

# --- Assign role group ---
try {
    Add-ADGroupMember -Identity $RoleGroupMap[$Department] -Members $SamAccountName
    Write-Log "Role group assigned: $($RoleGroupMap[$Department])"
}
catch {
    Write-Log "Failed to assign role group: $_" "ERROR"
}

# --- Assign resource groups ---
foreach ($Group in $ResourceGroupMap[$Department]) {
    try {
        Add-ADGroupMember -Identity $Group -Members $SamAccountName
        Write-Log "Resource group assigned: $Group"
    }
    catch {
        Write-Log "Failed to assign resource group '$Group': $_" "ERROR"
    }
}

# --- Summary ---
Write-Log "Provisioning complete for $DisplayName ($SamAccountName)"
Write-Log "UPN: $UPN | OU: $($UserOUMap[$Department]) | Ticket: $TicketNumber"
Write-Log "--- Provisioning ended ---"

Write-Host ""
Write-Host "Account ready. Temp password: Welcome@Lab2025! (user must change at first logon)" -ForegroundColor Green