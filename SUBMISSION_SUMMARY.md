# NimbusTech 

This repository implements the five requested tasks for the NimbusTech practical exercise.

## IaC choice

CloudFormation YAML so the infrastructure can be reviewed and deployed using native AWS tooling.

## Task 1

`task1/nimbustech-infra.yaml` implements the segmented two-tier architecture with public ALB, private application tier, private database tier, two AZs, NAT gateways, dedicated security groups, SSM access and IMDSv2.

## Task 2

The PostgreSQL migration and rollback SQL are idempotent and include validation checks.

## Task 3

Security findings are mapped to remediation actions. `task3/cloudtrail/cloudtrail.yaml` enables a multi-region CloudTrail trail, and `patch_fleet.py` uses SSM Run Command for fleet patching and verification.

## Task 4

Cost drivers and optimization recommendations are documented. `task4/billing-alarm.yaml` creates the $350 billing alarm and SNS notification.

## Task 5

The EC2 cleanup automation, prompt log and AI review are included.

## Deployment caution

The exercise's production-style architecture includes NAT gateways and Multi-AZ RDS, which can incur charges