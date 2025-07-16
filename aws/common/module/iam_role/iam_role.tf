resource "aws_iam_role" "this" {
  name               = "${var.project_name}-${var.environment}-${var.service_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-role"
  })
}

# 인라인 정책 (사용 여부 확인)
resource "aws_iam_role_policy" "this" {
  count  = var.enable_inline_policy ? 1 : 0
  name   = "${var.project_name}-${var.environment}-${var.service_name}-inline-policy"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

# 관리형 정책 (사용 여부 확인)
resource "aws_iam_role_policy_attachment" "managed" {
  count      = var.enable_managed_policy ? length(var.managed_policy_arns) : 0
  policy_arn = var.managed_policy_arns[count.index]
  role       = aws_iam_role.this.name
}

resource "aws_iam_instance_profile" "this" {
  count = var.instance_profile_enabled ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.service_name}-profile"
  role = aws_iam_role.this.name
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [var.assume_role_service]
    }
  }
}
