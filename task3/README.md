# Task 3 — Security Audit & Remediation

## Overview

This task addresses six security findings in the NimbusTech AWS environment. The severity ratings are based on potential impact and exposure.

| Finding                               | Severity | Remediation                                            |
| ------------------------------------- | -------- | ------------------------------------------------------ |
| RDS publicly accessible               | Critical | Make RDS private and allow access only from the App SG |
| EC2 SG allows SSH from `0.0.0.0/0`    | Critical | Remove port 22 and use SSM Session Manager             |
| S3 bucket has public ACLs             | High     | Block public access and enable Bucket Owner Enforced   |
| `deploy-user` has AdministratorAccess | Critical | Remove admin access and use a least-privilege role     |
| CloudTrail not enabled                | High     | Enable a multi-region CloudTrail trail                 |
| Ubuntu EC2 has 14 Critical CVEs       | Critical | Patch EC2 fleet using SSM and verify the updates       |

---

## A. RDS Public Access

Disable public access:

```bash
aws rds modify-db-instance \
  --db-instance-identifier nimbus-prod-postgres \
  --no-publicly-accessible \
  --apply-immediately \
  --region us-east-1
```

The permanent solution is to place RDS in private DB subnets and allow port `5432` only from the application security group.

---

## B. Remove Public SSH

Remove the public SSH rule:

```bash
aws ec2 revoke-security-group-ingress \
  --group-id sg-EXAMPLE \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region us-east-1
```

EC2 administration should use **AWS Systems Manager Session Manager** instead of public SSH.

---

## C. Secure S3

Block public access:

```bash
aws s3api put-public-access-block \
  --bucket nimbus-uploads \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Enable Bucket Owner Enforced:

```bash
aws s3api put-bucket-ownership-controls \
  --bucket nimbus-uploads \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
```

Also review the bucket policy to ensure there is no remaining public access.

---

## D. Remove AdministratorAccess

Check attached policies:

```bash
aws iam list-attached-user-policies \
  --user-name deploy-user
```

Remove the administrator policy:

```bash
aws iam detach-user-policy \
  --user-name deploy-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

The preferred solution is a CI/CD deployment role with only the permissions required for deployment.

---

## E. Enable CloudTrail

CloudTrail is implemented using:

```text
cloudtrail/cloudtrail.yaml
```

Deploy:

```bash
aws cloudformation deploy \
  --template-file cloudtrail/cloudtrail.yaml \
  --stack-name nimbustech-cloudtrail \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

Verify:

```bash
aws cloudtrail get-trail-status \
  --name nimbustech-cloudtrail \
  --region us-east-1
```

Expected:

```text
IsLogging: true
```

The trail should be multi-region and deliver logs to an S3 bucket.

---

## F. Patch Critical Ubuntu CVEs

The script:

```text
patch_ec2.py
```

uses **AWS Systems Manager Run Command** to patch the EC2 fleet.

Current flow:

```text
Find running EC2s
      ↓
Send SSM command
      ↓
apt update + upgrade
      ↓
Update OpenSSL
      ↓
Check SSM status
      ↓
Verify kernel + OpenSSL
```

Run:

```bash
python3 patch_ec2.py
```

The script runs:

```bash
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install --only-upgrade openssl
```

and verifies:

```bash
uname -r
openssl version
```

### Important

The current script selects running instances **without a `Name` tag** as its target fleet. For production, I would use tags such as `Environment=production` or `PatchGroup=critical-linux` instead.

If a kernel update requires a reboot, the instance should be rebooted during an approved maintenance window and the verification should be repeated.

Finally, run an **AWS Inspector rescan** to confirm the 14 Critical CVEs are resolved.

---

## Required Permissions

The script operator needs:

```text
ec2:DescribeInstances
ssm:SendCommand
ssm:ListCommandInvocations
ssm:GetCommandInvocation
```

The EC2 instances must be managed by Systems Manager and have the appropriate SSM IAM role.

---

## Tracking Findings to Closure

For each finding, I would track:

* Finding ID
* Severity
* Resource
* Owner
* Remediation action
* Change ticket
* Evidence
* Validation result
* Closure date

Process:

```text
Finding
   ↓
Assign Owner
   ↓
Apply Fix
   ↓
Validate
   ↓
Inspector / Security Hub Rescan
   ↓
Close
```

A finding should only be closed after the remediation has been successfully validated.

## Assumptions

* Region: `us-east-1`
* Database: PostgreSQL RDS
* S3 bucket: `nimbus-uploads`
* IAM user: `deploy-user`
* EC2 instances: Ubuntu
* EC2 instances are managed by AWS Systems Manager
* Production changes should be tested before implementation
