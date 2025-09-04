output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_hosted_zone_id" {
  description = "The canonical hosted zone ID of the DB instance"
  value       = aws_db_instance.main.hosted_zone_id
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_engine" {
  description = "The database engine"
  value       = aws_db_instance.main.engine
}

output "db_instance_engine_version" {
  description = "The running version of the database"
  value       = aws_db_instance.main.engine_version
}

output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.main.arn
}

output "db_parameter_group_id" {
  description = "The db parameter group id"
  value       = aws_db_parameter_group.main.id
}

output "db_option_group_id" {
  description = "The db option group id"
  value       = aws_db_option_group.main.id
}

output "read_replica_endpoint" {
  description = "The read replica endpoint"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].endpoint : null
}

output "read_replica_id" {
  description = "The read replica ID"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].id : null
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = var.storage_encrypted ? aws_kms_key.rds[0].key_id : null
}

output "enhanced_monitoring_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the monitoring role"
  value       = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
}