output "vpc_id" {
  description = "ID của VPC Staging"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Tên EKS Cluster Staging"
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

# Staging thường dùng chung ECR/Jenkins với Dev nên không cần output ECR URL ở đây
# trừ khi bạn deploy ECR riêng cho Stg.