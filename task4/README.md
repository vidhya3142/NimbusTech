# Task 4 — Cost Analysis & Optimisation

## Baseline

The supplied scenario totals approximately $420/month:

| Service | Monthly spend |
|---|---:|
| EC2 | $30.37 |
| RDS Multi-AZ | $98.40 |
| NAT Gateway | $104.00 |
| Data Transfer Out | $92.40 |
| CloudWatch Logs | $62.50 |
| S3 | $23.00 |
| ALB | $9.33 |
| **Total** | **~$420.00** |

## Top three drivers

1. **NAT Gateway — $104 (24.8%)**: 2 TB of processed traffic creates a large data-processing charge, in addition to the hourly NAT charge.
2. **RDS — $98.40 (23.4%)**: Multi-AZ doubles the underlying DB deployment cost relative to a comparable single-AZ setup; this is a deliberate availability feature, not simply waste.
3. **Data Transfer Out — $92.40 (22.0%)**: 3 TB of outbound traffic is significant. The right optimization depends on whether this is internet delivery, cross-AZ traffic, or traffic to another AWS/third-party service.

CloudWatch Logs is a close fourth at $62.50 (14.9%) and should also be addressed.

## Recommendations

Savings are intentionally expressed as ranges because the supplied exercise does not provide AWS Cost Explorer dimensions, traffic destinations, log groups, RDS utilization, or workload schedules.

| Action | Estimated monthly savings | Trade-off / validation |
|---|---:|---|
| Reduce NAT processing using S3 Gateway Endpoint and Interface VPC Endpoints for high-volume AWS APIs | $40–$80 | Validate which 2 TB is AWS-service traffic. Do not remove NAT if the app needs arbitrary internet egress. |
| Reduce outbound data transfer through compression, caching/CDN, and eliminating unnecessary payloads | $20–$50 | Validate the destination and current architecture first. CloudFront can be appropriate for public content/API responses that are cacheable. |
| Reassess RDS Multi-AZ for non-production; keep Multi-AZ for production if required by availability SLA | $40–$50 in non-prod | Availability trade-off. Do not downgrade production solely for cost. |
| Reduce CloudWatch log ingestion with filtering, sampling, lower verbosity, and retention policies | $20–$40 | Preserve security/audit logs; separate high-value logs from noisy application/debug logs. |
| EC2 Savings Plans / right-size after utilization review | $5–$10 | Commit only after confirming steady usage. |
| S3 lifecycle/Intelligent-Tiering for older 5 TB objects and cleanup incomplete multipart uploads | $3–$10 | Validate access pattern and retrieval costs. |
| Schedule non-production EC2/RDS off-hours | $10–$25 | Requires workload schedule and automation; not applicable to 24x7 production. |

A realistic first-pass target is roughly **$100–$170/month** (24–40%) without assuming unsafe production changes. The exact savings need Cost Explorer and usage data.

## Billing alarm — $350

Billing metrics are evaluated in `us-east-1`. The Terraform below creates an SNS topic and a CloudWatch alarm. Add a real email endpoint before applying.

```bash
cd billing-alarm
terraform init
terraform plan
terraform apply
```

The alarm is deliberately a warning threshold rather than an automatic shutdown mechanism.

## Tagging strategy

Recommended mandatory tags:

- `Client` — `NimbusTech`
- `Environment` — `prod|stage|dev`
- `Application` — `nimbus-api`
- `Owner` — team/person responsible
- `CostCenter` — billing allocation code
- `Project` — project/workstream
- `ManagedBy` — `Terraform|CloudFormation|Manual`
- `DataClassification` — `public|internal|confidential|restricted`
- `BusinessCriticality` — `low|medium|high`
- `ExpiryDate` — for temporary resources

For a consultancy, enforce the tag policy at account/OU level where possible and use AWS Cost Categories to group spend by `Client`, `Environment`, and `Application`. Avoid putting secrets or personal data into tag values.
