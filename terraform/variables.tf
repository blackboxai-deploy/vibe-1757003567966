variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "animagenius"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "animagenius"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "animagenius"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
}

variable "synthesia_api_key" {
  description = "Synthesia API key"
  type        = string
  sensitive   = true
}

variable "heygen_api_key" {
  description = "HeyGen API key"
  type        = string
  sensitive   = true
}

variable "replicate_api_key" {
  description = "Replicate API key"
  type        = string
  sensitive   = true
}

variable "openrouter_api_key" {
  description = "OpenRouter API key"
  type        = string
  sensitive   = true
}

# Monitoring configuration
variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable centralized logging"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Enable distributed tracing"
  type        = bool
  default     = true
}

# Security configuration
variable "enable_pod_security_policies" {
  description = "Enable Pod Security Policies"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Enable Network Policies"
  type        = bool
  default     = true
}

# Backup configuration
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

# Scaling configuration
variable "min_nodes" {
  description = "Minimum number of nodes in each node group"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of nodes in each node group"
  type        = number
  default     = 10
}

variable "desired_nodes" {
  description = "Desired number of nodes in each node group"
  type        = number
  default     = 3
}

# Instance configuration
variable "general_instance_types" {
  description = "Instance types for general workloads"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge", "m5.2xlarge"]
}

variable "gpu_instance_types" {
  description = "Instance types for GPU workloads"
  type        = list(string)
  default     = ["p3.2xlarge", "p3.8xlarge", "g4dn.xlarge"]
}

variable "compute_instance_types" {
  description = "Instance types for compute-intensive workloads"
  type        = list(string)
  default     = ["c5.2xlarge", "c5.4xlarge", "c5.9xlarge"]
}