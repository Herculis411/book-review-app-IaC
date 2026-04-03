output "web_instance_ids"  { value = aws_instance.web[*].id }
output "app_instance_ids"  { value = aws_instance.app[*].id }
output "web_instance_ips"  { value = aws_instance.web[*].private_ip }
output "app_instance_ips"  { value = aws_instance.app[*].private_ip }
output "ssm_role_arn"      { value = aws_iam_role.ec2_ssm.arn }
