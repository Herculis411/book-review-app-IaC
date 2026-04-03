########################################################################
# Database Module — RDS MySQL with Multi-AZ and Read Replica
########################################################################

# ── RDS Subnet Group ───────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-db-subnet-group" }
}

# ── RDS Parameter Group ────────────────────────────────────────────────────
resource "aws_db_parameter_group" "main" {
  family = "mysql8.0"
  name   = "${var.project_name}-${var.environment}-mysql-params"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = { Name = "${var.project_name}-${var.environment}-mysql-params" }
}

# ── RDS Primary Instance (Multi-AZ) ───────────────────────────────────────
resource "aws_db_instance" "primary" {
  identifier             = "${var.project_name}-${var.environment}-mysql-primary"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"
  deletion_protection    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  tags = { Name = "${var.project_name}-${var.environment}-mysql-primary" }
}

# ── RDS Read Replica ───────────────────────────────────────────────────────
resource "aws_db_instance" "replica" {
  identifier             = "${var.project_name}-${var.environment}-mysql-replica"
  replicate_source_db    = aws_db_instance.primary.identifier
  instance_class         = var.db_instance_class
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false

  vpc_security_group_ids = [var.db_sg_id]

  tags = { Name = "${var.project_name}-${var.environment}-mysql-replica" }
}
