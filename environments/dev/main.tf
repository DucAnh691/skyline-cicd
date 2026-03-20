# 1. Khởi tạo Tầng Mạng (VPC)
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.10.0/24", "10.0.11.0/24"]
}

#2. Tầng Bảo mật (Sẽ mở khóa sau khi xong module IAM)
module "iam" {
  source = "../../modules/iam"
  prefix = var.project_name
}

#3. Module Cơ sở dữ liệu (RDS) - Đã build xong
module "rds" {
  source             = "../../modules/rds"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = module.vpc.private_subnet_ids
  db_password        = var.db_password
}

# 4. Module Trùm cuối (EKS) - THÊM MỚI TẠI ĐÂY
module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "${var.project_name}-eks"
  vpc_id             = module.vpc.vpc_id
  
  # Truyền danh sách Subnet từ module VPC
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Truyền ARN của các Role từ module IAM
  cluster_role_arn   = module.iam.eks_cluster_role_arn
  node_role_arn      = module.iam.eks_node_role_arn

  # SSH Key nếu bạn muốn vào debug Node (Tùy chọn)
  ssh_key_name     = "web-key"

  # Đảm bảo các thành phần nền tảng phải xong trước
  depends_on = [
    module.vpc,
    module.iam
  ]
}

# 5. CI/CD Server (Jenkins)
module "jenkins" {
  source            = "../../modules/jenkins"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  ssh_key_name      = "web-key" # Đảm bảo key này đã tồn tại trên AWS Console

  depends_on = [module.vpc]
}