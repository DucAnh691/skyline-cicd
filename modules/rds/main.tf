# 1. Tạo Subnet Group cho RDS 
# Gom các Private Subnets lại thành một nhóm để AWS biết chỗ đặt DB
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# 2. Security Group cho RDS
# Quy tắc: Chỉ cho phép các tài nguyên bên trong VPC truy cập cổng 3306
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow inbound traffic from VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Chỉ cho phép nội bộ VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# 3. Instance RDS MySQL
resource "aws_db_instance" "mysql" {
  identifier           = "${var.project_name}-db"
  allocated_storage    = 20            # 20GB (Mức tối thiểu)
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro" # Loại rẻ nhất để chạy thử
  
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password # Sẽ bị ẩn trên console nhờ biến sensitive
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  multi_az             = false         # Tắt để tiết kiệm chi phí cho môi trường Dev
  publicly_accessible  = false         # Tuyệt đối không mở Public IP
  skip_final_snapshot  = true          # Cho phép xóa nhanh mà không cần backup cuối cùng

  tags = {
    Name = "${var.project_name}-mysql-db"
  }
}