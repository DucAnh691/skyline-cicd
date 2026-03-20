# 1. EKS Cluster (Control Plane)
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.32" # Cập nhật phiên bản mới nhất 2026

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Cấu hình truy cập hiện đại (EKS Access Entries)
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = var.cluster_name
  }
}

# 2. EKS Managed Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.public_subnet_ids # Chạy trên Public Subnet để Zero NAT

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  # Sử dụng Amazon Linux 2023 mới nhất
  instance_types = ["t3.small"]
  ami_type       = "AL2023_x86_64_STANDARD" 

  # Đã loại bỏ remote_access để tránh lỗi KeyPair không tồn tại
  remote_access {
    ec2_ssh_key = var.ssh_key_name
  }
  
  depends_on = [
    aws_eks_cluster.main
  ]

  tags = {
    Name = "${var.cluster_name}-worker-node"
  }
}

# 3. OIDC Provider cho IAM Roles for Service Accounts (IRSA)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}