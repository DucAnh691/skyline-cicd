output "repository_urls" {
  description = "Danh sách URL của các ECR Repositories"
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}
