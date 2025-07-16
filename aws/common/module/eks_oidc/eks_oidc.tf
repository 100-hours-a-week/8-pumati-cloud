data "tls_certificate" "this" {
  url = var.oidc_url
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = var.oidc_url

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-${var.service_name}-provider"
    Component = "EKS-OIDC"
  })
}
