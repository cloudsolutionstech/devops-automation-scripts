# DevOps Automation Scripts (Ubuntu + CentOS + Amazon Linux)

A practical collection of **small automation scripts** that save hours every week across:
- ✅ Ubuntu (18.04/20.04/22.04/24.04)
- ✅ CentOS / RHEL / Rocky / Alma (7/8/9)
- ✅ Amazon Linux (AL2 + AL2023)

These scripts are intentionally small, readable, and easy to adapt for:
- Monitoring
- Cleanup/housekeeping
- AWS operations (EC2 scheduling, snapshot verification, IAM reporting)
- Daily system summaries
- Safer cron execution (wrapper)

---

## Repo Structure

```text
devops-automation-scripts/
├── lib/
│   └── common.sh
├── install/
│   └── install.sh
├── scripts/
│   ├── 01_disk_usage_alert.sh
│   ├── 02_log_cleanup.sh
│   ├── 03_ec2_start_stop.sh
│   ├── 04_backup_verify_aws_snapshots.sh
│   ├── 05_iam_audit.sh
│   ├── 06_access_key_rotation_report.sh
│   ├── 07_service_health_check.sh
│   ├── 08_server_bootstrap.sh
│   ├── 09_git_stale_branches.sh
│   ├── 10_ssl_expiry_check.sh
│   ├── 11_cron_job_wrapper.sh
│   └── 12_daily_system_health_summary.sh
├── cron/
│   └── crontab_examples.txt
├── iam/
│   ├── ec2_start_stop_policy.json
│   ├── snapshot_verify_policy.json
│   └── iam_audit_policy.json
└── .github/
    └── workflows/
        └── shellcheck.yml

## Requirements
System requirements (Linux)
- Bash
- curl, wget, unzip, openssl
- jq (recommended)
- mail/mailx (optional for email alerts)

## AWS scripts requirements
Scripts 03, 04, 05, 06 require:
- AWS CLI v2 installed
- Credentials via one of:
Instance profile (recommended)
aws configure with least-privilege IAM user/role

## Quick Start (Local)
```
chmod +x scripts/*.sh
./scripts/12_daily_system_health_summary.sh
```

## Install (Recommended)
This installs dependencies, copies repo to /opt/devops-automation-scripts, and symlinks scripts to /usr/local/bin.

```
sudo bash install/install.sh
```

## Choose scheduling method
Use systemd timers (recommended):

```
sudo USE_SYSTEMD=true bash install/install.sh
```

Or use cron jobs:

```
sudo USE_SYSTEMD=false bash install/install.sh
```

## Running Scripts (Examples)
Disk alert

```
THRESHOLD=80 EMAIL_TO=you@example.com /usr/local/bin/01_disk_usage_alert
```

Log cleanup

```
LOG_DIR=/var/log DAYS_OLD=14 DRY_RUN=true /usr/local/bin/02_log_cleanup
```

## EC2 office-hours scheduling (tag-based)
- Tag instances:
- Schedule=OfficeHours
- Then:

```
REGION=us-east-1 TAG_KEY=Schedule TAG_VALUE=OfficeHours /usr/local/bin/03_ec2_start_stop stop
REGION=us-east-1 TAG_KEY=Schedule TAG_VALUE=OfficeHours /usr/local/bin/03_ec2_start_stop start
```

## Snapshot freshness verification (tag-based)
- Tag volumes:
- Backup=Daily
- Then:

```
REGION=us-east-1 MAX_AGE_HOURS=30 TAG_KEY=Backup TAG_VALUE=Daily /usr/local/bin/04_backup_verify_aws_snapshots
```

## IAM audit report
```
/usr/local/bin/05_iam_audit > iam_audit.csv
/usr/local/bin/06_access_key_rotation_report > key_rotation_report.csv
```

## Cron Examples
- See: cron/crontab_examples.txt

## IAM Least Privilege
- Policies are provided in:
iam/ec2_start_stop_policy.json
iam/snapshot_verify_policy.json
iam/iam_audit_policy.json

- Apply them to:
An IAM role used by an EC2 instance, OR
An IAM user/role used by AWS CLI

## Security Notes
- Prefer instance profiles instead of static access keys.
- Tag-based automation avoids accidental changes to unintended resources.
- Always test with a non-production account/region first.

## Contributing
- PRs welcome. Keep scripts:
small
readable
safe defaults
consistent formatting (bash, shellcheck)

```

# 2) IAM Policies (Least Privilege) ✅

Create folder: `iam/`

## A) EC2 Start/Stop Policy — `iam/ec2_start_stop_policy.json`

Allows describing instances + starting/stopping only.  
(Restrict by region in your role usage and by tag at the script level.)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescribeInstances",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "StartStopInstances",
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

Note: Tag-level restrictions for Start/Stop are possible but can be tricky across resources; many teams enforce tag restrictions using SCPs/permission boundaries. If you want, tell me your tag key/value and I’ll generate a stricter version.

B) Snapshot Verify Policy — iam/snapshot_verify_policy.json
Allows describing volumes + snapshots to verify backup freshness.
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescribeVolumesAndSnapshots",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots"
      ],
      "Resource": "*"
    }
  ]
}
```

C) IAM Audit Policy — iam/iam_audit_policy.json
Allows listing IAM users, access keys, and checking last-used info.
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListUsersAndKeys",
      "Effect": "Allow",
      "Action": [
        "iam:ListUsers",
        "iam:ListAccessKeys",
        "iam:GetAccessKeyLastUsed"
      ],
      "Resource": "*"
    }
  ]
}
```

3) GitHub Actions (ShellCheck) ✅
Create: .github/workflows/shellcheck.yml

```
name: ShellCheck

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install ShellCheck
        run: |
          sudo apt-get update -y
          sudo apt-get install -y shellcheck

      - name: Run ShellCheck
        run: |
          shellcheck -x lib/common.sh
          shellcheck -x scripts/*.sh
          shellcheck -x install/*.sh
```


