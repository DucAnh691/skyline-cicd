# ------------------------------------------------------------------------------
# 1. IAM & SECURITY SETUP (BEST PRACTICES)
# ------------------------------------------------------------------------------

# IAM Role cho phép EC2 tương tác với AWS Services (ECR, EKS, SSM)
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project_name}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Policy: Cho phép Session Manager (SSM) để debug không cần mở Port 22
resource "aws_iam_role_policy_attachment" "ssm_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.jenkins_role.name
}

# Policy: Cho phép Jenkins tương tác với Container Registry (ECR)
resource "aws_iam_role_policy_attachment" "ecr_power" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.jenkins_role.name
}

# Policy: Cho phép Jenkins quản lý EKS (Cần thiết cho CD)
resource "aws_iam_role_policy_attachment" "eks_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.jenkins_role.name
}

# Policy: Cho phép Jenkins Agent lấy thông tin cluster để update kubeconfig
# Đây là quyền bị thiếu trong lỗi "AccessDeniedException"
resource "aws_iam_role_policy" "eks_describe" {
  name = "${var.project_name}-eks-describe-policy"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["eks:DescribeCluster"]
      Effect   = "Allow"
      Resource = "*" # Cho phép describe tất cả cluster, có thể giới hạn lại nếu cần
    }]
  })
}

# Instance Profile để gắn Role vào EC2
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

# --- SECURITY GROUPS ---

# SG cho Master: Mở Web UI và SSH từ IP Admin
resource "aws_security_group" "jenkins_master_sg" {
  name        = "${var.project_name}-jenkins-master-sg"
  description = "Security Group for Jenkins Master"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Allow SSH from Admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip_for_ssh]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-jenkins-master-sg" }
}

# SG cho Agent: Chỉ cho phép SSH từ Master (nguyên tắc bảo mật)
resource "aws_security_group" "jenkins_agent_sg" {
  name        = "${var.project_name}-jenkins-agent-sg"
  description = "Security Group for Jenkins Agents"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow SSH from Jenkins Master only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-jenkins-agent-sg" }
}

# Lấy AMI Amazon Linux 2023 mới nhất
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ------------------------------------------------------------------------------
# 2. JENKINS MASTER (CONTROLLER)
# ------------------------------------------------------------------------------

# Sử dụng EC2 Instance thông thường thay vì ASG
resource "aws_instance" "jenkins_master" {
  # Sử dụng AMI động (Amazon Linux 2023) để luôn có bản vá bảo mật mới nhất
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  key_name               = var.ssh_key_name
  subnet_id              = var.public_subnet_ids[0] # Đặt tại subnet public đầu tiên
  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              hostnamectl set-hostname jenkins-master
              
              # Tạo Swap 2GB cho Jenkins Master (Quan trọng cho t3.small)
              dd if=/dev/zero of=/swapfile bs=1M count=2048
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
              
              # 1. Cài đặt Java 17 (Amazon Corretto)
              dnf install java-17-amazon-corretto-devel -y
              
              # 2. Cài đặt Jenkins
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              dnf install jenkins -y
              
              systemctl enable jenkins
              systemctl start jenkins

              # 3. Cài đặt Git & Docker (để Master có thể checkout code cơ bản)
              dnf install git docker -y
              systemctl enable docker
              systemctl start docker
              # Thêm user 'jenkins' vào group 'docker' để Jenkins có quyền thực thi lệnh docker
              usermod -aG docker jenkins
              EOF
  )

  tags = {
    Name = "${var.project_name}-jenkins-master"
  }
}

# Tạo Elastic IP để cố định IP cho Jenkins Master
resource "aws_eip" "jenkins_master_eip" {
  instance = aws_instance.jenkins_master.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-jenkins-master-eip"
  }
}

# ------------------------------------------------------------------------------
# 3. JENKINS AGENTS (WORKERS)
# ------------------------------------------------------------------------------

resource "aws_launch_template" "jenkins_agent_lt" {
  name_prefix   = "${var.project_name}-jenkins-agent-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.small" # Có thể tăng lên t3.medium cho agent
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.jenkins_profile.name
  }

  # Tăng dung lượng ổ cứng lên 20GB để chứa Swap file và Docker Images
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.jenkins_agent_sg.id]
  }

  # Agent KHÔNG cài Jenkins, chỉ cài môi trường Build
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              
              # Lấy Instance ID và đặt Hostname động để dễ phân biệt trên Jenkins Dashboard
              TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
              hostnamectl set-hostname "jenkins-agent-$${INSTANCE_ID}"
              
              # Tạo Swap 3GB để hỗ trợ RAM cho t3.small (Tránh lỗi OOM khi Master connect)
              dd if=/dev/zero of=/swapfile bs=1M count=3072
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
              
              # 1. Cài đặt Java 17 (Yêu cầu bắt buộc để Master kết nối qua SSH)
              dnf install java-17-amazon-corretto-devel -y
              
              # 2. Cài đặt Docker (Để build image)
              dnf install docker -y
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user

              # 3. Cài đặt Git
              dnf install git -y

              # 3.1 Cài đặt Maven (Bắt buộc để build Java Project)
              dnf install maven -y

              # 4. Cài đặt AWS CLI (Để xác thực với EKS)
              dnf install awscli -y

              # 5. Cài đặt kubectl (Phiên bản 1.32 - Khớp với EKS Cluster)
              curl -LO https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              # 6. Cài đặt Helm (Quản lý package Kubernetes)
              curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-jenkins-agent" }
  }
}

resource "aws_autoscaling_group" "jenkins_agent_asg" {
  name                = "${var.project_name}-jenkins-agent-asg"
  min_size            = 0 # Tối ưu chi phí: Cho phép scale-in về 0 khi không cần build
  max_size            = 5
  desired_capacity    = 2
  vpc_zone_identifier = var.public_subnet_ids

  # TỐI ƯU HÓA: Sử dụng Mixed Instances Policy để chạy Spot Instances (Tiết kiệm chi phí)
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0 # 100% dùng Spot
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.jenkins_agent_lt.id
        version            = "$Latest"
      }
      # Nếu t3.small hết Spot, tự động chuyển sang t3.medium
      override { instance_type = "t3.small" }
      override { instance_type = "t3.medium" }
    }
  }
}