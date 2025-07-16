resource "aws_iam_role" "this" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-role"

  assume_role_policy = var.assume_role_policy_json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-role"
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = length(var.managed_policy_arns)
  policy_arn = var.managed_policy_arns[count.index]
  role       = aws_iam_role.this.name
}
