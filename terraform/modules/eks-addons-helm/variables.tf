variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

# EKS Cluster Connection
variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64 encoded)"
  type        = string
}

variable "cluster_token" {
  description = "EKS cluster authentication token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "EKS cluster name for log group naming"
  type        = string
}

# Envoy Gateway
variable "enable_envoy_gateway" {
  type    = bool
  default = true
}

variable "envoy_gateway_chart_version" {
  type    = string
  default = "v1.7.1"
}

variable "envoy_gateway_custom_values" {
  description = "Custom YAML values for Envoy Gateway"
  type        = string
  default     = ""
}

# Metrics Server
variable "enable_metrics_server" {
  description = "Enable Kubernetes Metrics Server (required for HPA and kubectl top)"
  type        = bool
  default     = true
}

variable "metrics_server_chart_version" {
  description = "Metrics Server Helm chart version"
  type        = string
  default     = "3.12.2"
}

# Velero
variable "enable_velero" {
  type    = bool
  default = true
}

variable "velero_chart_version" {
  type    = string
  default = "11.4.0"
}

variable "velero_backup_s3_bucket" {
  type    = string
  default = ""
}

variable "velero_iam_role_arn" {
  type    = string
  default = ""
}

variable "velero_custom_values" {
  description = "Custom YAML values for Velero"
  type        = string
  default     = ""
}

variable "enable_velero_schedule" {
  description = "Enable daily automated Velero backup schedule (runs at 02:00 UTC, 30-day retention)"
  type        = bool
  default     = true
}

# Fargate Logging
variable "enable_fargate_logging" {
  description = "Enable Fargate built-in Fluent Bit logging to CloudWatch"
  type        = bool
  default     = true
}

variable "fargate_log_retention_days" {
  description = "CloudWatch log retention days for Fargate logs"
  type        = number
  default     = 30
}

# ADOT Collector (Metrics + Tracing)
variable "enable_adot_collector" {
  description = "Enable ADOT Collector for CloudWatch Container Insights and X-Ray tracing"
  type        = bool
  default     = true
}

variable "adot_collector_chart_version" {
  description = "OpenTelemetry Collector Helm chart version"
  type        = string
  default     = "0.108.0"
}

variable "adot_collector_replicas" {
  description = "Number of ADOT collector replicas"
  type        = number
  default     = 1
}

variable "adot_iam_role_arn" {
  description = "IAM role ARN for ADOT collector IRSA (CloudWatch + X-Ray permissions)"
  type        = string
  default     = ""
}
