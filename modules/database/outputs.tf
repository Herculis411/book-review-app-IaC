output "db_endpoint"              { value = aws_db_instance.primary.endpoint }
output "db_hostname"              { value = aws_db_instance.primary.address }
output "db_port"                  { value = aws_db_instance.primary.port }
output "db_read_replica_endpoint" { value = aws_db_instance.replica.endpoint }
output "db_read_replica_hostname" { value = aws_db_instance.replica.address }
