# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.storage_encrypted ? aws_kms_key.rds[0].arn : null
  
  db_name  = var.db_name
  username = var.username
  password = var.password
  
  vpc_security_group_ids = var.vpc_security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                  = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  auto_minor_version_upgrade = true
  apply_immediately         = var.apply_immediately
  
  tags = var.tags
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  count = var.storage_encrypted ? 1 : 0
  
  description = "KMS key for RDS encryption"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
    ]
  })
  
  tags = var.tags
}

resource "aws_kms_alias" "rds" {
  count = var.storage_encrypted ? 1 : 0
  
  name          = "alias/rds-${var.identifier}"
  target_key_id = aws_kms_key.rds[0].key_id
}

# Enhanced Monitoring IAM Role
resource "aws_iam_role" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  name = "${var.identifier}-enhanced-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/aws/rds/instance/${var.identifier}/postgresql"
  retention_in_days = var.cloudwatch_logs_retention_days
  
  tags = var.tags
}

# Read Replica (optional)
resource "aws_db_instance" "read_replica" {
  count = var.create_read_replica ? 1 : 0
  
  identifier             = "${var.identifier}-read-replica"
  replicate_source_db    = aws_db_instance.main.id
  instance_class         = var.read_replica_instance_class != null ? var.read_replica_instance_class : var.instance_class
  
  vpc_security_group_ids = var.vpc_security_group_ids
  
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval         = var.monitoring_interval
  monitoring_role_arn        = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
  
  auto_minor_version_upgrade = true
  
  tags = merge(var.tags, {
    Name = "${var.identifier}-read-replica"
  })
}

# Parameter Group
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.identifier}-pg"
  
  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
  
  tags = var.tags
}

# Option Group
resource "aws_db_option_group" "main" {
  name                 = "${var.identifier}-og"
  option_group_description = "Option group for ${var.identifier}"
  engine_name          = "postgres"
  major_engine_version = "15"
  
  tags = var.tags
}

# Automated Backup
resource "aws_db_automated_backup_replication" "main" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  source_db_instance_arn = aws_db_instance.main.arn
  destination_region     = var.backup_destination_region
  
  tags = var.tags
}

# Data sources
data "aws_caller_identity" "current" {}

# DB Snapshot
resource "aws_db_snapshot" "main" {
  count = var.create_manual_snapshot ? 1 : 0
  
  db_instance_identifier = aws_db_instance.main.id
  db_snapshot_identifier = "${var.identifier}-manual-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  tags = var.tags
}