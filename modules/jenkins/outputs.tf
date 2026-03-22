output "jenkins_url" {
  description = "Đường dẫn truy cập Jenkins UI"
  value       = "http://${aws_eip.jenkins_master_eip.public_ip}:8080"
}

output "jenkins_master_public_ip" {
  description = "Public IP của Jenkins Master"
  value       = aws_eip.jenkins_master_eip.public_ip
}

output "jenkins_agent_security_group_id" {
  description = "The ID of the security group for Jenkins agents"
  value       = aws_security_group.jenkins_agent_sg.id
}

output "jenkins_role_arn" {
  description = "ARN của IAM Role gán cho Jenkins Agent"
  value       = aws_iam_role.jenkins_role.arn
}