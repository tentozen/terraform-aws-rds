# terraform-aws-rds

Opinionated Terraform module for deploying a production-ready RDS PostgreSQL instance with TLS enforced, encryption at rest, managed master credentials, slow query logging, pg_stat_statements, internal DNS, optional enhanced monitoring, and optional read replicas.

## Usage

### Basic

```hcl
module "rds" {
  source = "git::git@github.com:tentozen/terraform-aws-rds.git?ref=main"

  app_name    = "myapp"
  environment = "prod"
  region      = "us-east-1"

  vpc_id          = module.networking.vpc_id
  data_subnet_ids = module.networking.data_subnet_ids
  private_zone_id = module.networking.private_zone_id
  internal_domain = module.networking.internal_domain

  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  instance_class = "db.r6g.large"
  multi_az       = true
}
```

### With read replicas and enhanced monitoring

```hcl
module "rds" {
  source = "git::git@github.com:tentozen/terraform-aws-rds.git?ref=main"

  app_name    = "myapp"
  environment = "prod"
  region      = "us-east-1"

  vpc_id          = module.networking.vpc_id
  data_subnet_ids = module.networking.data_subnet_ids
  private_zone_id = module.networking.private_zone_id
  internal_domain = module.networking.internal_domain

  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  instance_class = "db.r6g.large"
  multi_az       = true

  deploy_read_replica        = true
  read_replica_count         = 2
  enable_enhanced_monitoring = true
}
```

### Dev/sandbox (minimal, no deletion protection)

```hcl
module "rds" {
  source = "git::git@github.com:tentozen/terraform-aws-rds.git?ref=main"

  app_name    = "myapp"
  environment = "dev"
  region      = "us-east-1"

  vpc_id          = module.networking.vpc_id
  data_subnet_ids = module.networking.data_subnet_ids
  private_zone_id = module.networking.private_zone_id
  internal_domain = module.networking.internal_domain

  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  instance_class      = "db.t4g.micro"
  multi_az            = false
  deletion_protection = false
}
```

## What gets created

| Resource | Always | With `enable_enhanced_monitoring` | With `deploy_read_replica` |
|---|---|---|---|
| RDS PostgreSQL instance (gp3, encrypted) | x | | |
| DB subnet group | x | | |
| Security group (port 5432 ingress) | x | | |
| Parameter group (TLS, slow query log, pg_stat_statements) | x | | |
| Route53 CNAME (`db.<app_name>.<internal_domain>`) | x | | |
| Enhanced monitoring IAM role | | x | |
| Read replica(s) | | | x |

## Variables

| Name | Type | Default | Description |
|---|---|---|---|
| `app_name` | `string` | required | Application name, used for resource naming and tagging |
| `environment` | `string` | required | Environment name (e.g. dev, staging, prod) |
| `region` | `string` | required | AWS region |
| `vpc_id` | `string` | required | VPC ID for the RDS security group |
| `data_subnet_ids` | `map(string)` | required | Map of AZ to data subnet ID (from networking module) |
| `allowed_security_group_ids` | `list(string)` | required | Security group IDs allowed to connect |
| `private_zone_id` | `string` | required | Route53 private hosted zone ID |
| `internal_domain` | `string` | required | Internal domain name (e.g. myapp.internal) |
| `instance_class` | `string` | required | RDS instance class (e.g. db.t4g.micro, db.r6g.large) |
| `multi_az` | `bool` | required | Enable Multi-AZ deployment |
| `engine_version` | `string` | `"16"` | PostgreSQL major version (AWS resolves latest minor) |
| `allocated_storage` | `number` | `20` | Initial allocated storage in GB |
| `max_allocated_storage` | `number` | `100` | Maximum storage in GB for autoscaling |
| `backup_retention_period` | `number` | `7` | Days to retain automated backups |
| `backup_window` | `string` | `"03:00-04:00"` | Daily backup window (UTC) |
| `maintenance_window` | `string` | `"sun:04:00-sun:05:00"` | Weekly maintenance window (UTC) |
| `deletion_protection` | `bool` | `true` | Enable deletion protection |
| `enable_enhanced_monitoring` | `bool` | `false` | Enable Enhanced Monitoring (60s interval) |
| `deploy_read_replica` | `bool` | `false` | Deploy read replica(s) |
| `read_replica_count` | `number` | `1` | Number of read replicas (when enabled) |

## Outputs

| Name | Description |
|---|---|
| `endpoint` | RDS instance endpoint (host:port) |
| `reader_endpoint` | Read replica endpoint (empty if not deployed) |
| `port` | Database port (5432) |
| `master_secret_arn` | ARN of the Secrets Manager secret containing master credentials |
| `security_group_id` | Security group ID for the RDS instance |
| `internal_dns_name` | Internal DNS name (`db.<app_name>.<internal_domain>`) |

## Design decisions

- **RDS PostgreSQL, not Aurora** — simpler operational model, sufficient for current workloads. Aurora is a separate module if needed.
- **Managed master password** — `manage_master_user_password = true` lets AWS rotate credentials automatically via Secrets Manager. No static master password in Terraform state.
- **Per-app credentials are the consumer's concern** — the module creates the instance; the consumer creates app-specific databases and users, stores creds in Secrets Manager, and syncs via ESO. No initial `db_name` is created.
- **TLS enforced** — `rds.force_ssl = 1` in the parameter group. Clients using `sslmode=prefer` (the default) connect over TLS transparently; `sslmode=disable` is rejected.
- **gp3 with autoscaling** — gp3 baseline performance, storage grows automatically from `allocated_storage` to `max_allocated_storage`. No IOPS/throughput variables — gp3 baseline is sufficient for most workloads.
- **`data_subnet_ids` as map(string)** — matches the networking module's AZ-keyed output directly. The module calls `values()` internally.
- **Feature flag convention** — `deploy_*` for resources (read replicas), `enable_*` for behaviors (enhanced monitoring). Matches networking and EKS modules.
- **No CloudWatch alarms** — Prometheus stack handles monitoring.
- **Deploy order** — `networking → compute → rds`. The EKS cluster security group is dynamically created by AWS, so compute must be applied before RDS to provide `cluster_security_group_id`.
