variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17.2"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max allocated storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "backup_window" {
  description = "Daily time range during which automated backups are created"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly time range during which system maintenance can occur"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the DB instance is destroyed"
  type        = bool
  default     = true
}

variable "delete_automated_backups" {
  description = "Delete automated backups when the DB instance is destroyed"
  type        = bool
  default     = true
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights for the RDS instance"
  type        = bool
  default     = true
}

variable "secret_recovery_window_in_days" {
  description = "Number of days Secrets Manager waits before deleting the secret"
  type        = number
  default     = 0
}

variable "enable_automated_backups_replication" {
  description = "Enable cross-region replication for automated RDS backups"
  type        = bool
  default     = false
}

variable "automated_backups_replication_retention_period" {
  description = "Retention period for replicated automated backups in the destination region"
  type        = number
  default     = 7
}

variable "automated_backups_replication_kms_key_deletion_window_in_days" {
  description = "Deletion window in days for the KMS key used to encrypt replicated backups"
  type        = number
  default     = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
