# Module Development Patterns

## Principles

1. **Single Responsibility** — Each module does one thing well
2. **Composability** — Modules can be combined without conflicts
3. **Encapsulation** — Internal complexity hidden behind clean interfaces
4. **Versioning** — Semantic versioning for all shared modules

## Module Interface Design

### Input Variables

Keep the interface minimal but flexible:

```hcl
# Required variables (no default)
variable "name" {
  description = "Name prefix for all resources in this module"
  type        = string

  validation {
    condition     = length(var.name) <= 24
    error_message = "Name must be 24 characters or fewer."
  }
}

# Optional variables (with sensible defaults)
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Feature flags
variable "enable_monitoring" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}
```

### Output Values

Expose what consumers need, nothing more:

```hcl
output "id" {
  description = "The ID of the created resource"
  value       = aws_instance.main.id
}

output "arn" {
  description = "The ARN of the created resource"
  value       = aws_instance.main.arn
}

# Group related outputs
output "connection" {
  description = "Connection details for the database"
  value = {
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    database = aws_db_instance.main.db_name
  }
}
```

## Composition Patterns

### Root Module Calling Child Modules

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name       = "production"
  cidr_block = "10.0.0.0/16"
  azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "ecs" {
  source = "../../modules/ecs-cluster"

  name       = "production"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  depends_on = [module.vpc]
}
```

### Using `moved` Blocks for Refactoring

When renaming or restructuring without destroying resources:

```hcl
# Rename a resource
moved {
  from = aws_instance.web
  to   = aws_instance.web_server
}

# Move into a module
moved {
  from = aws_security_group.main
  to   = module.security.aws_security_group.main
}
```

## Anti-Patterns to Avoid

1. **God modules** — Modules with 50+ variables that do everything
2. **Deep nesting** — Module calling module calling module (max 2 levels)
3. **Hardcoded values** — Anything environment-specific in module code
4. **Missing descriptions** — Every variable and output needs a description
5. **Circular dependencies** — Modules referencing each other
