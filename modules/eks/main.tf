resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.33" # Hoặc version mới nhất bạn muốn

  vpc_config {
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # QUAN TRỌNG: Bật chế độ xác thực API để cho phép Jenkins Access Entry hoạt động
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

# Add ingress rules to the EKS cluster's primary security group.
# This allows sources (like the Jenkins agent) to communicate with the K8s API server.
resource "aws_security_group_rule" "allow_additional_sgs_to_eks" {
  count                    = length(var.additional_security_group_ids_for_cluster)
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.additional_security_group_ids_for_cluster[count.index]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.public_subnet_ids # Trong LAB dùng public để dễ debug, Prod nên dùng private

  scaling_config {
    # Giữ 1 Node để tiết kiệm vCPU (Tránh lỗi VcpuLimitExceeded của tài khoản Free Tier)
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # ISTIO REQUIREMENT: Dùng m7i-flex.large (8GB RAM) để đủ bộ nhớ cho Sidecar Proxies
  # c7i-flex.large chỉ có 4GB RAM, rất dễ bị crash khi chạy Istio
  instance_types = ["c7i-flex.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_eks_cluster.main]
}

# --- EKS ACCESS ENTRIES (Quyền truy cập K8s cho IAM Roles) ---

# 1. Tạo Access Entry cho Jenkins Role
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.jenkins_role_arn
  type          = "STANDARD"
}

# 2. Gán quyền Cluster Admin cho Jenkins Role
resource "aws_eks_access_policy_association" "jenkins_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.jenkins_role_arn

  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.jenkins]
}