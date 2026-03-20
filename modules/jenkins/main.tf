# Security Group cho Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-jenkins-sg"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-jenkins-sg" }
}

# Launch Template (Cấu hình máy ảo)
resource "aws_launch_template" "jenkins_lt" {
  name_prefix   = "${var.project_name}-jenkins-lt-"
  image_id      = "ami-0be9cb9f67c8dabd6" # Amazon Linux 2023 (Singapore)
  instance_type = "t3.small"
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              # Cài đặt Java 17 (Bắt buộc cho Jenkins hiện đại)
              dnf install fontconfig java-17-amazon-corretto-devel -y
              
              # Cài đặt Jenkins
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              dnf install jenkins -y
              
              systemctl enable jenkins
              systemctl start jenkins
              EOF
  )
}

# Auto Scaling Group (Tính sẵn sàng cao)
resource "aws_autoscaling_group" "jenkins_asg" {
  name                = "${var.project_name}-jenkins-asg"
  min_size            = 1 # Có thể chỉnh lên 2 để test HA
  max_size            = 3
  desired_capacity    = 1 
  vpc_zone_identifier = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.jenkins_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-jenkins-instance"
    propagate_at_launch = true
  }
}