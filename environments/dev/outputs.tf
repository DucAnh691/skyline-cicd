output "dev_vpc_id" {
  value = module.vpc.vpc_id
}

output "dev_public_subnets" {
  value = module.vpc.public_subnet_ids
}

output "ecr_repository_urls" {
  description = "URL của các ECR Repositories (Dùng để push docker image)"
  value       = module.ecr.repository_urls
}

output "aws_region" {
  description = "Region hiện tại (Dùng cho lệnh docker login)"
  value       = "ap-southeast-1"
}
