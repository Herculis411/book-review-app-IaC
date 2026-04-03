# CLAUDE.md — Book Review App IaC

## Project Overview

This repository deploys the **Book Review App** (Next.js + Node.js + MySQL)
on **AWS** using a fully modular Terraform architecture.
It is designed for use with **Claude Code** as an AI-assisted DevOps project.

---

## Architecture Summary

```
Internet
   │
   ▼
[Public ALB]          ← port 80, internet-facing
   │
   ▼
[Web Tier EC2 x2]     ← Next.js via Nginx, public subnets, 2 AZs
   │
   ▼ port 3001
[Internal ALB]        ← internal, web tier only
   │
   ▼
[App Tier EC2 x2]     ← Node.js API, private subnets, 2 AZs
   │
   ▼ port 3306
[RDS MySQL]           ← primary + read replica, private subnets
```

### Subnet Layout (VPC: 10.0.0.0/16)

| Tier | Subnet | AZ | Type |
|---|---|---|---|
| Web | 10.0.1.0/24 | us-east-1a | Public |
| Web | 10.0.2.0/24 | us-east-1b | Public |
| App | 10.0.3.0/24 | us-east-1a | Private |
| App | 10.0.4.0/24 | us-east-1b | Private |
| DB  | 10.0.5.0/24 | us-east-1a | Private |
| DB  | 10.0.6.0/24 | us-east-1b | Private |

---

## Module Structure

```
modules/
├── networking/   VPC, 6 subnets, IGW, 2x NAT Gateway, route tables
├── security/     5 security groups (public-alb, web, internal-alb, app, db)
├── alb/          Public ALB (port 80) + Internal ALB (port 3001)
├── ec2/          2x web EC2 + 2x app EC2 + SSM IAM role
└── database/     RDS MySQL 8.0 (Multi-AZ primary + read replica)

scripts/
├── deploy-frontend.sh   Next.js bootstrap (templatefile injected)
└── deploy-backend.sh    Node.js bootstrap (templatefile injected)
```

---

## Security Rules

| From | To | Port | Rule |
|---|---|---|---|
| Internet | Public ALB | 80, 443 | Open |
| Public ALB | Web EC2 | 80 | ALB SG only |
| Web EC2 | Internal ALB | 3001 | Web SG only |
| Internal ALB | App EC2 | 3001 | Internal ALB SG only |
| App EC2 | RDS MySQL | 3306 | App SG only |

**No EC2 instances have public IPs.** App and DB tiers have no internet access.
Web tier instances have public IPs but SSH is not open — use AWS SSM.

---

## Prerequisites — Before Running

1. AWS CLI installed and configured:
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. Terraform >= 1.5.0 installed:
   ```bash
   terraform --version
   ```

3. AWS key pair exists in your account:
   ```bash
   aws ec2 describe-key-pairs --key-names your-key-name
   ```
   If not, create one:
   ```bash
   aws ec2 create-key-pair --key-name book-review-key \
     --query 'KeyMaterial' --output text > book-review-key.pem
   chmod 400 book-review-key.pem
   ```

4. Fill in `terraform.tfvars` — replace all `CHANGE_ME` values.

---

## Deployment Commands

```bash
# Step 1 — Initialise providers and modules
terraform init

# Step 2 — Preview changes (reads your IP, check security groups)
terraform plan

# Step 3 — Deploy (RDS takes 10-15 min, full stack ~20 min)
terraform apply

# Step 4 — Get the application URL
terraform output app_url

# Step 5 — Watch frontend bootstrap
terraform output bootstrap_log_web
# Run the printed command

# Step 6 — Watch backend bootstrap
terraform output bootstrap_log_app
# Run the printed command

# Step 7 — Destroy everything when done
terraform destroy
```

---

## Deployment Timeline

| Stage | Time |
|---|---|
| Networking (VPC, subnets, IGW, NAT) | ~2 min |
| Security groups | ~1 min |
| ALBs | ~3 min |
| RDS primary (Multi-AZ) | ~12 min |
| RDS read replica | ~8 min (parallel) |
| EC2 bootstrap (frontend) | ~5 min after launch |
| EC2 bootstrap (backend) | ~5 min after launch |
| **Total** | **~20-25 min** |

---

## Verifying the Deployment

```bash
# 1. Check the app is live
curl -I http://$(terraform output -raw public_alb_dns)

# 2. Check backend API via internal ALB (from app EC2 via SSM)
curl http://$(terraform output -raw internal_alb_dns):3001/api/books

# 3. Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=book-review" \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,ID:InstanceId}" \
  --output table

# 4. Check RDS
aws rds describe-db-instances \
  --query "DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,AZ:AvailabilityZone}" \
  --output table
```

---

## Claude Code Usage — Suggested Tasks

If using this project with Claude Code, you can ask it to:

- `/scaffold-terraform` — review and suggest improvements to any module
- Review security group rules for best practices
- Debug Terraform errors from `terraform plan` output
- Suggest scaling improvements (Auto Scaling Groups, CloudFront)
- Validate CIDR block calculations

---

## Troubleshooting

### Frontend shows 502 Bad Gateway
The Next.js app on port 3000 is not ready yet. Check:
```bash
# Via SSM on web instance
pm2 status
pm2 logs book-review-frontend
```

### Backend API not responding
Check the app tier bootstrap log:
```bash
# Via SSM on app instance
pm2 status
pm2 logs book-review-backend
tail -f /var/log/book-review-setup.log
```

### Database connection refused
RDS may still be initialising. The bootstrap script retries automatically for up to 7.5 minutes.
Check RDS status:
```bash
aws rds describe-db-instances \
  --db-instance-identifier book-review-production-mysql-primary \
  --query "DBInstances[0].DBInstanceStatus"
```

### terraform apply fails on RDS replica
The read replica depends on the primary being in `available` state.
Add `depends_on = [aws_db_instance.primary]` is already configured.
If it still fails, run `terraform apply` again — eventual consistency issue.

---

## Hard Rules (NEVER DO THESE)

- **Never commit `terraform.tfvars`** — it contains passwords and secrets
- **Never commit `*.tfstate`** — it contains infrastructure details
- **Never assign public IPs to app or db tier instances**
- **Never open port 3306 to the internet**
- **Never hardcode credentials in `.tf` files** — use `terraform.tfvars` + `sensitive = true`

---

## Cost Estimate (approximate, us-east-1)

| Resource | Cost/month |
|---|---|
| 4x EC2 t3.small | ~$30 |
| RDS db.t3.micro Multi-AZ | ~$30 |
| RDS read replica | ~$15 |
| 2x NAT Gateway | ~$65 |
| 2x ALB | ~$35 |
| **Total** | **~$175/month** |

> Run `terraform destroy` when not in use to stop billing.
