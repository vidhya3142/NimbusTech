# NimbusTech Submission Summary

## Executive summary

I re-architected NimbusTech from a flat/default-VPC deployment into a two-AZ segmented design with a public ALB, private EC2 application tier, and private Multi-AZ RDS. The security model removes direct SSH and database internet exposure and uses security-group references between tiers.

The database migration is idempotent, validates row counts/schema/indexes, and backfills completed orders. Security remediation covers all six supplied findings, including an SSM-based Ubuntu patching workflow. Cost analysis prioritizes NAT Gateway, RDS, and data transfer, with CloudWatch Logs as the next major optimization opportunity. Task 5 demonstrates AI-assisted automation with an explicit prompt log and human review.

## Key design choices

- Two AZs for application/database resilience.
- Public ALB only; EC2 and RDS have no public exposure.
- SSM Session Manager instead of SSH.
- IMDSv2 required on EC2.
- RDS encrypted, Multi-AZ, private subnet group, and dedicated SG.
- Two NAT Gateways for production AZ resilience; recommend a single NAT/VPC endpoints for cost-sensitive non-prod where appropriate.
- Terraform variables keep environment-specific values out of source code.

## Validation performed in this environment

- Python syntax compilation passed for Task 3 and Task 5.
- Architecture diagram PNG generated and included.
- Terraform files were reviewed structurally, but Terraform CLI is not installed in this environment, so `terraform validate` was not executed here.
- AWS CLI is not installed, so no AWS resources were modified from this exercise environment.
- PostgreSQL scripts were reviewed as SQL source; they should be executed against a staging clone before production.

## What I would do with more time

1. Add automated Terraform CI (`fmt`, `validate`, `tflint`, security scanning, and plan review).
2. Add test fixtures for the migration and run them against a PostgreSQL container.
3. Add AWS Config/Security Hub control mapping and evidence collection.
4. Replace RDS password Terraform input with Secrets Manager rotation.
5. Add WAF, Route 53, ACM, VPC endpoints, CloudWatch alarms, and centralized observability.
6. Run Cost Explorer analysis using real usage dimensions before committing to savings estimates.
