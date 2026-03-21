variable "project_name" {
  description = "Tên dự án"
  type        = string
}

variable "service_names" {
  description = "Danh sách tên các Microservices cần tạo Repo"
  type        = list(string)
  default     = ["user-service", "order-service", "payment-service"]
}
