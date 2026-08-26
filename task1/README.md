# Task 1 — Infrastructure Architecture & IaC

This task is implemented using **AWS CloudFormation YAML**, not CloudFormation.

## Files
- `cloudformation.yaml` — complete VPC, subnets, routes, NAT, ALB, private EC2 Auto Scaling Group, security groups and private Multi-AZ RDS.
- `SECURITY_GROUPS.md` — least-privilege rule explanation.
- `diagram/architecture.png` — architecture diagram.
- `diagram/architecture.mmd` — diagram source.

## Design
- Public subnets: ALB only.
- Private application subnets: EC2 Auto Scaling Group across two AZs.
- Private database subnets: RDS across two AZs.
- No public IPs on application/database resources.
- No SSH access; SSM Session Manager is used instead.
- IMDSv2 is required.
- NAT Gateway per AZ avoids a single-AZ NAT dependency.

## Validate and deploy

```bash
aws cloudformation validate-template \
  --template-body file://task1/cloudformation.yaml

aws cloudformation deploy \
  --template-file task1/cloudformation.yaml \
  --stack-name nimbustech-network \
  --capabilities CAPABILITY_IAM
```

**Cost warning:** NAT Gateways and Multi-AZ RDS can create charges and are not free-tier resources. For this hiring exercise, review the template rather than deploying it blindly in a personal account.

**PostgreSQL version:** the scenario mentions PostgreSQL 18. The template uses PostgreSQL 17 as a conservative example. Before deployment, verify the supported engine version in the selected AWS region and update `EngineVersion` accordingly.
