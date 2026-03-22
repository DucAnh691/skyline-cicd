variable "aws_region" {
  description = "Region triển khai"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tên dự án"
  type        = string
}

variable "db_password" {
  description = "Mật khẩu Database"
  type        = string
  sensitive   = true
}