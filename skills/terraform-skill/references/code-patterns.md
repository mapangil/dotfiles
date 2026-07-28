# Modern Terraform/OpenTofu Code Patterns

## Dynamic Blocks

Use for repeating nested blocks:

```hcl
resource "aws_security_group" "main" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
}
```

## Conditional Resources

```hcl
# Create resource only when enabled
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name = "${var.name}-cpu-high"
  # ...
}

# Better: use for_each with conditional
resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = var.enable_monitoring ? { "cpu" = true } : {}

  alarm_name = "${var.name}-cpu-high"
  # ...
}
```

## Complex Variable Types

```hcl
variable "services" {
  description = "Map of services to deploy"
  type = map(object({
    image         = string
    cpu           = number
    memory        = number
    port          = number
    desired_count = optional(number, 2)
    environment   = optional(map(string), {})
    health_check  = optional(object({
      path     = string
      interval = optional(number, 30)
    }))
  }))
}
```

## Locals for Computed Values

```hcl
locals {
  # Merge default tags with user-provided tags
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    },
    var.additional_tags
  )

  # Computed values from other resources
  private_subnet_ids = [for s in aws_subnet.private : s.id]

  # Conditional logic
  is_production = var.environment == "production"
  instance_type = local.is_production ? "m5.large" : "t3.micro"
}
```

## Preconditions and Postconditions (>= 1.2)

```hcl
resource "aws_instance" "main" {
  instance_type = var.instance_type
  ami           = var.ami_id

  lifecycle {
    precondition {
      condition     = data.aws_ami.selected.architecture == "x86_64"
      error_message = "AMI must be x86_64 architecture."
    }

    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance must receive a public IP."
    }
  }
}
```

## Import Blocks (>= 1.5)

Declarative import without CLI:

```hcl
import {
  to = aws_s3_bucket.existing
  id = "my-existing-bucket-name"
}

resource "aws_s3_bucket" "existing" {
  bucket = "my-existing-bucket-name"

  tags = {
    ManagedBy = "terraform"
  }
}
```

## Check Blocks (>= 1.5)

Continuous validation (non-blocking assertions):

```hcl
check "health_check" {
  data "http" "api" {
    url = "https://${aws_lb.main.dns_name}/health"
  }

  assert {
    condition     = data.http.api.status_code == 200
    error_message = "API health check failed after deployment"
  }
}
```

## Provider Aliasing for Multi-Region

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu"
  region = "eu-west-1"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.eu
  bucket   = "${var.name}-replica-eu"
}
```

## Terraform Functions (>= 1.8)

User-defined functions:

```hcl
# functions/sanitize_name.tf
function "sanitize_name" {
  params = [name]
  result = lower(replace(name, "/[^a-z0-9-]/", "-"))
}

# Usage
resource "aws_s3_bucket" "main" {
  bucket = sanitize_name(var.project_name)
}
```

## Error Handling Patterns

```hcl
# Try/can for graceful fallbacks
locals {
  parsed_config = try(jsondecode(file("config.json")), {})
  region        = try(local.parsed_config.region, "us-east-1")
}

# Coalesce for first non-null value
locals {
  instance_type = coalesce(var.override_instance_type, var.default_instance_type)
}
```
