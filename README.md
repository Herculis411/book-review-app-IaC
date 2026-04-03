<img width="3484" height="3324" alt="image" src="https://github.com/user-attachments/assets/b8ee5002-82f0-4b25-97a9-67ccb4b1637e" />


# Book Review App — Infrastructure as Code

Modular Terraform deployment of the Book Review App
(Next.js + Node.js + MySQL) on AWS — three-tier production architecture.

---

## What This Deploys

| Component | Technology | Details |
|---|---|---|
| Frontend | Next.js 18 via Nginx | Web tier, public subnets, 2 AZs |
| Backend | Node.js 18 + Express | App tier, private subnets, 2 AZs |
| Database | RDS MySQL 8.0 | Multi-AZ + read replica, private subnets |
| Load Balancers | 2x AWS ALB | Public (frontend) + Internal (backend) |
| Networking | Custom VPC | 6 subnets across 2 AZs |

---

## Project Structure

```
book-review-app-IaC/
├── main.tf               Root module — orchestrates all modules
├── variables.tf          Root variable definitions
├── outputs.tf            Root outputs (URLs, IDs, endpoints)
├── terraform.tfvars      Your values — EXCLUDED from git
├── .gitignore            Excludes secrets and state files
├── CLAUDE.md             Claude Code deployment guide
├── README.md             This file
│
├── scripts/
│   ├── deploy-backend.sh    Node.js bootstrap (user_data)
│   └── deploy-frontend.sh   Next.js bootstrap (user_data)
│
└── modules/
    ├── networking/       VPC, subnets, IGW, NAT, route tables
    ├── security/         Security groups for all tiers
    ├── alb/              Public ALB + Internal ALB
    ├── ec2/              Web and app tier EC2 instances
    └── database/         RDS MySQL primary + read replica
```

---

## Quick Start

```bash
# 1. Clone this repo
git clone <this-repo>
cd book-review-app-IaC

# 2. Fill in your values
cp terraform.tfvars terraform.tfvars.example   # keep example
# edit terraform.tfvars — replace all CHANGE_ME values

# 3. Deploy
terraform init
terraform plan
terraform apply

# 4. Get the app URL
terraform output app_url
```

Full deployment guide: see **CLAUDE.md**

---

## Security

- App and database tiers have **no public IP addresses**
- SSH access via **AWS Systems Manager (SSM)** — no open port 22
- All credentials via `terraform.tfvars` (excluded from git)
- RDS storage encrypted at rest
- Security groups follow **least-privilege** rules per tier

---

## Repository

Book Review App source: https://github.com/pravinmishraaws/book-review-app
