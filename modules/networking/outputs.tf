output "vpc_id"          { value = aws_vpc.main.id }
output "web_subnet_ids"  { value = aws_subnet.web[*].id }
output "app_subnet_ids"  { value = aws_subnet.app[*].id }
output "db_subnet_ids"   { value = aws_subnet.db[*].id }
output "igw_id"          { value = aws_internet_gateway.igw.id }
output "nat_gateway_ids" { value = aws_nat_gateway.nat[*].id }
