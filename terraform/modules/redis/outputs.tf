output "id" {
  description = "ID of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.id
}

output "arn" {
  description = "ARN of the created ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.arn
}

output "primary_endpoint" {
  description = "Address of the endpoint for the primary node in the replication group"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Address of the endpoint for the reader node in the replication group"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "configuration_endpoint" {
  description = "Address of the replication group configuration endpoint when cluster mode is enabled"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "port" {
  description = "Port number on which each of the cache nodes will accept connections"
  value       = aws_elasticache_replication_group.main.port
}

output "cache_nodes" {
  description = "List of node objects including id, address, port and availability_zone"
  value = [
    for node in aws_elasticache_replication_group.main.cache_cluster : {
      id                = node.cache_node_id
      address          = node.cache_nodes[0].address
      port             = node.cache_nodes[0].port
      availability_zone = node.cache_nodes[0].availability_zone
    }
  ]
}

output "member_clusters" {
  description = "Identifiers of all the nodes that are part of this replication group"
  value       = aws_elasticache_replication_group.main.member_clusters
}

output "replication_group_id" {
  description = "ID of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "engine_version_actual" {
  description = "Running version of the cache engine"
  value       = aws_elasticache_replication_group.main.engine_version_actual
}

output "cluster_enabled" {
  description = "Indicates if cluster mode is enabled"
  value       = aws_elasticache_replication_group.main.cluster_enabled
}

output "parameter_group_name" {
  description = "Name of the parameter group used by the cache cluster"
  value       = var.create_parameter_group ? aws_elasticache_parameter_group.main[0].name : var.parameter_group
}

output "subnet_group_name" {
  description = "Name of the cache subnet group used by the cache cluster"
  value       = var.create_subnet_group ? aws_elasticache_subnet_group.main[0].name : var.subnet_group_name
}

output "auth_token_enabled" {
  description = "Whether auth token (password) is enabled"
  value       = var.auth_token != null
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for slow logs"
  value       = aws_cloudwatch_log_group.redis_slow.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.create_sns_topic ? aws_sns_topic.redis_alerts[0].arn : null
}