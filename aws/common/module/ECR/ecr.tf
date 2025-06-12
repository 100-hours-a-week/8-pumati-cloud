resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}-${var.environment}-${var.service_name}-ecr"
  image_tag_mutability = "MUTABLE"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-ecr"
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images > 14 days"
      selection = {
        tagStatus     = "untagged"
        countType     = "sinceImagePushed"
        countUnit     = "days"
        countNumber   = 14 // 14일 이상 된 태그 없는 이미지 자동 삭제 정책
      }
      action = {
        type = "expire"
      }
    }]
  })
}
