variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "single_nat_gateway" { type = bool }
variable "kubernetes_version" { type = string }
variable "eks_endpoint_public_access" { type = bool }
variable "eks_endpoint_private_access" { type = bool }
variable "eks_enabled_log_types" { type = list(string) }
variable "tags" { type = map(string) }

variable "s3_buckets" {
  type = map(object({
    name              = string
    enable_versioning = bool
    force_destroy     = bool
    expiration_days   = number
  }))
}

variable "eks_addons" {
  type = map(object({
    version                     = string
    resolve_conflicts_on_create = string
    resolve_conflicts_on_update = string
  }))
}
variable "ecr_repository_names" { type = list(string) }
variable "ecr_image_retention_days" { type = number }

variable "fargate_profiles" {
  type = map(object({
    name = optional(string, null)
    selectors = list(object({
      namespace = string
    }))
  }))
}

# Helm Add-ons
variable "enable_metrics_server" { type = bool }
variable "metrics_server_chart_version" { type = string }
variable "enable_envoy_gateway" { type = bool }
variable "envoy_gateway_chart_version" { type = string }
variable "enable_velero" { type = bool }
variable "velero_chart_version" { type = string }
variable "enable_velero_schedule" { type = bool }

# Fargate Observability
variable "enable_fargate_logging" { type = bool }
variable "fargate_log_retention_days" { type = number }
variable "enable_adot_collector" { type = bool }
variable "adot_collector_chart_version" { type = string }
variable "adot_collector_replicas" { type = number }

variable "security_groups" {
  type = map(object({
    description = string
    ingress_rules = list(object({
      cidr_ipv4         = string
      from_port         = number
      protocol          = string
      referenced_sg_key = string
      to_port           = number
    }))
    egress_rules = list(object({
      cidr_ipv4 = string
      protocol  = string
    }))
  }))
}

variable "rds_instances" {
  type = map(object({
    allocated_storage                                             = number
    automated_backups_replication_kms_key_deletion_window_in_days = number
    automated_backups_replication_retention_period                = number
    backup_retention_period                                       = number
    backup_window                                                 = string
    db_instance_class                                             = string
    db_name                                                       = string
    db_username                                                   = string
    delete_automated_backups                                      = bool
    deletion_protection                                           = bool
    enable_automated_backups_replication                          = bool
    engine_version                                                = string
    maintenance_window                                            = string
    max_allocated_storage                                         = number
    multi_az                                                      = bool
    performance_insights_enabled                                  = bool
    rds_automated_backups_replication_region                      = string
    secret_recovery_window_in_days                                = number
    security_group_key                                            = string
    skip_final_snapshot                                           = bool
  }))
}

variable "albs" { type = any }
variable "cloudfront_distributions" { type = any }
variable "cloudwatch_create_rds_alarms" { type = bool }
variable "cloudwatch_create_alb_alarms" { type = bool }
variable "cloudwatch_log_retention_days" { type = number }
variable "alarm_email" { type = string }
