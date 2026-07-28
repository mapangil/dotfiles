---
name: terraform-skill
description: "Comprehensive Terraform and OpenTofu guidance for writing, reviewing, and debugging infrastructure code. Use when writing Terraform modules, running plan/apply, managing state, creating CI/CD pipelines, structuring projects, or debugging infrastructure issues. Diagnoses failure modes including identity churn, secrets exposure, blast radius, CI drift, and state corruption with version-aware guards."
---

# Terraform & OpenTofu Skill

## Overview

This skill provides production-grade guidance for Terraform and OpenTofu infrastructure code. It enforces best practices from terraform-best-practices.com and enterprise experience.

## Critical Safety Rules

1. **NEVER** run `terraform destroy` without first running `terraform plan -destroy` and showing every resource that will be deleted
2. **NEVER** use `-auto-approve` on destroy operations
3. **NEVER** commit `.tfstate` files or secrets to version control
4. **ALWAYS** use remote state with locking enabled
5. **ALWAYS** pin provider and module versions
6. **ALWAYS** run `terraform fmt` and `terraform validate` before committing

## Failure Mode Diagnosis

When debugging Terraform issues, identify which failure mode applies:

### 1. Identity Churn
Resources being destroyed and recreated unnecessarily.
- Check for changes to `name`, `name_prefix`, or other identity-forming attributes
- Verify `lifecycle { create_before_destroy }` is set where needed
- Use `moved` blocks for refactoring instead of destroy/recreate

### 2. Secret Exposure
Sensitive data leaking into state, logs, or outputs.
- Mark variables as `sensitive = true`
- Use `sensitive` function in locals where needed
- Never use `terraform output` without `-json` in CI pipelines
- Store secrets in Vault, AWS Secrets Manager, or similar — reference them, don't inline them

### 3. Blast Radius
Changes affecting too many resources at once.
- Break large configurations into smaller state files
- Use targeted applies during refactoring: `terraform apply -target=module.x`
- Review `terraform plan` output carefully — look for unexpected destroys

### 4. CI Drift
State diverging from actual infrastructure.
- Run `terraform plan` on schedule (detect drift)
- Use state locking (DynamoDB for AWS, GCS for GCP)
- Never allow manual changes to managed resources
- Import existing resources rather than recreating: `terraform import`

### 5. State Corruption
State file issues blocking operations.
- Always back up state before operations: `terraform state pull > backup.tfstate`
- Use `terraform state rm` + `terraform import` for recovery
- Never edit state files manually

## Module Structure

Follow this standard layout for modules:

```
modules/
└── my-module/
    ├── main.tf          # Primary resources
    ├── variables.tf     # Input variables
    ├── outputs.tf       # Output values
    ├── versions.tf      # Required providers & terraform version
    ├── locals.tf        # Local values (computed)
    ├── data.tf          # Data sources
    ├── README.md        # Module documentation
    └── tests/
        └── main.tftest.hcl   # Native Terraform tests
```

## Style Guide

### Naming Conventions
- Resources: `snake_case` (e.g., `aws_instance.web_server`)
- Variables: `snake_case`, descriptive (e.g., `instance_type`, `enable_monitoring`)
- Outputs: `snake_case`, prefixed with resource context (e.g., `vpc_id`, `subnet_ids`)
- Modules: `kebab-case` for directories (e.g., `modules/vpc-network/`)
- Files: `snake_case.tf`

### Resource Organization in main.tf
```hcl
# 1. Terraform & provider configuration (versions.tf)
# 2. Data sources (data.tf)
# 3. Local values (locals.tf)
# 4. Resources (main.tf) - ordered by dependency
# 5. Outputs (outputs.tf)
```

### Prefer `for_each` over `count`
```hcl
# GOOD - stable identity, safe to modify
resource "aws_subnet" "private" {
  for_each = toset(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.value))
}

# BAD - index-based, reorders cause recreation
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zones[count.index]
}
```

### Variable Definitions
```hcl
variable "instance_type" {
  description = "EC2 instance type for the web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Instance type must be from the t3 family."
  }
}
```

### Version Pinning
```hcl
terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## Testing Strategy

### Native Terraform Tests (preferred for >= 1.6)
```hcl
# tests/main.tftest.hcl
run "creates_vpc" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block is incorrect"
  }
}

run "applies_successfully" {
  command = apply

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC was not created"
  }
}
```

### Validation commands
```bash
# Format check
terraform fmt -check -recursive

# Validate configuration
terraform validate

# Run native tests
terraform test

# Security scanning
tfsec .
checkov -d .
```

## CI/CD Patterns

### Standard Pipeline Stages
1. `terraform fmt -check` — Style enforcement
2. `terraform init` — Initialize providers
3. `terraform validate` — Syntax and logic validation
4. `tfsec` / `checkov` — Security scanning
5. `terraform plan -out=tfplan` — Generate execution plan
6. Manual approval gate
7. `terraform apply tfplan` — Apply approved plan

### Key CI/CD Rules
- Always save plan output to a file (`-out=tfplan`)
- Apply from the saved plan file, never re-plan during apply
- Use separate state files per environment
- Implement drift detection on schedule
- Use OIDC for cloud authentication (no long-lived credentials)

## Production Patterns

### Remote State Configuration (AWS)
```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "env/production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Workspace Structure (recommended)
```
infrastructure/
├── modules/               # Reusable modules
│   ├── vpc/
│   ├── ecs-cluster/
│   └── rds/
├── environments/          # Environment-specific configs
│   ├── dev/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── production/
└── global/                # Shared resources (IAM, DNS)
    └── main.tf
```

## References

For detailed guidance on specific topics, see:
- `references/module-patterns.md` — Advanced module development
- `references/ci-cd-workflows.md` — CI/CD pipeline templates
- `references/testing-frameworks.md` — Testing strategies in depth
- `references/code-patterns.md` — Modern HCL patterns and features
