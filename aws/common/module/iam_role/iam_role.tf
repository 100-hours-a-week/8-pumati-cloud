resource "aws_iam_role" "this" {
  name               = "${var.project_name}-${var.environment}-${var.service_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-role"
  })
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.project_name}-${var.environment}-${var.service_name}-inline-policy"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
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
