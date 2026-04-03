########################################################################
# Networking Module — VPC, Subnets, Gateways, Route Tables
# Three-tier architecture: Web (public), App (private), DB (private)
########################################################################

# ── VPC ────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# ── Internet Gateway ───────────────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# ── Web Tier Subnets (Public — 2 AZs) ─────────────────────────────────────
resource "aws_subnet" "web" {
  count                   = length(var.web_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.web_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-web-subnet-${count.index + 1}"
    Tier = "web"
  }
}

# ── App Tier Subnets (Private — 2 AZs) ────────────────────────────────────
resource "aws_subnet" "app" {
  count             = length(var.app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-app-subnet-${count.index + 1}"
    Tier = "app"
  }
}

# ── Database Tier Subnets (Private — 2 AZs) ───────────────────────────────
resource "aws_subnet" "db" {
  count             = length(var.db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-${count.index + 1}"
    Tier = "database"
  }
}

# ── Elastic IPs for NAT Gateways ───────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.web_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ── NAT Gateways (one per AZ for HA) ──────────────────────────────────────
resource "aws_nat_gateway" "nat" {
  count         = length(var.web_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.web[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ── Public Route Table (Web Tier) ──────────────────────────────────────────
resource "aws_route_table" "web" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-rt"
  }
}

resource "aws_route_table_association" "web" {
  count          = length(aws_subnet.web)
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.web.id
}

# ── Private Route Tables (App Tier — one per AZ for HA) ───────────────────
resource "aws_route_table" "app" {
  count  = length(var.app_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# ── Private Route Tables (DB Tier) ────────────────────────────────────────
resource "aws_route_table" "db" {
  count  = length(var.db_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.db)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db[count.index].id
}
