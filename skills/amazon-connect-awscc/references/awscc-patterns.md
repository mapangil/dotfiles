# Advanced AWSCC Patterns for Amazon Connect

## Using AWS and AWSCC Providers Together

The AWSCC provider complements the standard AWS provider. Use both in the same project
for maximum coverage and stability.

### Provider Aliasing

```hcl
terraform {
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

# Use AWS provider for the instance (more stable)
resource "aws_connect_instance" "main" {
  identity_management_type = "CONNECT_MANAGED"
  instance_alias           = var.instance_alias
  inbound_calls_enabled    = true
  outbound_calls_enabled   = true
}

# Use AWSCC for newer resources not yet in AWS provider
resource "awscc_connect_rule" "sentiment" {
  instance_arn = aws_connect_instance.main.arn
  name         = "NegativeSentimentAlert"
  # ...
}
```



## Migrating Between Providers

When a resource matures in the AWS provider, you may want to migrate from AWSCC:

```hcl
# Step 1: Add moved block
moved {
  from = awscc_connect_queue.general
  to   = aws_connect_queue.general
}

# Step 2: Define the resource with the new provider
resource "aws_connect_queue" "general" {
  instance_id            = aws_connect_instance.main.id
  name                   = "General"
  description            = "General inquiry queue"
  hours_of_operation_id  = aws_connect_hours_of_operation.business_hours.hours_of_operation_id
  max_contacts           = 50
}
```

> **Note:** Not all attributes map 1:1 between providers. Always run `terraform plan`
> after migration and verify no unexpected changes.

## User Hierarchy Management

### Define Complete Hierarchy Structure

```hcl
resource "awscc_connect_user_hierarchy_structure" "main" {
  instance_arn = aws_connect_instance.main.arn

  user_hierarchy_structure = {
    level_one = {
      name = "Division"
    }
    level_two = {
      name = "Department"
    }
    level_three = {
      name = "Team"
    }
  }
}

# Create hierarchy groups at each level
resource "awscc_connect_user_hierarchy_group" "support_division" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Customer Support"

  tags = local.common_tags
}

resource "awscc_connect_user_hierarchy_group" "technical" {
  instance_arn    = aws_connect_instance.main.arn
  name            = "Technical Support"
  parent_group_arn = awscc_connect_user_hierarchy_group.support_division.user_hierarchy_group_arn

  tags = local.common_tags
}
```



## User Management with AWSCC

```hcl
resource "awscc_connect_user" "agent" {
  for_each = var.agents

  instance_arn         = aws_connect_instance.main.arn
  username             = each.value.username
  routing_profile_arn  = awscc_connect_routing_profile.default.routing_profile_arn
  security_profile_arns = [
    awscc_connect_security_profile.agent.security_profile_arn
  ]
  hierarchy_group_arn  = each.value.hierarchy_group_arn

  identity_info = {
    first_name = each.value.first_name
    last_name  = each.value.last_name
    email      = each.value.email
  }

  phone_config = {
    phone_type                    = each.value.phone_type  # "SOFT_PHONE" or "DESK_PHONE"
    auto_accept                   = false
    after_contact_work_time_limit = 30
  }

  tags = local.common_tags
}
```

### Variable Definition for Agents

```hcl
variable "agents" {
  description = "Map of agent configurations"
  type = map(object({
    username          = string
    first_name        = string
    last_name         = string
    email             = string
    phone_type        = string
    hierarchy_group_arn = string
  }))
  default = {}
}
```

## Contact Lens Rules (AWSCC-only)

Contact Lens rules are only available via the AWSCC provider:

```hcl
resource "awscc_connect_rule" "negative_sentiment" {
  instance_arn = aws_connect_instance.main.arn
  name         = "NegativeSentimentEscalation"
  publish_status = "PUBLISH"

  trigger_event_source = {
    event_source_name = "OnPostCallAnalysisAvailable"
  }

  function = "AssignContactCategory"

  actions = {
    assign_contact_category_actions = [{}]
    send_notification_actions = [
      {
        delivery_method = "EMAIL"
        content         = "Negative sentiment detected on call {ContactId}"
        content_type    = "PLAIN_TEXT"
        subject         = "Alert: Negative Customer Sentiment"
        recipient = {
          user_arns = [awscc_connect_user.supervisor.user_arn]
        }
      }
    ]
  }

  tags = local.common_tags
}
```



## Evaluation Forms (AWSCC-only)

```hcl
resource "awscc_connect_evaluation_form" "quality" {
  instance_arn = aws_connect_instance.main.arn
  title        = "Quality Assurance Evaluation"
  description  = "Standard QA evaluation form for voice interactions"
  status       = "ACTIVE"

  scoring_strategy = {
    mode   = "QUESTION_ONLY"
    status = "ENABLED"
  }

  items = [
    {
      section = {
        title = "Greeting & Opening"
        items = [
          {
            question = {
              title         = "Agent greeted customer professionally"
              not_applicable_enabled = true
              question_type = "SINGLESELECT"
              single_select_question = {
                options = [
                  { text = "Yes", score = 10, auto_select = false },
                  { text = "No", score = 0, auto_select = false },
                ]
              }
            }
          }
        ]
      }
    }
  ]

  tags = local.common_tags
}
```

## Task Templates (AWSCC-only)

```hcl
resource "awscc_connect_task_template" "follow_up" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Customer Follow-Up"
  description  = "Template for customer follow-up tasks"
  status       = "ACTIVE"

  fields = [
    {
      id = {
        name = "CustomerName"
      }
      type        = "NAME"
      description = "Customer full name"
      single_select_options = []
    },
    {
      id = {
        name = "Reason"
      }
      type        = "TEXT"
      description = "Reason for follow-up"
      single_select_options = []
    },
    {
      id = {
        name = "Priority"
      }
      type        = "SINGLE_SELECT"
      description = "Follow-up priority"
      single_select_options = ["High", "Medium", "Low"]
    }
  ]

  defaults = [
    {
      id = {
        name = "Priority"
      }
      default_value = "Medium"
    }
  ]

  tags = local.common_tags
}
```

## Agent Views (AWSCC-only)

```hcl
resource "awscc_connect_view" "customer_info" {
  instance_arn = aws_connect_instance.main.arn
  name         = "CustomerInfoView"
  description  = "Agent workspace view showing customer details"

  template = jsonencode({
    Version = "2022-11-28"
    Sections = {
      CustomerDetails = {
        Type = "Section"
        Items = [
          { Type = "Field", Label = "Name", Binding = "$.Customer.Name" },
          { Type = "Field", Label = "Account", Binding = "$.Customer.AccountId" },
        ]
      }
    }
  })

  tags = local.common_tags
}

resource "awscc_connect_view_version" "v1" {
  view_arn             = awscc_connect_view.customer_info.view_arn
  version_description  = "Initial release"
}
```



## Dynamic Queue Creation with for_each

```hcl
variable "queues" {
  description = "Map of queues to create"
  type = map(object({
    description  = string
    max_contacts = number
    priority     = number
  }))
  default = {
    general = {
      description  = "General inquiries"
      max_contacts = 50
      priority     = 5
    }
    billing = {
      description  = "Billing support"
      max_contacts = 30
      priority     = 3
    }
    technical = {
      description  = "Technical support"
      max_contacts = 40
      priority     = 2
    }
    escalation = {
      description  = "Escalation queue"
      max_contacts = 10
      priority     = 1
    }
  }
}

resource "awscc_connect_queue" "queues" {
  for_each = var.queues

  instance_arn            = aws_connect_instance.main.arn
  name                    = title(replace(each.key, "_", " "))
  description             = each.value.description
  hours_of_operation_arn  = awscc_connect_hours_of_operation.business_hours.hours_of_operation_arn
  max_contacts            = each.value.max_contacts

  tags = concat(local.common_tags, [
    { key = "Queue", value = each.key }
  ])
}
```

## Multi-Environment Pattern

### Using Workspaces or Variable Files

```hcl
# environments/dev/terraform.tfvars
instance_alias   = "mycompany-dev"
environment      = "dev"
aws_region       = "us-east-1"
enable_recording = false
agents = {}

# environments/production/terraform.tfvars
instance_alias   = "mycompany-prod"
environment      = "production"
aws_region       = "us-east-1"
enable_recording = true
agents = {
  jdoe = {
    username   = "jdoe"
    first_name = "Jane"
    last_name  = "Doe"
    email      = "jdoe@company.com"
    phone_type = "SOFT_PHONE"
    hierarchy_group_arn = "arn:aws:connect:us-east-1:123456789:instance/xxx/agent-group/yyy"
  }
}
```

## Import Existing Resources

When adopting Terraform for an existing Connect instance:

```bash
# Import existing instance (AWS provider)
terraform import aws_connect_instance.main <instance-id>

# Import existing queue (AWSCC provider)
terraform import awscc_connect_queue.general <queue-arn>

# Import existing contact flow (AWSCC provider)
terraform import awscc_connect_contact_flow.main <contact-flow-arn>

# Import existing hours of operation
terraform import awscc_connect_hours_of_operation.business <hours-arn>
```

### Post-Import Checklist

1. Run `terraform plan` to see drift between state and config
2. Update your HCL to match the imported resource exactly
3. Iterate until `terraform plan` shows no changes
4. Add `lifecycle { prevent_destroy = true }` for critical resources
5. Commit the aligned configuration

## State Management Best Practices

```hcl
# Separate state per environment
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "connect/${var.environment}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### State Isolation Strategy

- **One state per Connect instance** — Prevents blast radius across environments
- **Separate state for integrations** — Lambda/Lex can be managed independently
- **Global state for shared resources** — IAM roles, KMS keys shared across instances
