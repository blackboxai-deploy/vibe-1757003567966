# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = var.cluster_id
  description                  = "Redis cluster for ${var.cluster_id}"
  
  node_type                    = var.node_type
  port                         = var.port
  parameter_group_name         = var.parameter_group
  
  num_cache_clusters           = var.num_cache_nodes
  
  automatic_failover_enabled   = var.num_cache_nodes > 1
  multi_az_enabled            = var.num_cache_nodes > 1
  
  subnet_group_name           = var.subnet_group_name
  security_group_ids          = var.security_group_ids
  
  at_rest_encryption_enabled  = var.at_rest_encryption_enabled
  transit_encryption_enabled  = var.transit_encryption_enabled
  auth_token                  = var.auth_token
  
  # Backup configuration
  snapshot_retention_limit    = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window
  
  # Maintenance
  maintenance_window         = var.maintenance_window
  
  # Notification
  notification_topic_arn     = var.notification_topic_arn
  
  # Engine version
  engine_version             = var.engine_version
  
  # Auto upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
  # Logs
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }
  
  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/redis/${var.cluster_id}/slow-log"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# Parameter Group (custom)
resource "aws_elasticache_parameter_group" "main" {
  count = var.create_parameter_group ? 1 : 0
  
  family = "redis7.x"
  name   = "${var.cluster_id}-params"
  
  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
  
  tags = var.tags
}

# Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  count = var.create_subnet_group ? 1 : 0
  
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = var.tags
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.cluster_id}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cache_memory" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.cluster_id}-high-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = "120"
  statistic           = "Average"
  threshold           = "100000000"  # 100MB in bytes
  alarm_description   = "This metric monitors Redis freeable memory"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cache_connection_count" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.cluster_id}-high-connection-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "120"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "This metric monitors Redis connection count"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
  
  tags = var.tags
}

# SNS Topic for notifications
resource "aws_sns_topic" "redis_alerts" {
  count = var.create_sns_topic ? 1 : 0
  
  name = "${var.cluster_id}-alerts"
  
  tags = var.tags
}

resource "aws_sns_topic_subscription" "redis_alerts_email" {
  count = var.create_sns_topic && var.alert_email_address != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.redis_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email_address
}