########################################################################
# Book Review App — Root Variables
########################################################################

# ── General ────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for naming and tagging all resources"
  type        = string
  default     = "book-review"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

# ── Networking ─────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Web tier — public subnets
variable "web_subnet_cidrs" {
  description = "CIDR blocks for web tier (public) subnets — one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# App tier — private subnets
variable "app_subnet_cidrs" {
  description = "CIDR blocks for app tier (private) subnets — one per AZ"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# DB tier — private subnets
variable "db_subnet_cidrs" {
  description = "CIDR blocks for database tier (private) subnets — one per AZ"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

# ── EC2 ────────────────────────────────────────────────────────────────────
variable "key_name" {
  description = "Name of the existing AWS key pair for SSH access"
  type        = string
}

variable "web_instance_type" {
  description = "EC2 instance type for web tier (Next.js)"
  type        = string
  default     = "t3.small"
}

variable "app_instance_type" {
  description = "EC2 instance type for app tier (Node.js)"
  type        = string
  default     = "t3.small"
}

# ── Database ───────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "book_review_db"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

# ── Application ────────────────────────────────────────────────────────────
variable "jwt_secret" {
  description = "JWT secret key for the backend API"
  type        = string
  sensitive   = true
}
