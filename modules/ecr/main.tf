# Tạo Repository cho từng Service trong danh sách
resource "aws_ecr_repository" "services" {
  for_each             = toset(var.service_names)
  name                 = each.value # Tên repo: user-service, order-service...
  image_tag_mutability = "MUTABLE"  # Cho phép ghi đè tag (tiện cho dev)

  image_scanning_configuration {
    scan_on_push = true # Quét bảo mật khi đẩy image lên
  }

  # Cho phép xóa repo ngay cả khi còn image (Dùng cho môi trường LAB/DEV)
  force_delete = true

  tags = {
    Name        = "${var.project_name}-${each.value}-repo"
    Environment = "dev"
  }
}

# Thiết lập chính sách vòng đời (Lifecycle Policy)
# Tự động xóa các image cũ để tiết kiệm chi phí, chỉ giữ lại 10 bản build mới nhất
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = toset(var.service_names)
  repository = aws_ecr_repository.services[each.value].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Giữ lại 10 images mới nhất"
      selection = {
        tagStatus   = "any" # Áp dụng cho cả image có tag và không tag (untagged)
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })

  depends_on = [aws_ecr_repository.services]
}
