variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (for IRSA)"
  type        = string
  default     = ""
}

variable "eks_oidc_provider_url" {
  type    = string
  default = ""
}

variable "create_alb_controller_role" {
  description = "Whether to create the ALB load balancer controller IAM role"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
