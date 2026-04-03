########################################################################
# Book Review App — Root Module
# Orchestrates all child modules
#
# Request flow after deployment:
#   Browser → Public ALB → Web EC2 (Nginx)
#     Nginx /api/* → Internal ALB:3001 → App EC2 (Node.js) → RDS
#     Nginx /*     → Next.js:3000
########################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── Networking ─────────────────────────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  web_subnet_cidrs   = var.web_subnet_cidrs
  app_subnet_cidrs   = var.app_subnet_cidrs
  db_subnet_cidrs    = var.db_subnet_cidrs
  availability_zones = var.availability_zones
}

# ── Security ───────────────────────────────────────────────────────────────
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

# ── ALB ────────────────────────────────────────────────────────────────────
# Must be created before EC2 so ALB DNS names are available
# for injection into user_data scripts via templatefile()
module "alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  web_subnet_ids     = module.networking.web_subnet_ids
  app_subnet_ids     = module.networking.app_subnet_ids
  public_alb_sg_id   = module.security.public_alb_sg_id
  internal_alb_sg_id = module.security.internal_alb_sg_id
}

# ── Database ───────────────────────────────────────────────────────────────
# Must be created before EC2 so RDS endpoint is available
# for injection into deploy-backend.sh via templatefile()
module "database" {
  source = "./modules/database"

  project_name      = var.project_name
  environment       = var.environment
  db_subnet_ids     = module.networking.db_subnet_ids
  db_sg_id          = module.security.db_sg_id
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_instance_class = var.db_instance_class
  multi_az          = var.db_multi_az
}

# ── EC2 ────────────────────────────────────────────────────────────────────
# Created last — depends on ALB and RDS being fully provisioned.
# templatefile() bakes all dynamic values into user_data at apply time:
#
#   Web EC2 gets:
#     public_alb_dns   → written to NEXT_PUBLIC_API_URL in .env.local
#     internal_alb_dns → written to Nginx /api/* proxy_pass target
#
#   App EC2 gets:
#     db_host          → written to DB_HOST in .env
#     db_name          → written to DB_NAME in .env
#     db_username      → written to DB_USER in .env
#     db_password      → written to DB_PASS in .env
#     jwt_secret       → written to JWT_SECRET in .env
#     allowed_origins  → written to ALLOWED_ORIGINS in .env
module "ec2" {
  source = "./modules/ec2"

  project_name         = var.project_name
  environment          = var.environment
  web_subnet_ids       = module.networking.web_subnet_ids
  app_subnet_ids       = module.networking.app_subnet_ids
  web_sg_id            = module.security.web_sg_id
  app_sg_id            = module.security.app_sg_id
  web_target_group_arn = module.alb.web_target_group_arn
  app_target_group_arn = module.alb.app_target_group_arn
  key_name             = var.key_name
  web_instance_type    = var.web_instance_type
  app_instance_type    = var.app_instance_type

  # Database — from RDS module outputs
  db_host     = module.database.db_hostname
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # ALB DNS — both needed for frontend Nginx config
  public_alb_dns   = module.alb.public_alb_dns
  internal_alb_dns = module.alb.internal_alb_dns

  # Application secrets
  jwt_secret      = var.jwt_secret
  allowed_origins = "http://${module.alb.public_alb_dns}"

  depends_on = [
    module.database,
    module.alb,
  ]
}
