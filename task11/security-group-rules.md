# Security Group Rules

## ALB Security Group

| Port | Source | Purpose |
|---|---|---|
| 80 | 0.0.0.0/0 | Public HTTP traffic |
| 443 | 0.0.0.0/0 | Public HTTPS traffic |

## Application Security Group

| Port | Source | Purpose |
|---|---|---|
| 3000 | ALB Security Group | Node.js API traffic |

No SSH rule is configured.

## Database Security Group

| Port | Source | Purpose |
|---|---|---|
| 5432 | Application Security Group | PostgreSQL traffic |

The database is private and does not accept traffic directly from the internet.
