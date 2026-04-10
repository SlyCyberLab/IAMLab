# Deprovisioning Runbook

**Version:** 1.0  
**Last Updated:** 2026-04-09  
**Owner:** IAM Team  
**SLA:** Account disabled within 1 hour of approved offboarding request

---

## Purpose

Standard procedure for offboarding a departing user. Covers account disable, group membership removal, OU move to Disabled, description stamping with offboarding details, and 30-day retention before permanent deletion.

---

## Prerequisites

- Approved offboarding request with ticket number
- Manager or HR approval documented
- SamAccountName of the departing user confirmed
- Script located at: `C:\Users\Administrator\Desktop\Remove-IamUser.ps1`

---

## Step 1: Confirm the account exists

```powershell
Get-ADUser -Identity "jdoe" -Properties Enabled, MemberOf, DistinguishedName |
  Select-Object Name, SamAccountName, Enabled, DistinguishedName, MemberOf
```

Confirm the account is active and note current group memberships for the record.

---

## Step 2: Run the deprovisioning script

```powershell
cd C:\Users\Administrator\Desktop
.\Remove-IamUser.ps1 `
  -SamAccountName "jdoe" `
  -TicketNumber "REQ-XXXX" `
  -ApprovedBy "manager-username"
```

The script executes the following steps in order:
1. Disables the account
2. Removes all group memberships
3. Moves the account to `OU=Disabled,OU=Users,OU=SLYTECH`
4. Stamps the account description with offboarding date, ticket number, and approver
5. Logs the scheduled delete date (30 days from offboarding)

---

## Step 3: Verify deprovisioning

```powershell
Get-ADUser -Identity "jdoe" -Properties Enabled, MemberOf, DistinguishedName, Description |
  Select-Object Name, Enabled, DistinguishedName, Description, MemberOf
```

Confirm:
- `Enabled` is `False`
- `DistinguishedName` shows the Disabled OU
- `MemberOf` is empty
- `Description` contains offboarding date, ticket, and approver

---

## Step 4: Verify audit log

```powershell
Get-Content C:\IAMLab\Logs\deprovisioning.log | Select-Object -Last 20
```

Confirm all steps logged with no ERROR entries for this account. Note the scheduled delete date in the log.

---

## Step 5: Calendar the deletion

Set a reminder for the scheduled delete date (30 days from offboarding). On that date, run:

```powershell
Remove-ADUser -Identity "jdoe" -Confirm:$false
```

Do not delete before the 30-day retention period unless directed by legal or HR.

---

## Retention policy

| Phase | Duration | Action |
|-------|----------|--------|
| Immediate | Day 0 | Disable, strip groups, move to Disabled OU |
| Retention | Days 1-30 | Account held in Disabled OU, no access |
| Deletion | Day 30 | Permanent removal from AD |

---

## Error handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Account not found | Wrong SamAccountName | Verify with `Get-ADUser -Filter {DisplayName -like "*name*"}` |
| Failed to remove from group | Permission issue | Run as Domain Admin, retry group removal manually |
| Failed to move account | OU path issue | Verify Disabled OU exists at correct path |

---

## Audit trail

All deprovisioning actions are logged to: `C:\IAMLab\Logs\deprovisioning.log`

Log format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] Message`
