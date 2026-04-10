# Provisioning Runbook

**Version:** 1.0  
**Last Updated:** 2026-04-09  
**Owner:** IAM Team  
**SLA:** Account live within 2 hours of approved request

---

## Purpose

Standard procedure for creating a new Active Directory user account, assigning the correct OU placement, role group, and resource group access, and logging the action with a ticket reference.

---

## Prerequisites

- Approved new hire request with ticket number
- Manager account exists in AD
- Department confirmed: Sales or IT
- Script located at: `C:\Users\Administrator\Desktop\New-IamUser.ps1`
- Log directory exists: `C:\IAMLab\Logs\`

---

## Step 1: Verify domain password policy

Before running the script in any environment, confirm the minimum password length and complexity requirements:

```powershell
Get-ADDefaultDomainPasswordPolicy
```

Ensure the temp password in the script meets `MinPasswordLength` and `ComplexityEnabled` requirements. Update `$TempPassword` in the script if needed.

---

## Step 2: Run the provisioning script

```powershell
cd C:\Users\Administrator\Desktop
.\New-IamUser.ps1 `
  -FirstName "Jane" `
  -LastName "Doe" `
  -Department "Sales" `
  -Title "Account Executive" `
  -Manager "jsmith" `
  -TicketNumber "REQ-XXXX"
```

Accepted values for `-Department`: `Sales`, `IT`

---

## Step 3: Verify account creation

```powershell
Get-ADUser -Identity "jdoe" -Properties Department, Title, MemberOf, DistinguishedName |
  Select-Object Name, SamAccountName, Department, Title, DistinguishedName, MemberOf
```

Confirm:
- Account is in the correct department OU
- Role group assigned (Sales-Users or IT-Users)
- Resource group(s) assigned (FileShare-Sales-RW or FileShare-IT-RW)
- Account is enabled

---

## Step 4: Verify audit log

```powershell
Get-Content C:\IAMLab\Logs\provisioning.log | Select-Object -Last 20
```

Confirm all steps logged with no ERROR entries for this account.

---

## Step 5: M365 license assignment (production)

In a production environment, assign the appropriate M365 license via Microsoft Graph after AD account creation:

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

Set-MgUserLicense -UserId "jdoe@slytech.us" `
  -AddLicenses @{SkuId = "<M365-License-SkuId>"} `
  -RemoveLicenses @()
```

License SKU is determined by department and role. Standard users: Business Premium. Elevated roles: E3 or E5.

---

## Step 6: Communicate to requester

Notify the manager or HR contact that the account is active. Include:
- UPN (username@domain)
- Temp password: `Welcome@Lab2026!` (user must change at first logon)
- OU placement and group assignments for reference

---

## Default group assignments by department

| Department | Role Group | Resource Groups |
|------------|------------|-----------------|
| Sales | Sales-Users | FileShare-Sales-RW |
| IT | IT-Users | FileShare-IT-RW, FileShare-Sales-Read |

---

## Error handling

| Error | Cause | Resolution |
|-------|-------|------------|
| CONFLICT: Account already exists | SamAccountName taken | Check for existing account, use alternate naming if needed |
| Password does not meet requirements | Policy mismatch | Run `Get-ADDefaultDomainPasswordPolicy`, update `$TempPassword` |
| Manager account not found | Invalid `-Manager` value | Verify manager SamAccountName exists in AD |

---

## Audit trail

All provisioning actions are logged to: `C:\IAMLab\Logs\provisioning.log`

Log format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`
