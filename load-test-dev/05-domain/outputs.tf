# load-test-dev/05-domain/outputs.tf
# CloudFront 및 도메인 설정 출력 변수

# ===============================
# CloudFront 정보
# ===============================

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution 도메인 이름"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront Distribution Hosted Zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

# ===============================
# 도메인 정보
# ===============================

output "custom_domain" {
  description = "커스텀 도메인 이름"
  value       = "chat.goorm-ktb-008.goorm.team"
}

output "route53_zone_id" {
  description = "Route 53 호스팅 존 ID"
  value       = data.aws_route53_zone.main.zone_id
}

# ===============================
# 접속 URL 정보
# ===============================

output "application_urls" {
  description = "애플리케이션 접속 URL들"
  value = {
    main_site     = "https://chat.goorm-ktb-008.goorm.team"
    api_endpoint  = "https://chat.goorm-ktb-008.goorm.team/api"
    health_check  = "https://chat.goorm-ktb-008.goorm.team/health"
    cloudfront_direct = "https://${aws_cloudfront_distribution.main.domain_name}"
  }
}

# ===============================
# Origins 정보
# ===============================

output "origins_info" {
  description = "CloudFront Origins 정보"
  value = {
    frontend_s3 = {
      domain_name = data.aws_s3_bucket.frontend.bucket_domain_name
      origin_id   = "S3-${data.aws_s3_bucket.frontend.id}"
      purpose     = "프론트엔드 정적 파일 (/, /chat, /profile 등)"
    }
    backend_alb = {
      domain_name = data.aws_lb.backend_alb.dns_name
      origin_id   = "ALB-${data.aws_lb.backend_alb.name}"
      purpose     = "백엔드 API (/api/*, /health)"
    }
  }
}

# ===============================
# Cache Behaviors 정보
# ===============================

output "routing_info" {
  description = "CloudFront 라우팅 규칙"
  value = {
    default_behavior = {
      path_pattern = "모든 요청 (/*)"
      target       = "S3 (프론트엔드)"
      caching      = "최적화된 캐싱"
      description  = "Next.js 정적 파일, SPA 라우팅 지원"
    }
    api_behavior = {
      path_pattern = "/api/*"
      target       = "ALB (백엔드)"
      caching      = "캐싱 비활성화"
      description  = "백엔드 API 호출, 모든 HTTP 메서드 지원"
    }
    health_behavior = {
      path_pattern = "/health"
      target       = "ALB (백엔드)"
      caching      = "캐싱 비활성화"
      description  = "헬스체크 엔드포인트"
    }
  }
}

# ===============================
# 설정 요약
# ===============================

output "configuration_summary" {
  description = "CloudFront 설정 요약"
  value = {
    description = "chat.goorm-ktb-008.goorm.team - 프론트엔드(S3) + 백엔드(ALB) 통합"
    architecture = "CloudFront → S3 (/) + ALB (/api/*)"
    features = [
      "HTTPS 강제 리다이렉트",
      "SPA 라우팅 지원",
      "API 캐싱 비활성화",
      "전역 CDN 배포",
      "Origin Access Control 보안"
    ]
    ssl_certificate = data.aws_acm_certificate.main.arn
    function_enabled = "SPA 리다이렉트 함수 활성화"
  }
}

# ===============================
# 테스트 명령어
# ===============================

output "test_commands" {
  description = "배포 후 테스트 명령어들"
  value = {
    frontend_test = "curl -I https://chat.goorm-ktb-008.goorm.team"
    api_test      = "curl https://chat.goorm-ktb-008.goorm.team/api/health"
    health_test   = "curl https://chat.goorm-ktb-008.goorm.team/health"
    
    # DNS 전파 확인
    dns_check = "nslookup chat.goorm-ktb-008.goorm.team"
    
    # CloudFront 캐시 무효화 (필요시)
    cache_invalidation = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.main.id} --paths '/*'"
  }
} 