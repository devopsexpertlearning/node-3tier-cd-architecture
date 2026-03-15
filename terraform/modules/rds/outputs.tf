output "db_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_host" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "automated_backups_replication_id" {
  description = "ID of the automated backup replication resource"
  value       = length(aws_db_instance_automated_backups_replication.main) > 0 ? aws_db_instance_automated_backups_replication.main[0].id : ""
}
