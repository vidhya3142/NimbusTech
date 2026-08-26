# Security Group Rules

| Security Group | Direction | Port | Source | Reason |
|---|---|---:|---|---|
| ALB SG | Inbound | 80 | 0.0.0.0/0 | Public web entry point |
| ALB SG | Outbound | All | 0.0.0.0/0 | Reach application targets |
| App SG | Inbound | 3000 | ALB SG | Only the ALB reaches the API |
| App SG | Outbound | All | 0.0.0.0/0 | Outbound access through NAT for updates/dependencies |
| DB SG | Inbound | 5432 | App SG | Only the application tier reaches PostgreSQL |
| DB SG | Outbound | All | 0.0.0.0/0 | Stateful egress; can be tightened after dependency mapping |

There is no inbound SSH rule. EC2 administration uses AWS Systems Manager Session Manager.
