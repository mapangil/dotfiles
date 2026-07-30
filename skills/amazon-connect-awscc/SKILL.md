---
name: amazon-connect-awscc
description: "Amazon Connect contact center infrastructure using the Terraform AWSCC (AWS Cloud Control) provider. Use when building, deploying, or managing Amazon Connect instances, contact flows, queues, routing profiles, hours of operation, quick connects, security profiles, user hierarchies, phone numbers, and integrations via Terraform. Covers both the AWSCC provider and the standard AWS provider for Connect resources, with best practices for IaC-driven contact center operations."
---

# Amazon Connect with Terraform AWSCC Skill

## Overview

This skill provides production-grade guidance for managing Amazon Connect contact center infrastructure using Terraform, with emphasis on the AWSCC (AWS Cloud Control) provider. The AWSCC provider is auto-generated from AWS CloudFormation schemas, providing faster access to new Connect features compared to the standard AWS provider.

## When to Use AWSCC vs AWS Provider

| Scenario | Provider | Reason |
|----------|----------|--------|
| New Connect features (days after launch) | `awscc` | Auto-generated from CloudFormation schemas |
| Mature, well-tested resources | `aws` | Better documentation, community support |
| Connect Contact Lens rules | `awscc` | Not yet in AWS provider |
| Connect instance creation | `aws` | More stable, better tested |
| Mixing both in one project | Both | Use `moved` blocks when migrating |

## Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}
```

## Critical Safety Rules

1. **NEVER** delete a Connect instance without confirming all phone numbers are released
2. **NEVER** modify contact flows in production without testing in a dev instance first
3. **ALWAYS** use `lifecycle { prevent_destroy = true }` on production instances
4. **ALWAYS** export contact flow content as JSON files, not inline HCL strings
5. **ALWAYS** version-pin the AWSCC provider — breaking changes happen between releases
6. **NEVER** hardcode instance IDs — use data sources or variables



## AWSCC Connect Resources

The AWSCC provider exposes Amazon Connect resources with the `awscc_connect_` prefix:

### Core Resources
- `awscc_connect_instance` — Connect instance
- `awscc_connect_instance_storage_config` — Storage configuration (S3, Kinesis)

### Routing & Queues
- `awscc_connect_queue` — Contact queues
- `awscc_connect_routing_profile` — Routing profiles
- `awscc_connect_hours_of_operation` — Hours of operation schedules

### Contact Flows
- `awscc_connect_contact_flow` — Contact flows (IVR logic)
- `awscc_connect_contact_flow_module` — Reusable flow modules

### Users & Security
- `awscc_connect_user` — Agent/admin users
- `awscc_connect_user_hierarchy_group` — Hierarchy groups
- `awscc_connect_user_hierarchy_structure` — Hierarchy structure
- `awscc_connect_security_profile` — Security profiles
- `awscc_connect_security_key` — Security keys

### Phone Numbers
- `awscc_connect_phone_number` — Phone number claims

### Quick Connects
- `awscc_connect_quick_connect` — Quick connect configurations

### Rules & Analytics
- `awscc_connect_rule` — Contact Lens rules
- `awscc_connect_evaluation_form` — Agent evaluation forms
- `awscc_connect_predefined_attribute` — Predefined attributes

### Integrations
- `awscc_connect_integration_association` — Lambda, Lex bot integrations
- `awscc_connect_task_template` — Task templates
- `awscc_connect_view` — Agent workspace views
- `awscc_connect_view_version` — View versions



## Module Structure

Follow this layout for an Amazon Connect Terraform project:

```
connect-infrastructure/
├── modules/
│   ├── instance/
│   │   ├── main.tf           # Instance + storage config
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── routing/
│   │   ├── main.tf           # Queues, routing profiles, hours
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── flows/
│   │   ├── main.tf           # Contact flow resources
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── flow-content/     # JSON flow definitions
│   │       ├── inbound.json
│   │       ├── transfer.json
│   │       └── callback.json
│   ├── users/
│   │   ├── main.tf           # Users, security profiles, hierarchy
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── integrations/
│       ├── main.tf           # Lambda, Lex, Kinesis integrations
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── production/
├── contact-flows/            # Source flow JSON exports
│   ├── README.md
│   └── *.json
└── tests/
    └── main.tftest.hcl
```



## Common Patterns

### Create a Connect Instance (AWS Provider)

```hcl
resource "aws_connect_instance" "main" {
  identity_management_type = "CONNECT_MANAGED"
  instance_alias           = var.instance_alias
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true

  lifecycle {
    prevent_destroy = true
  }
}

# Enable required instance features
resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.main.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = var.recordings_bucket_name
      bucket_prefix = "call-recordings"
    }
  }
}
```

### Hours of Operation (AWSCC)

```hcl
resource "awscc_connect_hours_of_operation" "business_hours" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Business Hours"
  description  = "Standard business hours Mon-Fri 8am-6pm"
  time_zone    = "US/Eastern"

  config = [
    for day in ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"] : {
      day = day
      start_time = {
        hours   = 8
        minutes = 0
      }
      end_time = {
        hours   = 18
        minutes = 0
      }
    }
  ]

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```

### Queue (AWSCC)

```hcl
resource "awscc_connect_queue" "general" {
  instance_arn            = aws_connect_instance.main.arn
  name                   = "General"
  description            = "General inquiry queue"
  hours_of_operation_arn = awscc_connect_hours_of_operation.business_hours.hours_of_operation_arn
  max_contacts           = 50

  outbound_caller_config = {
    outbound_caller_id_name      = var.caller_id_name
    outbound_caller_id_number_arn = var.outbound_number_arn
  }

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```



### Routing Profile (AWSCC)

```hcl
resource "awscc_connect_routing_profile" "default" {
  instance_arn                 = aws_connect_instance.main.arn
  name                        = "Default Routing"
  description                 = "Default routing profile for agents"
  default_outbound_queue_arn  = awscc_connect_queue.general.queue_arn

  media_concurrencies = [
    {
      channel     = "VOICE"
      concurrency = 1
    },
    {
      channel     = "CHAT"
      concurrency = 3
    },
    {
      channel     = "TASK"
      concurrency = 5
    }
  ]

  queue_configs = [
    {
      delay    = 0
      priority = 1
      queue_reference = {
        channel   = "VOICE"
        queue_arn = awscc_connect_queue.general.queue_arn
      }
    },
    {
      delay    = 0
      priority = 1
      queue_reference = {
        channel   = "CHAT"
        queue_arn = awscc_connect_queue.general.queue_arn
      }
    }
  ]

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```

### Contact Flow (AWSCC)

```hcl
resource "awscc_connect_contact_flow" "inbound" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Inbound Flow"
  description  = "Main inbound contact flow"
  type         = "CONTACT_FLOW"
  state        = "ACTIVE"

  # Load flow content from external JSON file
  content = file("${path.module}/flow-content/inbound.json")

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```

### Phone Number (AWSCC)

```hcl
resource "awscc_connect_phone_number" "toll_free" {
  target_arn   = aws_connect_instance.main.arn
  type         = "TOLL_FREE"
  country_code = "US"
  description  = "Main toll-free number"

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```



### Quick Connect (AWSCC)

```hcl
resource "awscc_connect_quick_connect" "agent_transfer" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Transfer to Supervisor"
  description  = "Quick connect for supervisor transfer"

  quick_connect_config = {
    quick_connect_type = "QUEUE"
    queue_config = {
      contact_flow_arn = awscc_connect_contact_flow.transfer.contact_flow_arn
      queue_arn        = awscc_connect_queue.escalation.queue_arn
    }
  }

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```

### Security Profile (AWSCC)

```hcl
resource "awscc_connect_security_profile" "agent" {
  instance_arn = aws_connect_instance.main.arn
  security_profile_name = "CustomAgent"
  description           = "Custom agent security profile"

  permissions = [
    "BasicAgentAccess",
    "OutboundCallAccess",
    "ContactLens:ViewPostContactSummary"
  ]

  allowed_access_control_tags = [
    {
      key   = "Department"
      value = "Support"
    }
  ]

  tags = [
    {
      key   = "Environment"
      value = var.environment
    }
  ]
}
```

## Contact Flow JSON Management

### Best Practices for Flow Content

1. **Export flows from the Connect UI** — Use the admin console to design flows visually, then export the JSON
2. **Store JSON files separately** — Keep flow content in dedicated files, not inline in HCL
3. **Use `templatefile()` for dynamic content** — Inject ARNs and environment-specific values

```hcl
resource "awscc_connect_contact_flow" "main" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Main IVR"
  type         = "CONTACT_FLOW"
  state        = "ACTIVE"

  content = templatefile("${path.module}/flows/main-ivr.json.tftpl", {
    queue_arn       = awscc_connect_queue.general.queue_arn
    lambda_arn      = aws_lambda_function.lookup.arn
    transfer_flow   = awscc_connect_contact_flow.transfer.contact_flow_arn
    hours_arn       = awscc_connect_hours_of_operation.business_hours.hours_of_operation_arn
  })
}
```

4. **Version control flow JSON** — Track changes to flow content in git
5. **Validate JSON before apply** — Use `jsonencode(jsondecode(...))` to catch syntax errors

```hcl
locals {
  # Validate flow JSON at plan time
  flow_content = jsondecode(file("${path.module}/flows/main-ivr.json"))
}
```



## Lambda Integration

### Associate Lambda with Connect Instance

```hcl
resource "awscc_connect_integration_association" "lambda" {
  instance_id      = aws_connect_instance.main.id
  integration_arn  = aws_lambda_function.connect_handler.arn
  integration_type = "LAMBDA_FUNCTION"
}

# Grant Connect permission to invoke Lambda
resource "aws_lambda_permission" "connect" {
  statement_id  = "AllowConnectInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connect_handler.function_name
  principal     = "connect.amazonaws.com"
  source_arn    = aws_connect_instance.main.arn
}
```

## Lex Bot Integration

```hcl
resource "awscc_connect_integration_association" "lex_bot" {
  instance_id      = aws_connect_instance.main.id
  integration_arn  = aws_lexv2models_bot.assistant.arn
  integration_type = "LEX_BOT"
}
```

## Data Sources

### Reference Existing Resources

```hcl
# Look up an existing Connect instance
data "aws_connect_instance" "existing" {
  instance_alias = "my-existing-instance"
}

# Look up an existing contact flow
data "aws_connect_contact_flow" "default_hold" {
  instance_id = data.aws_connect_instance.existing.id
  name        = "Default customer hold"
}
```

## Tagging Strategy

Use consistent tags across all Connect resources:

```hcl
locals {
  common_tags = [
    { key = "Environment", value = var.environment },
    { key = "Project", value = "contact-center" },
    { key = "ManagedBy", value = "terraform" },
    { key = "CostCenter", value = var.cost_center },
  ]
}
```

## Troubleshooting

### Common AWSCC Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Instance ARN wrong | Verify instance ARN format: `arn:aws:connect:region:account:instance/id` |
| `InvalidParameterException` | Tag format wrong | AWSCC uses `[{key, value}]` not `map(string)` |
| `ResourceConflictException` | Resource name exists | Connect names must be unique per instance |
| `LimitExceededException` | Too many resources | Check service quotas, request increase |
| Provider schema mismatch | Provider version old | Upgrade AWSCC provider to latest |

### AWSCC vs AWS Provider Tag Differences

```hcl
# AWS provider — uses map
tags = {
  Environment = "dev"
}

# AWSCC provider — uses list of objects
tags = [
  {
    key   = "Environment"
    value = "dev"
  }
]
```

## References

For detailed guidance on specific topics, see:
- `references/awscc-patterns.md` — Advanced AWSCC resource patterns and migrations
- `references/contact-flows.md` — Contact flow design patterns and JSON structure
