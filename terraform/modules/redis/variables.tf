variable "cluster_id" {
  description = "Group identifier for the ElastiCache cluster"
  type        = string
}

variable "node_type" {
  description = "The compute and memory capacity of the nodes"
  type        = string
  default     = "cache.r6g.large"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes in the cluster"
  type        = number
  default     = 3
}

variable "parameter_group" {
  description = "Name of the parameter group to associate with this cache cluster"
  type        = string
  default     = "default.redis7"
}

variable "port" {
  description = "Port number on which each of the cache nodes will accept connections"
  type        = number
  default     = 6379
}

variable "subnet_group_name" {
  description = "Name of the cache subnet group to be used for the cache cluster"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with this cache cluster"
  type        = list(string)
}

variable "at_rest_encryption_enabled" {
  description = "Whether to enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Whether to enable encryption in transit"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Auth token for password protecting redis"
  type        = string
  default     = null
  sensitive   = true
}

variable "snapshot_retention_limit" {
  description = "Number of days for which ElastiCache will retain automatic cache cluster snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range during which ElastiCache will begin taking a daily snapshot"
  type        = string
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  description = "Specifies the weekly time range for when maintenance on the cache cluster is performed"
  type        = string
  default     = "sun:05:00-sun:09:00"
}

variable "notification_topic_arn" {
  description = "ARN of an Amazon SNS topic to send ElastiCache notifications to"
  type        = string
  default     = null
}

variable "engine_version" {
  description = "Version number of the cache engine to be used for the cache clusters"
  type        = string
  default     = "7.0"
}

variable "auto_minor_version_upgrade" {
  description = "Specifies whether minor version engine upgrades will be applied automatically"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "create_parameter_group" {
  description = "Whether to create a custom parameter group"
  type        = bool
  default     = false
}

variable "create_subnet_group" {
  description = "Whether to create a subnet group"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of VPC Subnet IDs for the cache subnet group"
  type        = list(string)
  default     = []
}

variable "parameters" {
  description = "A list of Redis parameters to apply"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for the Redis cluster"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "The list of actions to execute when this alarm transitions into an ALARM state"
  type        = list(string)
  default     = []
}

variable "create_sns_topic" {
  description = "Whether to create an SNS topic for alerts"
  type        = bool
  default     = false
}

variable "alert_email_address" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}