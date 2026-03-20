output "db_instance_endpoint" {
  description = "Địa chỉ để ứng dụng kết nối tới Database"
  value       = aws_db_instance.mysql.endpoint
}

output "db_instance_id" {
  value = aws_db_instance.mysql.id
}