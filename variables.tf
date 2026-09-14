# -----------------------------------------------------
# Required
# -----------------------------------------------------

variable "app_name" {
  description = "Application name, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the RDS security group"
  type        = string
}

variable "data_subnet_ids" {
  description = "Map of AZ to data subnet ID (from networking module)"
  type        = map(string)
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to the database"
  type        = list(string)
}

variable "private_zone_id" {
  description = "Route53 private hosted zone ID for internal DNS record"
  type        = string
}

variable "internal_domain" {
  description = "Internal domain name (e.g. dojo.internal)"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t4g.micro, db.r6g.large)"
  type        = string
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
}

# -----------------------------------------------------
# Optional with defaults
# -----------------------------------------------------

variable "engine_version" {
  description = "PostgreSQL major version (AWS resolves latest minor)"
  type        = string
  default     = "16"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage in GB for autoscaling (set equal to allocated_storage to disable)"
  type        = number
  default     = 100
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily backup window in UTC (e.g. 03:00-04:00)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window in UTC (e.g. sun:04:00-sun:05:00)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection (disable explicitly for dev/sandbox)"
  type        = bool
  default     = true
}

variable "enable_enhanced_monitoring" {
  description = "Enable RDS Enhanced Monitoring (60s interval)"
  type        = bool
  default     = false
}

variable "deploy_read_replica" {
  description = "Deploy read replica(s)"
  type        = bool
  default     = false
}

variable "read_replica_count" {
  description = "Number of read replicas (when deploy_read_replica is true)"
  type        = number
  default     = 1
}
