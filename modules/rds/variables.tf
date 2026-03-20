variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
  description = "Danh sách ID subnet lấy từ module VPC"
}

variable "db_name" {
  type    = string
  default = "skyline_db"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true # Ẩn mật khẩu khi Terraform in ra màn hình
  default = "DucAnh691!"
}