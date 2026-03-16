variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Enable HTTP/2 on the ALB"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Idle timeout in seconds for the ALB"
  type        = number
  default     = 60
}

variable "listeners" {
  description = <<-EOT
    Map of listeners to create on this ALB.
    Each key is a logical name (e.g. "http", "https").
    - port             : listener port (required)
    - protocol         : HTTP or HTTPS (required)
    - redirect_to_https: if true, listener redirects HTTP → HTTPS 301 (optional)
    - certificate_arn  : ACM certificate ARN, required when protocol = HTTPS
    Example:
      listeners = {
        http  = { port = 80,  protocol = "HTTP",  redirect_to_https = true }
        https = { port = 443, protocol = "HTTPS", certificate_arn = "arn:aws:acm:..." }
      }
  EOT
  type        = any
  default = {
    http = {
      port     = 80
      protocol = "HTTP"
    }
  }
}

variable "default_target_group" {
  description = "Key of the target group to use as the default listener action"
  type        = string
  default     = "web"
}

variable "target_groups" {
  description = <<-EOT
    Map of target groups to create for this ALB. Each key becomes part of the
    target group name (max combined 32 chars). Supports multiple TGs per ALB.
    Example:
      target_groups = {
        web = {
          port          = 3000
          path_patterns = null   # default route
          health_check  = { path = "/" }
        }
        api = {
          port          = 3001
          path_patterns = ["/api/*"]
          priority      = 100
          health_check  = { path = "/api/status" }
        }
      }
  EOT
  type        = any
  default = {
    web = {
      port = 3000
      health_check = {
        path                = "/"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 3
        unhealthy_threshold = 3
      }
    }
    api = {
      port          = 3001
      path_patterns = ["/api/*"]
      priority      = 100
      health_check = {
        path                = "/api/status"
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 3
        unhealthy_threshold = 3
      }
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
