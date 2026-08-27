# Task 4 — Cost Analysis & Optimisation

## Overview

NimbusTech's current monthly AWS spend is approximately **$420/month**.

The objective is to identify the main cost drivers, recommend practical optimisations, and configure a CloudWatch billing alarm at **$350**.

---

## Current Monthly Spend

| Service | Monthly Cost |
|---|---:|
| EC2 – t3.medium | $30.37 |
| RDS – db.t3.medium Multi-AZ | $98.40 |
| NAT Gateway | $104.00 |
| Data Transfer Out | $92.40 |
| CloudWatch Logs | $62.50 |
| S3 | $23.00 |
| ALB | $9.33 |
| **Total** | **~$420** |

---

## Top 3 Cost Drivers

### 1. NAT Gateway — $104/month

The NAT Gateway is expensive because approximately 2 TB of data is processed through it.

**Recommendation:**
- Use VPC endpoints for AWS services such as S3 where appropriate.
- Reduce unnecessary traffic through the NAT Gateway.
- Keep private application traffic inside the VPC where possible.

**Estimated saving:** ~$30–$50/month

---

### 2. RDS — $98.40/month

The database is using a Multi-AZ `db.t3.medium` configuration.

**Recommendation:**
- Review whether Multi-AZ is required for the non-production environment.
- Right-size the DB instance based on CPU, memory and connection usage.
- Consider Reserved Instances for predictable production workloads.

**Estimated saving:** ~$20–$40/month

---

### 3. Data Transfer — $92.40/month

Approximately 3 TB of outbound data transfer is generating a significant cost.

**Recommendation:**
- Identify the largest sources of outbound traffic using Cost Explorer.
- Use CloudFront for suitable public content.
- Reduce unnecessary cross-AZ and internet data transfer.
- Compress responses and objects where possible.

**Estimated saving:** ~$20–$40/month

---

## Additional Optimisation Recommendations

### 4. CloudWatch Logs — $62.50/month

500 GB of log ingestion is high.

Recommendations:

- Reduce unnecessary application logging.
- Adjust log levels.
- Set appropriate log retention periods.
- Export long-term logs to S3 when appropriate.

**Estimated saving:** ~$20–$30/month

---

### 5. EC2 — $30.37/month

Review EC2 utilisation and right-size the instance if it is underutilised.

For predictable workloads, consider Reserved Instances or Savings Plans.

**Estimated saving:** ~$5–$10/month

---

### 6. S3 — $23/month

Review old and infrequently accessed objects.

Recommendations:

- Add S3 Lifecycle policies.
- Move older objects to appropriate storage classes.
- Review unnecessary GET requests.

**Estimated saving:** ~$5–$10/month

---

## Estimated Savings Summary

| Optimisation | Estimated Monthly Saving |
|---|---:|
| NAT Gateway optimisation | $30–$50 |
| RDS optimisation | $20–$40 |
| Data transfer optimisation | $20–$40 |
| CloudWatch Logs optimisation | $20–$30 |
| EC2 right-sizing | $5–$10 |
| S3 optimisation | $5–$10 |
| **Potential Total** | **~$100–$180/month** |

Actual savings would be confirmed using AWS Cost Explorer and CloudWatch utilisation metrics before making production changes.

---

# CloudWatch Billing Alarm

The file:

```text
billingalarm.yaml