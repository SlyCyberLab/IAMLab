# IAMLab

Active Directory IAM homelab built on Proxmox. Covers provisioning and deprovisioning workflows, OU and group structure following least-privilege, quarterly access review simulation, and GPO-based access control by department.

## Blog Post
[Building an IAM Lab](https://blog.slytech.us/iam-lab)

## Scripts
- `New-IamUser.ps1`: New hire provisioning with audit logging
- `Remove-IamUser.ps1`: Offboarding with group stripping and 30-day retention
- `Get-IamAccessReview.ps1`: Quarterly access review report generator

## Runbooks
- Provisioning runbook
- Deprovisioning runbook
- Access review runbook

## Lab Infrastructure
- dc01: Windows Server 2025, AD DS, DNS, GPO
- fs01: Windows Server 2025, department file shares
- WS01: Sales department endpoint
- WS02: IT department endpoint

## Tools
Active Directory, PowerShell, Group Policy, Windows Server 2025
