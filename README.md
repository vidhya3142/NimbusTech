# NimbusTech AWS Cloud Engineer Practical Exercise

This repository is a reference implementation for the NimbusTech hiring exercise. The implementation follows the supplied brief and intentionally focuses on infrastructure, security, automation, cost reasoning, and documentation rather than deploying a complete application.

## Deliverables

- `task1/` — secure 2-AZ VPC, ALB, private application tier, private RDS, security groups, diagram.
- `task2/` — idempotent PostgreSQL v1→v2 migration, rollback, validation, and runtime notes.
- `task3/` — security findings, remediation plan, Terraform/CLI fixes, and SSM patching script.
- `task4/` — cost analysis, savings recommendations, billing alarm, and tagging strategy.
- `task5/` — Boto3 automation that finds unnamed EC2 instances older than 7 days, sends SNS, and stops them; includes AI prompt log and review notes.

## Assumptions

1. The exercise's supplied spend numbers are used as the baseline; savings are estimates, not AWS Cost Explorer quotes.
2. The production design uses two NAT Gateways for AZ resilience. For a non-production environment, a single NAT Gateway or VPC endpoints can reduce cost.
3. The application listens on TCP/3000. Change `app_port` if NimbusTech's Node.js API uses another port.
4. ALB TLS/HTTPS is represented as an optional listener variable because a certificate ARN is environment-specific.
5. The RDS engine version is parameterized as requested by the scenario (`18` by default). Before applying, confirm that the selected AWS region/provider currently offers that engine version.
6. No application AMI or deployment artifact was supplied, so the launch template is intentionally stubbed with an Amazon Linux 2023 AMI lookup and a placeholder bootstrap message. In a real deployment, use a hardened application AMI or a CI/CD deployment mechanism.
7. Secrets are not stored in Terraform state as plain text in this exercise. RDS password input is marked sensitive; for production I would use AWS Secrets Manager and rotation.
8. Task 5 stops only instances that meet both conditions: no `Name` tag and runtime greater than seven days. It uses `DryRun` by default.

## Safety

The Terraform is designed to be reviewable and runnable, but `terraform apply` creates billable resources. Review the plan and AWS Free Tier eligibility before applying. The exercise itself asks for a personal AWS account, but several resources in the scenario (NAT Gateway, RDS Multi-AZ, data transfer, CloudWatch ingestion) can generate charges.

## AI usage

AI assistance is explicitly encouraged by the exercise. Task 5 contains the prompt log, an AI-generated baseline, and a human review/change summary. The final code is the candidate submission, not an assertion that generated code is automatically production-ready.

## Suggested validation sequence

```bash
cd task1/terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

For Task 2, use a non-production PostgreSQL clone first. For Task 3, run remediation commands only after confirming resource names/IDs and change-control approval. For Task 5, run with `--dry-run` first.
