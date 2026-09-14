output "endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "reader_endpoint" {
  description = "Read replica endpoint (empty if replicas not deployed)"
  value       = var.deploy_read_replica ? aws_db_instance.replica[0].endpoint : ""
}

output "port" {
  description = "Database port"
  value       = 5432
}

output "master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.this.id
}

output "internal_dns_name" {
  description = "Internal DNS name for the RDS instance"
  value       = aws_route53_record.this.fqdn
}
