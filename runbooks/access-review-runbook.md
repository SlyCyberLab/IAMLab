# Access Review Runbook

**Version:** 1.0  
**Last Updated:** 2026-04-09  
**Owner:** IAM Team  
**Cadence:** Quarterly

---

## Purpose

Standard procedure for running the quarterly access review. Pulls all domain user accounts with group memberships, last logon date, and account status. Flags stale and never-logged-on accounts for manager review and documents outcomes.

---

## Prerequisites

- Domain Admin credentials on dc01
- Script located at: `C:\Users\Administrator\Desktop\Get-IamAccessReview.ps1`
- Reports directory exists: `C:\IAMLab\Reports\`
- Manager contacts available for each department

---

## Step 1: Run the access review script

```powershell
cd C:\Users\Administrator\Desktop
.\Get-IamAccessReview.ps1 -StaleDays 90
```

For a stricter review use `-StaleDays 30`. The script outputs:
- Console table showing all accounts with stale flags
- CSV report at `C:\IAMLab\Reports\AccessReview-YYYY-MM-DD.csv`
- Log entry at `C:\IAMLab\Logs\access-review.log`

---

## Step 2: Review the CSV output

Open `C:\IAMLab\Reports\AccessReview-YYYY-MM-DD.csv` and filter for accounts where `StaleFlag` is not `No`.

Key columns to review:

| Column | What to check |
|--------|---------------|
| DisplayName | Empty = orphaned account, investigate ownership |
| Enabled | True on a stale account = action required |
| LastLogon | Blank = never logged on |
| StaleFlag | YES = requires manager decision |
| GroupMemberships | Broad access on stale account = immediate disable |

---

## Step 3: Send for manager review

Export flagged accounts per department and send to each department manager. Required response per account:

- **Retain**: Account is active, user confirmed by manager
- **Disable**: Account no longer needed, disable immediately
- **Deprovision**: Account and user fully offboarded, run deprovisioning runbook

Set a response deadline of 5 business days. Accounts with no response default to disable.

---

## Step 4: Action flagged accounts

**Disable (no full offboarding needed):**
```powershell
Disable-ADAccount -Identity "username"
Set-ADUser -Identity "username" -Description "DISABLED: YYYY-MM-DD | Access review | No manager response"
```

**Deprovision (full offboarding):**
Follow the Deprovisioning Runbook with the access review ticket number.

**Retain (no action):**
Document the manager confirmation and move on.

---

## Step 5: Document outcomes

For each flagged account, record in the CSV or a separate tracking document:

| Field | Value |
|-------|-------|
| Account | SamAccountName |
| Action taken | Retained / Disabled / Deprovisioned |
| Approved by | Manager name |
| Date actioned | YYYY-MM-DD |
| Ticket number | REQ-XXXX |

This document is the evidence artifact for audit purposes.

---

## Step 6: Verify and close

After all actions are taken, run the script once more to confirm no flagged accounts remain enabled:

```powershell
.\Get-IamAccessReview.ps1 -StaleDays 90
```

Review the output. All previously flagged accounts should now show `Enabled: False` or be absent from the report entirely.

---

## Stale account thresholds

| Threshold | Use case |
|-----------|----------|
| 90 days | Standard quarterly review |
| 30 days | Stricter environments, high-security OUs |
| Never logged on | Always flag regardless of threshold |

---

## Audit trail

Access review actions are logged to: `C:\IAMLab\Logs\access-review.log`

CSV reports are retained at: `C:\IAMLab\Reports\AccessReview-YYYY-MM-DD.csv`

Retain reports for a minimum of 1 year for audit purposes.
