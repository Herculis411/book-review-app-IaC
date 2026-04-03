variable "project_name"          { type = string }
variable "environment"           { type = string }
variable "web_subnet_ids"        { type = list(string) }
variable "app_subnet_ids"        { type = list(string) }
variable "web_sg_id"             { type = string }
variable "app_sg_id"             { type = string }
variable "web_target_group_arn"  { type = string }
variable "app_target_group_arn"  { type = string }
variable "key_name"              { type = string }
variable "web_instance_type"     { type = string }
variable "app_instance_type"     { type = string }
variable "db_host"               { type = string }
variable "db_name"               { type = string }
variable "db_username"           { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "public_alb_dns"        { type = string }
variable "internal_alb_dns"      { type = string }
variable "jwt_secret" {
  type      = string
  sensitive = true
}
variable "allowed_origins"       { type = string }
