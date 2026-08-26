# Task 1 — Infrastructure Architecture & IaC

## Overview

This solution uses **AWS CloudFormation only** for the NimbusTech infrastructure.

The architecture separates the application into public, private application, and private database tiers.

## Architecture

```text
                         Internet
                            |
                            v
                   Internet Gateway
                            |
             +--------------+--------------+
             |                             |
       Public Subnet 1               Public Subnet 2
             |                             |
             +--------------+--------------+
                            |
                    Public ALB
                     80 / 443
                            |
                     TCP 3000
                            |
             +--------------+--------------+
             |                             |
       Private App 1                 Private App 2
             |                             |
             +--------------+--------------+
                            |
                     TCP 5432
                            |
             +--------------+--------------+
             |                             |
       Private DB 1                  Private DB 2
             |                             |
             +--------------+--------------+
                            |
                     RDS PostgreSQL

Private application subnets -> NAT Gateway -> Internet Gateway
RDS has no internet route.
```

## Files

```text
task1-infrastructure/
├── cloudformation/
│   └── nimbustech-infrastructure.yaml
├── architecture-diagram.txt
├── security-group-rules.md
└── README.md
```

## CloudFormation Resources

The template creates:

- VPC
- 2 public subnets across 2 AZs
- 2 private application subnets across 2 AZs
- 2 private database subnets across 2 AZs
- Internet Gateway
- NAT Gateway
- Public and private route tables
- Public Application Load Balancer
- EC2 Launch Template
- EC2 Auto Scaling Group
- RDS PostgreSQL
- RDS subnet group
- ALB security group
- Application security group
- Database security group
- EC2 IAM role for Systems Manager
- IMDSv2 requirement

## Security Group Design

### ALB Security Group

```text
Internet -> ALB
TCP 80
TCP 443
```

The ALB is the public entry point.

### Application Security Group

```text
ALB Security Group -> EC2
TCP 3000
```

There is no public inbound rule for EC2.

SSH port 22 is not opened. Systems Manager can be used for administration.

### Database Security Group

```text
Application Security Group -> RDS
TCP 5432
```

RDS is configured with:

```yaml
PubliclyAccessible: false
```

## Least Privilege Flow

```text
Internet
   |
   v
ALB : 80/443
   |
   v
EC2 : 3000
   |
   v
RDS : 5432
```

There is no direct Internet access to EC2 or RDS.

## Deployment

Validate:

```bash
aws cloudformation validate-template   --template-body file://cloudformation/nimbustech-infrastructure.yaml
```

Deploy:

```bash
aws cloudformation deploy   --template-file cloudformation/nimbustech-infrastructure.yaml   --stack-name nimbustech-infrastructure   --parameter-overrides DBPassword='CHANGE_ME'
```

For production, the database password should be stored in AWS Secrets Manager instead of being passed on the command line.

## Cost Consideration

The requested architecture includes a NAT Gateway and Multi-AZ RDS. These can create charges in a personal AWS account.

I would review AWS pricing and free-tier eligibility before deployment. The CloudFormation template is provided as the production-oriented target architecture requested by the exercise.

## Assumptions

- Deployment region is `us-east-1`.
- Two Availability Zones are available.
- The Node.js application listens on port 3000.
- Ubuntu is used for EC2.
- EC2 administration is performed through Systems Manager instead of SSH.
- RDS PostgreSQL 18 is required by the exercise.
- The application tier uses two EC2 instances across two AZs.
