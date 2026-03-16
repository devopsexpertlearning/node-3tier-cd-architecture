# CloudFront Module

locals {
  origin_id = "${var.project_name}-${var.environment}-alb-origin"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = var.enabled
  is_ipv6_enabled     = var.is_ipv6_enabled
  comment             = "${var.project_name} ${var.environment} CDN"
  default_root_object = ""
  price_class         = var.price_class
  wait_for_deployment = var.wait_for_deployment
  aliases             = var.aliases

  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior - dynamic content (forward all)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Referer"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = var.default_viewer_protocol_policy
    min_ttl                = var.default_cache_ttl.min
    default_ttl            = var.default_cache_ttl.default
    max_ttl                = var.default_cache_ttl.max
    compress               = true
  }

  # Cache behavior for static assets
  dynamic "ordered_cache_behavior" {
    for_each = var.static_cache_behaviors
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = local.origin_id

      forwarded_values {
        query_string = false
        headers      = ["Host", "Origin", "Referer"]
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      min_ttl                = ordered_cache_behavior.value.min_ttl
      default_ttl            = ordered_cache_behavior.value.default_ttl
      max_ttl                = ordered_cache_behavior.value.max_ttl
      compress               = true
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == "" ? true : null
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-cdn"
  })
}
