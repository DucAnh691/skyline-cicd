output "vpc_id" {
  description = "ID của VPC Production"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Tên EKS Cluster Production"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint để truy cập Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "region" {
  description = "AWS Region triển khai"
  value       = var.aws_region
}

# Production cũng dùng chung ECR với Dev (build once, deploy anywhere)