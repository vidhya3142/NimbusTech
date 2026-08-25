# Task 3 — Security Audit & Remediation

The source exercise gives six findings. Severity below is my judgment based on likely exploitability and blast radius; a real client engagement would map them to the client's risk matrix and business impact.

| Finding | Severity | Remediation | Closure evidence |
|---|---|---|---|
| RDS publicly accessible | Critical | Set `PubliclyAccessible=false`, move into private DB subnets, restrict SG ingress to app SG only. | RDS attribute + SG review + connectivity test from app subnet. |
| EC2 SG allows `0.0.0.0/0:22` | Critical | Remove SSH internet ingress. Use SSM Session Manager. If emergency SSH is unavoidable, use a tightly controlled bastion/VPN/source CIDR and temporary rule. | SG diff + SSM connectivity test. |
| S3 `nimbus-uploads` public ACLs | High | Enable Bucket Owner Enforced Object Ownership, remove public ACLs, block all public access. Review bucket policy separately. | `get-public-access-block`, ownership controls, policy review. |
| `deploy-user` has AdministratorAccess | Critical | Remove AdministratorAccess. Prefer short-lived role assumption from CI/CD. Apply a task-scoped policy after inventorying actual deployment actions. | IAM policy inventory + successful least-privilege deployment. |
| CloudTrail not enabled in `us-east-1` | High | Create a multi-region trail, log file validation, encrypt/log to a dedicated bucket, and enable management events. | Trail status + S3 log delivery + Security Hub evidence. |
| Ubuntu host has 14 Critical CVEs | Critical | Patch fleet through SSM, reboot when required, verify package/kernel versions, then rescan with Inspector. | SSM command result + package/kernel verification + Inspector closure. |

## Remediation commands / code

### A. RDS public exposure

```bash
aws rds modify-db-instance \
  --db-instance-identifier nimbus-prod-postgres \
  --no-publicly-accessible \
  --apply-immediately
```

This command is only the immediate fix. The durable fix is the Task 1 private subnet + dedicated DB security group design.

### B. Remove SSH from EC2 SG

```bash
aws ec2 describe-security-groups --group-ids sg-EXAMPLE
aws ec2 revoke-security-group-ingress \
  --group-id sg-EXAMPLE \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

Use the actual security-group ID after confirming the rule. Do not blindly revoke rules from an unknown SG.

### C. S3 public ACLs

```bash
aws s3api put-public-access-block \
  --bucket nimbus-uploads \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-ownership-controls \
  --bucket nimbus-uploads \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
```

Review the bucket policy and any CloudFront/application access pattern before removing a legitimate public use case.

### D. Remove AdministratorAccess

First inventory the user's policies:

```bash
aws iam list-attached-user-policies --user-name deploy-user
aws iam list-user-policies --user-name deploy-user
```

Then detach the AWS managed administrator policy if that is the finding:

```bash
aws iam detach-user-policy \
  --user-name deploy-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Do not immediately replace it with another broad managed policy. Create a deployment role with only the actions actually required by the pipeline. The preferred end state is CI/CD -> `sts:AssumeRole` -> deployment role, with no long-lived IAM user credentials.

### E. CloudTrail

`cloudtrail.tf` creates a dedicated log bucket, bucket policy, and multi-region trail. It is intentionally separate from application storage.

```bash
cd cloudtrail
terraform init
terraform plan
terraform apply
```

### F. CVE patching

`patch_fleet.py` uses SSM Run Command, waits for completion, then verifies the running kernel and OpenSSL package. It supports targeting by tag or explicit instance IDs.

Example:

```bash
python3 patch_fleet.py \
  --region us-east-1 \
  --tag-key Environment \
  --tag-value prod \
  --min-age-days 0 \
  --reboot \
  --execute
```

Start without `--execute` to preview targets. Use a maintenance window/change ticket for production.

## Tracking to closure

For a client, I would maintain one finding record per issue with: finding ID, resource ID, severity, owner, remediation action, due date/SLA, change ticket, evidence link, validation result, and closure date. Findings remain open until an independent check (Security Hub/Inspector/configuration query or test) confirms the control is fixed. Exceptions require an owner, business justification, compensating control, expiry date, and approval.
