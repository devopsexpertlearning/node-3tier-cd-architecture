variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  description = "AWS region used in dashboard widgets"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name for log group"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier for alarms"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for alarms"
  type        = string
  default     = ""
}

variable "create_rds_alarms" {
  description = "Whether to create RDS CloudWatch alarms"
  type        = bool
  default     = false
}

variable "create_alb_alarms" {
  description = "Whether to create ALB CloudWatch alarms"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
