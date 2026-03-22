terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Khóa ở bản 5.x để ổn định
    }
  }

  # Chuẩn Doanh nghiệp: Lưu state trên S3
  # (Bạn cần tạo bucket và dynamodb table bằng tay hoặc script riêng trước)
  # backend "s3" {
  #   bucket         = "skyline-terraform-state-427077356037" # Thay bằng tên bucket thực tế của bạn
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock" # Khuyên dùng để chống conflict khi nhiều người chạy cùng lúc
  # }
}

provider "aws" {
  region = var.aws_region
}