# Task 4 — Cost Analysis & Optimisation

## Top cost drivers
1. NAT Gateway — $104/month
2. RDS Multi-AZ — $98.40/month
3. Data Transfer Out — $92.40/month

CloudWatch Logs ingestion ($62.50) is the next significant driver.

## Recommendations

| Recommendation | Estimated monthly saving | Notes |
|---|---:|---|
| Reduce unnecessary NAT data processing using VPC endpoints and architecture changes | $40–$80 | Validate traffic before changing routing |
| Review RDS Multi-AZ requirement for non-production | $49–$55 | Keep Multi-AZ for production HA |
| Reduce 3 TB internet data transfer | $20–$45 | CDN/cache/compression and regional architecture |
| Reduce CloudWatch log ingestion | $20–$40 | Sampling, retention policies, debug-log removal |
| Right-size EC2 / use Savings Plans after stable usage | $5–$10 | Validate CPU/memory first |
| Lifecycle S3 objects to cheaper storage tiers | $3–$8 | Use lifecycle rules based on access patterns |
| Review ALB LCUs and idle resources | $1–$3 | Remove unnecessary listeners/rules |

Savings are estimates, not guaranteed; actual savings depend on workload and AWS pricing.

## Billing alarm

`cloudformation/billing-alarm.yaml` creates an SNS notification and a CloudWatch billing alarm at **$350 USD**.

```bash
aws cloudformation deploy \
  --template-file cloudformation/billing-alarm.yaml \
  --stack-name nimbustech-billing-alarm \
  --parameter-overrides AlertEmail=YOUR_EMAIL@example.com
```

Confirm the SNS email subscription after deployment. Billing metrics are account-level and should be created in the AWS billing-supported region.

## Tagging strategy

Use consistent keys across every client:

- `Client` — client identifier
- `Environment` — dev/staging/prod
- `Application` — application name
- `Owner` — responsible team
- `CostCenter` — billing/cost center
- `Project` — project identifier
- `ManagedBy` — CloudFormation/manual/automation
- `DataClassification` — public/internal/confidential/restricted
