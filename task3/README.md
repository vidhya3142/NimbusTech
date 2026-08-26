# Task 3 — Security Audit & Remediation

The source exercise provides six security findings. The severity below is my judgment based on the likely exploitability and impact. In a real client engagement, I would also consider the client's risk matrix and business impact.

## Security Findings

| Finding                                          | Severity | Remediation                                                                                                                           | Closure Evidence                                                                             |
| ------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| RDS publicly accessible                          | Critical | Set `PubliclyAccessible=false`, move RDS into private DB subnets, and allow database access only from the application security group. | RDS configuration, security group review, and connectivity test from the application subnet. |
| EC2 security group allows `0.0.0.0/0` on port 22 | Critical | Remove public SSH access. Use AWS Systems Manager Session Manager instead.                                                            | Security group review and successful SSM connection.                                         |
| S3 `nimbus-uploads` has public ACLs              | High     | Block public access, disable ACL-based access using Bucket Owner Enforced ownership, and review the bucket policy.                    | S3 Public Access Block and ownership settings.                                               |
| `deploy-user` has AdministratorAccess            | Critical | Remove AdministratorAccess and use a least-privilege deployment role.                                                                 | IAM policy review and successful deployment using the new role.                              |
| CloudTrail is not enabled in `us-east-1`         | High     | Enable a multi-region CloudTrail trail and store logs in a dedicated S3 bucket.                                                       | CloudTrail status and S3 log delivery verification.                                          |
| Ubuntu EC2 has 14 Critical CVEs                  | Critical | Patch the EC2 instances using SSM Run Command, reboot if required, and verify the kernel and OpenSSL versions.                        | SSM command result, kernel/OpenSSL verification, and Inspector rescan.                       |

---

# Remediation

## A. RDS Public Access

The immediate fix is to make the RDS instance private:

```bash
aws rds modify-db-instance \
  --db-instance-identifier nimbus-prod-postgres \
  --no-publicly-accessible \
  --apply-immediately
```

This is only the immediate fix.

The permanent solution is the architecture from **Task 1**, where RDS is placed in private database subnets and the database security group allows PostgreSQL traffic only from the application security group.

---

## B. Remove Public SSH Access

First check the security group:

```bash
aws ec2 describe-security-groups \
  --group-ids sg-EXAMPLE
```

Remove the public SSH rule:

```bash
aws ec2 revoke-security-group-ingress \
  --group-id sg-EXAMPLE \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

The actual security group ID should be used after confirming the affected resource.

For normal administration, I would use **AWS Systems Manager Session Manager** instead of SSH.

---

## C. Secure S3 Bucket

Block public access:

```bash
aws s3api put-public-access-block \
  --bucket nimbus-uploads \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Enable Bucket Owner Enforced ownership:

```bash
aws s3api put-bucket-ownership-controls \
  --bucket nimbus-uploads \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
```

I would also review the bucket policy before making further changes to make sure there is no legitimate application requirement for public access.

---

## D. Remove AdministratorAccess

First check the policies attached to the user:

```bash
aws iam list-attached-user-policies \
  --user-name deploy-user
```

Also check inline policies:

```bash
aws iam list-user-policies \
  --user-name deploy-user
```

If the finding is caused by the AWS managed `AdministratorAccess` policy, remove it:

```bash
aws iam detach-user-policy \
  --user-name deploy-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

I would not replace it with another administrator-level policy.

The preferred design is:

```text
CI/CD Pipeline
      |
      v
STS AssumeRole
      |
      v
Least-Privilege Deployment Role
      |
      v
AWS Resources
```

The deployment role should contain only the permissions required by the application deployment process.

---

## E. Enable CloudTrail

The CloudFormation template is located at:

```text
cloudtrail/cloudtrail.yaml
```

It creates:

* A dedicated S3 bucket for CloudTrail logs
* S3 bucket policy for CloudTrail
* A multi-region CloudTrail trail
* Management event logging
* Log file validation

Validate the template:

```bash
aws cloudformation validate-template \
  --template-body file://cloudtrail/cloudtrail.yaml
```

Deploy it:

```bash
aws cloudformation deploy \
  --template-file cloudtrail/cloudtrail.yaml \
  --stack-name nimbustech-cloudtrail \
  --capabilities CAPABILITY_IAM
```

After deployment, verify the trail:

```bash
aws cloudtrail describe-trails
```

Then check that logging is enabled:

```bash
aws cloudtrail get-trail-status \
  --name nimbustech-cloudtrail
```

---

# F. Patch Critical Ubuntu CVEs

The script:

```text
patch_ec2.py
```

uses AWS Systems Manager Run Command to patch Ubuntu EC2 instances.

The basic flow is:

```text
Find running EC2 instances
        |
        v
Find instances without Name tag
        |
        v
Send SSM Run Command
        |
        v
apt update + upgrade
        |
        v
Update OpenSSL
        |
        v
Check command status
        |
        v
Verify kernel + OpenSSL
```

Run the script:

```bash
python3 patch_ec2.py
```

The script updates:

```bash
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install --only-upgrade openssl
```

It then verifies:

```bash
uname -r
openssl version
```

For production, I would run this during an approved maintenance window and perform an AWS Inspector rescan after patching.

---

# Required AWS Permissions

The person running the patching script needs permissions for:

* `ec2:DescribeInstances`
* `ssm:SendCommand`
* `ssm:ListCommandInvocations`

The EC2 instances also need to be managed by **AWS Systems Manager** and have the appropriate SSM IAM role attached.

---

# Testing the Patch

After the patch command finishes, the script checks the SSM command status.

A successful result looks like:

```text
i-0123456789abcdef0 : Success
Patch completed successfully
```

It then runs another SSM command to display:

```text
Kernel:
6.x.x-...

OpenSSL:
OpenSSL 3.x.x ...
```

For the final security validation, I would run AWS Inspector again and confirm that the Critical CVEs have been resolved.

---

# Tracking Findings to Closure

For a client, I would maintain one finding record for each security issue.

The tracking record would contain:

* Finding ID
* Resource ID
* Severity
* Finding description
* Owner
* Remediation action
* Due date
* Change ticket
* Evidence
* Validation result
* Closure date

A finding should remain **open** until there is evidence that the issue has been fixed.

For example:

```text
Finding
   |
Assign owner
    |
Create remediation ticket
    |
Apply fix
    |
Validate fix
    |
Collect evidence
    |
Security Hub / Inspector rescan
   |
Close finding
```

If a finding cannot be fixed immediately, I would document the exception with:

* Business justification
* Compensating control
* Risk owner
* Approval
* Expiration/review date

---

# Assumptions

* The EC2 instances are Ubuntu and are managed by AWS Systems Manager.
* The RDS database is PostgreSQL.
* The affected S3 bucket is `nimbus-uploads`.
* The affected IAM user is `deploy-user`.
* The environment is primarily deployed in `us-east-1`.
* Production changes should be tested in a non-production environment first.
