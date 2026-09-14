# terraform-aws-rds
# Opinionated RDS PostgreSQL module — see CLAUDE.md for design decisions

locals {
  identifier = "${var.app_name}-${var.environment}"

  default_tags = {
    ManagedBy   = "terraform"
    Application = var.app_name
    Environment = var.environment
  }
}

# -----------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = local.identifier
  subnet_ids = values(var.data_subnet_ids)

  tags = merge(local.default_tags, {
    Name = "${local.identifier}-db-subnet-group"
  })
}

# -----------------------------------------------------
# Security Group
# -----------------------------------------------------

resource "aws_security_group" "this" {
  name_prefix = "${local.identifier}-rds-"
  description = "Security group for ${local.identifier} RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(local.default_tags, {
    Name = "${local.identifier}-rds"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
  description              = "PostgreSQL from ${each.value}"
}

# -----------------------------------------------------
# Parameter Group
# -----------------------------------------------------

resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.identifier}-pg${var.engine_version}-"
  family      = "postgres${var.engine_version}"
  description = "Parameter group for ${local.identifier}"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  tags = local.default_tags

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------
# Enhanced Monitoring IAM Role (optional)
# -----------------------------------------------------

resource "aws_iam_role" "monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  name = "${local.identifier}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.monitoring[0].name
}

# -----------------------------------------------------
# RDS Instance
# -----------------------------------------------------

resource "aws_db_instance" "this" {
  identifier = local.identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  port                   = 5432

  manage_master_user_password = true
  username                    = "postgres"

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${local.identifier}-final"
  copy_tags_to_snapshot      = true

  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.monitoring[0].arn : null

  performance_insights_enabled = true

  tags = merge(local.default_tags, {
    Name = local.identifier
  })
}

# -----------------------------------------------------
# Internal DNS Record
# -----------------------------------------------------

resource "aws_route53_record" "this" {
  zone_id = var.private_zone_id
  name    = "db.${var.app_name}.${var.internal_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.this.address]
}

# -----------------------------------------------------
# Read Replicas (optional)
# -----------------------------------------------------

resource "aws_db_instance" "replica" {
  count = var.deploy_read_replica ? var.read_replica_count : 0

  identifier          = "${local.identifier}-replica-${count.index}"
  replicate_source_db = aws_db_instance.this.identifier

  instance_class = var.instance_class
  storage_type   = "gp3"

  multi_az               = false
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  port                   = 5432

  auto_minor_version_upgrade = true
  skip_final_snapshot        = true

  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.monitoring[0].arn : null

  performance_insights_enabled = true

  tags = merge(local.default_tags, {
    Name = "${local.identifier}-replica-${count.index}"
  })
}
