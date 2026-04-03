########################################################################
# EC2 Module — Web Tier (Next.js) + App Tier (Node.js)
# Web instances are public — App instances are private (no public IP)
########################################################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM Role for SSM Session Manager ──────────────────────────────
# Allows SSH-less access to both public and private EC2 instances
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-${var.environment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-ec2-ssm-role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-${var.environment}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# ── Web Tier EC2 Instances (Next.js — one per AZ) ──────────────────
# These are in PUBLIC subnets.
# user_data runs deploy-frontend.sh which:
#   1. Installs Node.js 18 and builds the Next.js app
#   2. Writes .env.local with NEXT_PUBLIC_API_URL = public ALB DNS
#   3. Configures Nginx to proxy:
#        /api/* → Internal ALB:3001 (backend)
#        /*     → Next.js:3000
resource "aws_instance" "web" {
  count                  = length(var.web_subnet_ids)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.web_instance_type
  subnet_id              = var.web_subnet_ids[count.index]
  vpc_security_group_ids = [var.web_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  # Inject both ALB DNS names — public for browser API URL,
  # internal for Nginx backend proxy target
  user_data = templatefile("${path.module}/../../scripts/deploy-frontend.sh", {
    public_alb_dns   = var.public_alb_dns
    internal_alb_dns = var.internal_alb_dns
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
    Tier = "web"
  }
}

# ── Register Web Instances with Public ALB Target Group ────────────
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = var.web_target_group_arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# ── App Tier EC2 Instances (Node.js — one per AZ) ──────────────────
# These are in PRIVATE subnets — no public IP assigned.
# Outbound traffic routes through NAT Gateway.
# user_data runs deploy-backend.sh which:
#   1. Installs Node.js 18
#   2. Writes .env with DB connection and CORS config
#   3. Waits for RDS to be ready (retries every 15s)
#   4. Starts the server with PM2 (Sequelize auto-creates tables)
resource "aws_instance" "app" {
  count                  = length(var.app_subnet_ids)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.app_instance_type
  subnet_id              = var.app_subnet_ids[count.index]
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  # Inject DB credentials and CORS origin from Terraform outputs
  user_data = templatefile("${path.module}/../../scripts/deploy-backend.sh", {
    db_host         = var.db_host
    db_name         = var.db_name
    db_user         = var.db_username
    db_password     = var.db_password
    jwt_secret      = var.jwt_secret
    allowed_origins = var.allowed_origins
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-app-${count.index + 1}"
    Tier = "app"
  }
}

# ── Register App Instances with Internal ALB Target Group ──────────
resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app)
  target_group_arn = var.app_target_group_arn
  target_id        = aws_instance.app[count.index].id
  port             = 3001
}
