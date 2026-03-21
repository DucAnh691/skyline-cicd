variable "project_name" {
  description = "Tên dự án, dùng làm tiền tố cho các tài nguyên"
  type        = string
}

variable "vpc_id" {
  description = "ID của VPC nơi Jenkins được triển khai"
  type        = string
}

variable "public_subnet_ids" {
  description = "Danh sách Public Subnet ID để đặt Jenkins Master/Agent"
  type        = list(string)
}

variable "ssh_key_name" {
  description = "Tên Key Pair có sẵn trên AWS để SSH vào instance"
  type        = string
}

variable "allowed_ip_for_ssh" {
  description = "Địa chỉ IP hoặc CIDR được phép SSH vào Jenkins Master (Ví dụ: IP nhà mạng của bạn)"
  type        = string
  default     = "0.0.0.0/0" # Nên thay đổi khi production
  validation {
    condition     = can(cidrhost(var.allowed_ip_for_ssh, 0))
    error_message = "Biến allowed_ip_for_ssh phải là định dạng CIDR hợp lệ (VD: 1.2.3.4/32)."
  }
}