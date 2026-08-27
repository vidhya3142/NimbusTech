# NimbusTech - Task 1: Infrastructure Architecture & IaC

CloudFormation (YAML) for a re-architected version of NimbusTech's stack:
ALB in public subnets, app tier (EC2 in an Auto Scaling Group) in private
subnets, RDS Postgres in its own private subnets that have no route to the
internet at all. No public IPs anywhere except the ALB.

Files:
- `nimbustech-infra.yaml` - the whole stack, one template
- `diagram/architecture.txt` - ASCII diagram of the design
- `nimbus_tech_architecture_diagram.png` - draw.io diagram of the design
- `README.md` - this file

## Design decisions and why

Public (ALB), private-app (EC2), andprivate-db (RDS) are separate subnets 
with separate route tables. The DB subnets' route table has no route to 
an Internet Gateway or NAT Gateway atall - so even if a security group 
rule were ever misconfigured, there's still no network path from the 
internet to the database. That's a stronger guarantee than "the security 
group blocks it."

**No SSH, no bastion host.** The app instances get an IAM instance profile
with `AmazonSSMManagedInstanceCore` and are managed through SSM Session
Manager. This means port 22 doesn't need to be open anywhere in the VPC,
inbound or via a bastion. It also removes the cost and maintenance of
running a bastion host just to get a shell.

**ALB -> App -> DB security groups, one direction only.** Each security
group only allows the tier directly in front of it: ALB accepts 80 from the
internet; the app tier only accepts `AppPort` from the ALB's security group
(referenced by SG ID, not CIDR range, so it doesn't matter what subnet the
ALB nodes actually land in); the DB only accepts 5432 from the app tier's
security group. Every rule has an inline `Description` saying why it exists,
per the exercise ask. One implementation note: I had to split each
cross-group rule into a separate `AWS::EC2::SecurityGroupEgress` resource
rather than defining egress inline on all three groups, because three groups
that reference each other in both directions creates a circular dependency
that CloudFormation won't deploy. `cfn-lint` caught this before I tried to
actually deploy it, which saved a failed stack creation.

**Auto Scaling Group instead of a single EC2 instance**, even though the
brief allows either. Min 1 / Max 2 / Desired 1 - so day-to-day this behaves
like a single instance (no cost increase), but it can absorb an instance or
AZ failure automatically, and it's the natural place to add a scaling policy
later without re-architecting.

**Single NAT Gateway by default** This is the one place I
deliberately traded a bit of resilience for cost, called out as a parameter
(`NumberOfNatGateways`) rather than hidden in the template. A second NAT
Gateway is about $32-35/month plus data processing charges. With one NAT,
if that AZ has an outage the app tier temporarily loses *outbound* internet
(patches, external API calls) but the app itself stays up, since the ALB and
ASG both still span two AZs. Given the CTO is actively trying to cut a $420
bill, I think this is the right default - it's a one-parameter change to
`'2'` once traffic/revenue justifies it.

**RDS: private, encrypted, not Multi-AZ by default.** `PubliclyAccessible:
false` (this alone is arguably the biggest fix vs. the current setup - the
brief says RDS is currently public). Storage is encrypted, backups retain 7
days, and `DeletionProtection: true` so a stack deletion or `terraform
destroy`-equivalent typo can't take the database with it. Multi-AZ is a
parameter, off by default - same cost-conscious logic as the NAT Gateway,
and it's the CTO's call once they decide what downtime is acceptable during
a failover.

**AMI resolved automatically.** `AppAmiId` defaults to the SSM public
parameter for the latest Ubuntu 22.04 AMI, so nobody has to go hunt down an
AMI ID for us-east-1 and it won't silently go stale.

**DB password as a `NoEcho` parameter, passed in at deploy time** (not
committed anywhere). `cfn-lint` flags this with a warning suggesting a
Secrets Manager dynamic reference instead - that's the more production-grade
option (auto-rotation, no plaintext ever touching a CLI history), and I'd
add it as a follow-up rather than in this first pass, since it pulls in an
extra resource (`AWS::SecretsManager::Secret`) that didn't feel necessary to
prove the architecture out for this exercise.

## Security group rules, summarized

| Security Group | Direction | Rule | Why |
|---|---|---|---|
| ALB SG | Inbound | TCP 80 from `0.0.0.0/0` | Public entry point. Add 443 once there's a domain/cert. |
| ALB SG | Outbound | TCP `AppPort` to App SG | ALB only ever needs to forward to the app tier. |
| App SG | Inbound | TCP `AppPort` from ALB SG | Only the ALB can reach the app instances - no direct/public access. |
| App SG | Outbound | TCP 5432 to DB SG | App needs to reach Postgres, and only Postgres, on the DB tier. |
| App SG | Outbound | TCP 443 to `0.0.0.0/0` | OS/package updates and external API calls, routed via NAT. |
| DB SG | Inbound | TCP 5432 from App SG | Only the app tier can reach the database. Not even the ALB can. |

## Cost, relative to the current $420/month setup

Roughly, at low/idle traffic in us-east-1:
- ALB: ~$16-20/month base + LCU usage
- 1x NAT Gateway: ~$32/month + data processing
- EC2 t3.medium (ASG, desired=1): about the same as the current single
  instance
- RDS db.t3.medium, single-AZ, gp3: similar to current RDS cost, but not
  materially higher just from moving it into a private subnet

So this design isn't primarily a cost-cutting move - it's fixing the
security posture (public DB, flat network, no least-privilege SGs) for
roughly the same spend, with the NAT Gateway count and RDS Multi-AZ flag
exposed as the two easy levers if the CTO wants to trade cost against
resilience later. Actual cost cutting (reserved instances / Savings Plans,
right-sizing after looking at real CloudWatch utilization, gp3 vs gp2, S3
lifecycle rules if applicable) is really a Task 2/3-shaped question - happy
to fold that analysis in if useful.

## How to deploy

```bash
aws cloudformation deploy \
  --template-file cloudformation/nimbustech-infra.yaml \
  --stack-name nimbustech-infra \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides DBPassword='<put-a-real-password-here>'
```