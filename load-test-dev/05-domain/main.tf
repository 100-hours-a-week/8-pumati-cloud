# load-test-dev/05-domain/main.tf
# CloudFront 설정 업데이트 - 백엔드 API 라우팅 추가
# 
# 이 모듈은 기존 CloudFront Distribution (E2UUSZ0MG179D8)에 
# 백엔드 ALB Origin을 추가하여 다음과 같이 라우팅합니다:
# - 기본 요청 (/*) → S3 (프론트엔드 정적 파일)
# - API 요청 (/api/*) → ALB (백엔드 서버)
# - 헬스체크 (/health) → ALB (백엔드 서버)

# ===============================
# CloudFront Distribution 메인 설정
# ===============================

resource "aws_cloudfront_distribution" "main" {
  # 기본 정보 설정
  comment             = "채팅 앱 - 프론트엔드(S3) + 백엔드(ALB) 통합 배포"
  default_root_object = "index.html"  # 루트 요청 시 반환할 기본 파일
  enabled             = true          # Distribution 활성화
  is_ipv6_enabled     = true          # IPv6 지원 활성화
  price_class         = "PriceClass_All"  # 전세계 모든 엣지 로케이션 사용
  http_version        = "http2"       # HTTP/2 프로토콜 사용
  
  # 커스텀 도메인 설정
  # CloudFront의 기본 도메인 대신 우리 도메인 사용
  aliases = ["chat.goorm-ktb-008.goorm.team"]

  # ===============================
  # Origins 설정 (데이터 소스)
  # ===============================
  
  # Origin 1: S3 버킷 (프론트엔드 정적 파일)
  # Next.js 빌드 결과물, HTML, CSS, JS, 이미지 등
  origin {
    domain_name              = data.aws_s3_bucket.frontend.bucket_domain_name
    origin_id                = "S3-${data.aws_s3_bucket.frontend.id}"
    origin_access_control_id = data.aws_cloudfront_origin_access_control.main.id
    
    # 연결 설정
    connection_attempts = 3   # 연결 실패 시 재시도 횟수
    connection_timeout  = 10  # 연결 타임아웃 (초)
  }

  # Origin 2: ALB (백엔드 API 서버)
  # Express.js 서버, Socket.IO, 데이터베이스 연동 등
  origin {
    domain_name = data.aws_lb.backend_alb.dns_name
    origin_id   = "ALB-${data.aws_lb.backend_alb.name}"
    
    # 커스텀 Origin 설정 (ALB는 HTTP/HTTPS 엔드포인트)
    custom_origin_config {
      http_port              = 80            # ALB HTTP 포트
      https_port             = 443           # ALB HTTPS 포트  
      origin_protocol_policy = "http-only"   # ALB에서 HTTP로 통신
      origin_ssl_protocols   = ["TLSv1.2"]   # HTTPS 사용 시 SSL 프로토콜
    }
    
    # 연결 설정
    connection_attempts = 3   # ALB 연결 실패 시 재시도
    connection_timeout  = 10  # ALB 연결 타임아웃
  }

  # ===============================
  # Cache Behaviors 설정 (라우팅 규칙)
  # ===============================

  # 기본 Behavior: 모든 요청을 S3로 (프론트엔드)
  # 정적 파일과 SPA 라우팅을 처리
  default_cache_behavior {
    target_origin_id       = "S3-${data.aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"  # HTTP → HTTPS 강제 리다이렉트
    compress               = true                  # GZIP 압축 활성화
    
    # 허용되는 HTTP 메서드 (정적 파일이므로 GET, HEAD만)
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]  # 캐시할 메서드
    
    # AWS 관리형 캐시 정책 사용 (정적 파일 최적화)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # Managed-CachingOptimized
    
    # SPA 라우팅을 위한 CloudFront Function 연결
    # /chat, /profile 등의 요청을 index.html로 리다이렉트
    function_association {
      event_type   = "viewer-request"  # 사용자 요청 시 실행
      function_arn = aws_cloudfront_function.spa_redirect.arn
    }
  }

  # API Behavior: /api/* 요청을 ALB로 (백엔드)
  # 모든 API 호출을 백엔드 서버로 전달
  ordered_cache_behavior {
    path_pattern           = "/api/*"                # API 경로 패턴
    target_origin_id       = "ALB-${data.aws_lb.backend_alb.name}"
    viewer_protocol_policy = "redirect-to-https"    # HTTPS 강제
    compress               = false                   # API 응답은 압축하지 않음
    
    # 모든 HTTP 메서드 허용 (REST API, WebSocket 업그레이드 등)
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]  # GET, HEAD만 캐시 가능하게 설정
    
    # API 응답은 캐싱하지 않음 (동적 데이터)
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # Managed-CachingDisabled
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"  # Managed-CORS-S3Origin
    
    # WebSocket 및 실시간 통신 지원
    trusted_signers = []  # 신뢰할 수 있는 서명자 없음
  }

  # Health Check Behavior: /health 요청을 ALB로
  # 서버 상태 확인을 위한 헬스체크 엔드포인트
  ordered_cache_behavior {
    path_pattern           = "/health"               # 헬스체크 경로
    target_origin_id       = "ALB-${data.aws_lb.backend_alb.name}"
    viewer_protocol_policy = "redirect-to-https"    # HTTPS 강제
    compress               = false                   # 헬스체크 응답은 압축 안함
    
    # 헬스체크는 GET 요청만 사용
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    
    # 헬스체크 결과는 캐싱하지 않음 (실시간 상태 확인)
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # Managed-CachingDisabled
  }

  # ===============================
  # SSL/TLS 인증서 설정
  # ===============================
  
  viewer_certificate {
    # us-east-1에 있는 ACM 인증서 사용 (CloudFront 요구사항)
    acm_certificate_arn      = data.aws_acm_certificate.main.arn
    ssl_support_method       = "sni-only"            # SNI 방식 SSL 지원
    minimum_protocol_version = "TLSv1.2_2021"        # 최소 TLS 1.2 사용
  }

  # ===============================
  # 지리적 제한 설정
  # ===============================
  
  restrictions {
    geo_restriction {
      restriction_type = "none"  # 지리적 제한 없음 (전세계 접근 허용)
    }
  }

  # ===============================
  # 리소스 태그 설정
  # ===============================
  
  tags = merge(local.common_tags, {
    Name        = "${local.project_name}-${local.environment}-cloudfront"
    Service     = "CloudFront"
    Purpose     = "Frontend + Backend Distribution"
    Environment = local.environment
    Component   = "CDN"
    Module      = "05-domain"
  })
}

# ===============================
# CloudFront Function (SPA 라우팅 지원)
# ===============================

# Next.js SPA를 위한 클라이언트 사이드 라우팅 지원
# /chat, /profile 등의 요청을 index.html로 리다이렉트하여
# React Router가 클라이언트에서 라우팅을 처리할 수 있도록 함
resource "aws_cloudfront_function" "spa_redirect" {
  name    = "${local.project_name}-${local.environment}-spa-redirect"
  runtime = "cloudfront-js-1.0"  # CloudFront JavaScript 런타임
  comment = "SPA 라우팅을 위한 index.html 리다이렉트"
  publish = true  # 함수를 즉시 배포
  
  # JavaScript 코드: 요청 URI를 분석하여 SPA 라우팅 처리
  code = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // API 요청과 헬스체크는 그대로 통과
    // 이미 다른 Cache Behavior에서 처리됨
    if (uri.startsWith('/api/') || uri.startsWith('/health')) {
        return request;
    }
    
    // 파일 확장자가 없는 경우 index.html로 리다이렉트
    // 예: /chat → /index.html, /profile → /index.html
    // 정적 파일(CSS, JS, 이미지)은 그대로 통과
    if (!uri.includes('.')) {
        request.uri = '/index.html';
    }
    
    return request;
}
EOT
}