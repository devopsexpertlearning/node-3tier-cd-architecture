# RDS Module

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# DB Subnet Group - ensures RDS is placed in private subnets
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  multi_az                  = var.multi_az
  publicly_accessible       = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  delete_automated_backups  = var.delete_automated_backups
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-postgres-final-${random_id.final_snapshot[0].hex}"
  copy_tags_to_snapshot     = true

  # Automated backups
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Performance Insights
  performance_insights_enabled = var.performance_insights_enabled

  # CloudWatch Logs — ship PostgreSQL logs off-host
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres"
  })
}

# Random Password Generation
resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_id" "final_snapshot" {
  count       = var.skip_final_snapshot ? 0 : 1
  byte_length = 4
}

resource "aws_kms_key" "automated_backups_replication" {
  count                   = var.enable_automated_backups_replication ? 1 : 0
  provider                = aws.replica
  description             = "KMS key for ${var.project_name}-${var.environment} replicated automated backups"
  deletion_window_in_days = var.automated_backups_replication_kms_key_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-backup-replication"
  })
}

resource "aws_kms_alias" "automated_backups_replication" {
  count         = var.enable_automated_backups_replication ? 1 : 0
  provider      = aws.replica
  name          = "alias/${var.project_name}-${var.environment}-rds-backup-replication"
  target_key_id = aws_kms_key.automated_backups_replication[0].key_id
}

resource "aws_db_instance_automated_backups_replication" "main" {
  count                  = var.enable_automated_backups_replication ? 1 : 0
  provider               = aws.replica
  source_db_instance_arn = aws_db_instance.main.arn
  kms_key_id             = aws_kms_key.automated_backups_replication[0].arn
  retention_period       = var.automated_backups_replication_retention_period

  depends_on = [aws_db_instance.main]
}

# AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-rds-creds-${random_password.db_password.id}"
  recovery_window_in_days = var.secret_recovery_window_in_days

  # Remove name_prefix and use name with random suffix from password ID 
  # (in case of recreation so secrets don't collide when recovery window is active)

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-creds"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username             = var.db_username
    password             = random_password.db_password.result
    engine               = "postgres"
    host                 = aws_db_instance.main.address
    port                 = aws_db_instance.main.port
    dbname               = var.db_name
    dbInstanceIdentifier = aws_db_instance.main.id
  })
}
