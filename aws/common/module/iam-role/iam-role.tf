 resource "aws_iam_role" "this" {
  name = "${var.project_name}-${var.environment}-${var.instance_name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.instance_name}-role"
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-${var.environment}-${var.instance_name}-profile"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.project_name}-${var.environment}-${var.instance_name}-inline-policy"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

# 지금 iam-role은 instance 전용이므로 신뢰정책은 이 모듈 내부에 작성함
# 만약 ECS나 Lambda 등 다른 서비스에서 사용할 경우 신뢰정책은 외부에 작성해야 함
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
