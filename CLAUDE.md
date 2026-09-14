## Project

Reusable Terraform module for deploying a production-ready RDS PostgreSQL instance with opinionated security and operational defaults.

## Prior art

- `terraform-aws-networking` — pattern reference for opinionated, feature-flagged modules
- `terraform-aws-eks` — same module pattern, wayfinder conventions

## Conventions

- Follow `terraform-aws-networking` module pattern: opinionated, feature-flagged, loose coupling via variables
- Standard Terraform file layout: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- Optional features gated by boolean variables (e.g. `enable_enhanced_monitoring`, `deploy_read_replicas`)

## Agent skills

### Issue tracker

GitHub Issues on this repo. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/`). See `docs/agents/domain.md`.
