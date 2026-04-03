########################################################################
# Book Review App — Root Outputs
########################################################################

# ── Application Access ─────────────────────────────────────────────────────
output "app_url" {
  description = "Public URL to access the Book Review frontend application"
  value       = "http://${module.alb.public_alb_dns}"
}

output "public_alb_dns" {
  description = "DNS name of the public-facing Application Load Balancer"
  value       = module.alb.public_alb_dns
}

output "internal_alb_dns" {
  description = "DNS name of the internal Application Load Balancer (backend)"
  value       = module.alb.internal_alb_dns
}

# ── Networking ─────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "web_subnet_ids" {
  description = "IDs of the web tier (public) subnets"
  value       = module.networking.web_subnet_ids
}

output "app_subnet_ids" {
  description = "IDs of the app tier (private) subnets"
  value       = module.networking.app_subnet_ids
}

output "db_subnet_ids" {
  description = "IDs of the database tier (private) subnets"
  value       = module.networking.db_subnet_ids
}

# ── EC2 ────────────────────────────────────────────────────────────────────
output "web_instance_ids" {
  description = "Instance IDs of the web tier EC2 instances"
  value       = module.ec2.web_instance_ids
}

output "app_instance_ids" {
  description = "Instance IDs of the app tier EC2 instances"
  value       = module.ec2.app_instance_ids
}

# ── Database ───────────────────────────────────────────────────────────────
output "db_endpoint" {
  description = "RDS primary endpoint (host:port)"
  value       = module.database.db_endpoint
}

output "db_hostname" {
  description = "RDS primary hostname only"
  value       = module.database.db_hostname
}

output "db_read_replica_endpoint" {
  description = "RDS read replica endpoint"
  value       = module.database.db_read_replica_endpoint
}

# ── Connection Helpers ─────────────────────────────────────────────────────
output "ssh_web_1" {
  description = "SSH command for web instance 1 (requires bastion or SSM)"
  value       = "aws ssm start-session --target ${module.ec2.web_instance_ids[0]}"
}

output "ssh_app_1" {
  description = "SSH command for app instance 1 (requires bastion or SSM)"
  value       = "aws ssm start-session --target ${module.ec2.app_instance_ids[0]}"
}

output "bootstrap_log_web" {
  description = "Command to view web instance bootstrap log via SSM"
  value       = "aws ssm start-session --target ${module.ec2.web_instance_ids[0]} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/book-review-setup.log'"
}

output "bootstrap_log_app" {
  description = "Command to view app instance bootstrap log via SSM"
  value       = "aws ssm start-session --target ${module.ec2.app_instance_ids[0]} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/book-review-setup.log'"
}
