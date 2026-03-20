terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Khóa ở bản 5.x để ổn định
    }
  }

  # Tạm thời dùng Local State. Khi lên Prod hãy đổi sang S3 Backend.
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}