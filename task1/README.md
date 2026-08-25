# Task 1 — Infrastructure Architecture & IaC

## Design

The target architecture separates internet-facing and internal workloads:

- Two public subnets across two AZs contain the ALB and NAT Gateways.
- Two private application subnets contain an Auto Scaling Group of EC2 instances.
- Two isolated database subnets contain Multi-AZ RDS PostgreSQL.
- Internet Gateway provides ingress/egress for public resources.
- Each application subnet routes outbound traffic through the NAT Gateway in the same AZ.
- The DB route tables have no default route to the internet.
- EC2 uses SSM instead of SSH; IMDSv2 is required.

## Security-group rules

| SG | Direction | Source/Destination | Port | Reason |
|---|---|---|---:|---|
| ALB | Ingress | `0.0.0.0/0` | 80 | Public HTTP entry point. |
| ALB | Ingress | `0.0.0.0/0` | 443 | Public HTTPS entry point. |
| ALB | Egress | App SG | 3000 | Forward API traffic only to app tier. |
| App | Ingress | ALB SG | 3000 | Prevent direct internet access to EC2. |
| App | Egress | Internet via NAT | All | Updates/external API access; tighten with VPC endpoints and egress proxy where practical. |
| RDS | Ingress | App SG | 5432 | Only application tier can reach PostgreSQL. |
| RDS | Egress | Default | All | Return traffic; can be further constrained if the workload permits. |

There is deliberately no SSH ingress rule.

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# Set db_password through a secure mechanism for your lab.
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Before applying, verify that PostgreSQL 18 is available in the selected region/provider version. The exercise asks for PostgreSQL 18, so the version is a variable rather than silently changing the requirement.

## Production improvements with more time

- Store DB credentials in Secrets Manager with rotation.
- Add VPC endpoints for SSM, CloudWatch, S3 and other AWS APIs to reduce NAT dependence.
- Add AWS WAF to the ALB.
- Add Route 53 + ACM for a real hostname/HTTPS.
- Add CloudWatch alarms, centralized logs, and application tracing.
- Use a hardened application AMI and CI/CD instead of a placeholder user-data script.
- Consider RDS Proxy for connection management if the application has bursty connection behavior.
