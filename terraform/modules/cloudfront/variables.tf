variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB origin"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "enabled" {
  description = "Whether the CloudFront distribution is enabled"
  type        = bool
  default     = true
}

variable "is_ipv6_enabled" {
  description = "Whether IPv6 is enabled for the CloudFront distribution"
  type        = bool
  default     = true
}

variable "wait_for_deployment" {
  description = "Whether to wait for the CloudFront deployment to complete"
  type        = bool
  default     = true
}

variable "origin_protocol_policy" {
  description = "Protocol policy used by CloudFront when connecting to the origin"
  type        = string
  default     = "http-only"
}

variable "default_viewer_protocol_policy" {
  description = "Viewer protocol policy for the default cache behavior"
  type        = string
  default     = "redirect-to-https"
}

variable "default_cache_ttl" {
  description = "TTL settings for the default cache behavior"
  type = object({
    min     = number
    default = number
    max     = number
  })
  default = {
    min     = 0
    default = 0
    max     = 86400
  }
}

variable "static_cache_behaviors" {
  description = "Static asset cache behavior definitions"
  type = list(object({
    path_pattern           = string
    viewer_protocol_policy = string
    min_ttl                = number
    default_ttl            = number
    max_ttl                = number
  }))
  default = [
    {
      path_pattern           = "/stylesheets/*"
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 3600
      default_ttl            = 86400
      max_ttl                = 604800
    },
    {
      path_pattern           = "/images/*"
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 3600
      default_ttl            = 86400
      max_ttl                = 604800
    }
  ]
}

variable "aliases" {
  description = "Alternate domain names (CNAMEs) for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in us-east-1). If empty, uses CloudFront default certificate."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
