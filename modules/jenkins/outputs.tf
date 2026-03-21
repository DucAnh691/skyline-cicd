output "jenkins_url" {
  description = "Đường dẫn truy cập Jenkins UI"
  value       = "http://${aws_eip.jenkins_master_eip.public_ip}:8080"
}

output "jenkins_master_public_ip" {
  description = "Public IP của Jenkins Master"
  value       = aws_eip.jenkins_master_eip.public_ip
}