variable "project_name" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "private_subnet_ids" { type = list(string) }
variable "db_password" {}