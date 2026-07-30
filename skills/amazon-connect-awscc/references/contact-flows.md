# Contact Flow Design Patterns

## Overview

Amazon Connect contact flows define the customer experience — the IVR menus, routing
decisions, integrations, and agent handoffs. Flows are stored as JSON and can be
managed as code via Terraform.

## Flow Types

| Type | Purpose | Use Case |
|------|---------|----------|
| `CONTACT_FLOW` | Main inbound flow | Primary IVR, routing logic |
| `CUSTOMER_QUEUE` | While customer waits | Hold music, position announcements |
| `CUSTOMER_HOLD` | Customer on hold | Hold music during transfers |
| `CUSTOMER_WHISPER` | Before agent connects | "This call may be recorded" |
| `AGENT_HOLD` | Agent side hold | Agent-side hold experience |
| `AGENT_WHISPER` | Before agent connects | Queue name announcement to agent |
| `AGENT_TRANSFER` | Agent-initiated transfer | Transfer logic |
| `OUTBOUND_WHISPER` | Outbound call connect | Outbound call setup |

## JSON Structure

### Basic Flow Skeleton

```json
{
  "Version": "2019-10-30",
  "StartAction": "action-id-1",
  "Actions": [
    {
      "Identifier": "action-id-1",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Welcome to our support line."
      },
      "Transitions": {
        "NextAction": "action-id-2",
        "Errors": [
          {
            "NextAction": "action-disconnect",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    }
  ]
}
```



### Common Action Types

| Action Type | Description |
|-------------|-------------|
| `MessageParticipant` | Play prompt or TTS message |
| `GetParticipantInput` | DTMF or Lex bot input |
| `TransferToQueue` | Route to a queue |
| `TransferToFlow` | Transfer to another flow |
| `InvokeLambdaFunction` | Call a Lambda function |
| `UpdateContactAttributes` | Set contact attributes |
| `CheckAttribute` | Branch on attribute value |
| `CheckHoursOfOperation` | Branch on hours |
| `CheckStaffing` | Branch on agent availability |
| `Loop` | Loop a section N times |
| `Wait` | Pause execution |
| `DisconnectParticipant` | End the contact |
| `TransferParticipantToThirdParty` | External transfer |
| `SetLoggingBehavior` | Enable/disable flow logging |

## Design Patterns

### Pattern 1: Hours Check with Fallback

Route contacts based on operating hours, with an after-hours message.

```json
{
  "Version": "2019-10-30",
  "StartAction": "check-hours",
  "Actions": [
    {
      "Identifier": "check-hours",
      "Type": "CheckHoursOfOperation",
      "Parameters": {
        "HoursOfOperationId": "${hours_of_operation_id}"
      },
      "Transitions": {
        "NextAction": "welcome-message",
        "Conditions": [
          {
            "NextAction": "after-hours-message",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["False"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "welcome-message",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "welcome-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you for calling. Please hold while we connect you."
      },
      "Transitions": {
        "NextAction": "transfer-to-queue"
      }
    },
    {
      "Identifier": "after-hours-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "We are currently closed. Our hours are Monday through Friday, 8 AM to 6 PM Eastern. Please call back during business hours."
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "transfer-to-queue",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          {
            "NextAction": "disconnect",
            "ErrorType": "QueueAtCapacity"
          },
          {
            "NextAction": "disconnect",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```



### Pattern 2: DTMF Menu (IVR)

Classic press-1-for-X menu with retry logic.

```json
{
  "Version": "2019-10-30",
  "StartAction": "welcome",
  "Actions": [
    {
      "Identifier": "welcome",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Welcome to Acme Support."
      },
      "Transitions": {
        "NextAction": "main-menu"
      }
    },
    {
      "Identifier": "main-menu",
      "Type": "GetParticipantInput",
      "Parameters": {
        "Text": "Press 1 for billing, press 2 for technical support, or press 3 to speak with an agent.",
        "InputTimeLimitSeconds": "5",
        "DTMFConfiguration": {
          "InputTerminationSequence": "#",
          "DisableInput": false
        }
      },
      "Transitions": {
        "NextAction": "invalid-input",
        "Conditions": [
          {
            "NextAction": "route-billing",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["1"]
            }
          },
          {
            "NextAction": "route-technical",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["2"]
            }
          },
          {
            "NextAction": "route-general",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["3"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "invalid-input",
            "ErrorType": "InputTimeLimitExceeded"
          },
          {
            "NextAction": "invalid-input",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "invalid-input",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Sorry, I didn't understand that. Let me repeat the options."
      },
      "Transitions": {
        "NextAction": "main-menu"
      }
    },
    {
      "Identifier": "route-billing",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${billing_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "disconnect", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "route-technical",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${technical_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "disconnect", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "route-general",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${general_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "disconnect", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```



### Pattern 3: Lambda Integration for Customer Lookup

Invoke a Lambda function to look up customer data before routing.

```json
{
  "Version": "2019-10-30",
  "StartAction": "set-logging",
  "Actions": [
    {
      "Identifier": "set-logging",
      "Type": "SetLoggingBehavior",
      "Parameters": {
        "LoggingBehavior": "Enable"
      },
      "Transitions": {
        "NextAction": "invoke-lookup"
      }
    },
    {
      "Identifier": "invoke-lookup",
      "Type": "InvokeLambdaFunction",
      "Parameters": {
        "LambdaFunctionARN": "${lambda_arn}",
        "InvocationTimeLimitSeconds": "8",
        "LambdaInvocationAttributes": {
          "callerNumber": "$.CustomerEndpoint.Address"
        }
      },
      "Transitions": {
        "NextAction": "check-customer-tier",
        "Errors": [
          {
            "NextAction": "route-default",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "check-customer-tier",
      "Type": "CheckAttribute",
      "Parameters": {
        "Attribute": "$.External.customerTier",
        "ComparisonType": "Equals"
      },
      "Transitions": {
        "NextAction": "route-default",
        "Conditions": [
          {
            "NextAction": "route-premium",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["premium"]
            }
          },
          {
            "NextAction": "route-enterprise",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["enterprise"]
            }
          }
        ]
      }
    },
    {
      "Identifier": "route-premium",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${premium_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "route-default", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "route-enterprise",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${enterprise_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "route-default", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "route-default",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${general_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "disconnect", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```



### Pattern 4: Lex Bot Integration

Use an Amazon Lex bot for natural language understanding.

```json
{
  "Version": "2019-10-30",
  "StartAction": "greeting",
  "Actions": [
    {
      "Identifier": "greeting",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Hello! How can I help you today?"
      },
      "Transitions": {
        "NextAction": "lex-bot"
      }
    },
    {
      "Identifier": "lex-bot",
      "Type": "GetParticipantInput",
      "Parameters": {
        "Text": "Please describe what you need help with.",
        "LexBot": {
          "Name": "${lex_bot_name}",
          "Region": "${aws_region}",
          "Alias": "${lex_bot_alias}"
        },
        "LexSessionAttributes": {
          "callerNumber": "$.CustomerEndpoint.Address"
        }
      },
      "Transitions": {
        "NextAction": "route-default",
        "Conditions": [
          {
            "NextAction": "handle-billing-intent",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["BillingInquiry"]
            }
          },
          {
            "NextAction": "handle-tech-intent",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["TechnicalSupport"]
            }
          },
          {
            "NextAction": "handle-account-intent",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["AccountManagement"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "route-default",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "handle-billing-intent",
      "Type": "UpdateContactAttributes",
      "Parameters": {
        "Attributes": {
          "intent": "billing"
        }
      },
      "Transitions": {
        "NextAction": "route-billing"
      }
    },
    {
      "Identifier": "handle-tech-intent",
      "Type": "UpdateContactAttributes",
      "Parameters": {
        "Attributes": {
          "intent": "technical"
        }
      },
      "Transitions": {
        "NextAction": "route-technical"
      }
    },
    {
      "Identifier": "handle-account-intent",
      "Type": "UpdateContactAttributes",
      "Parameters": {
        "Attributes": {
          "intent": "account"
        }
      },
      "Transitions": {
        "NextAction": "route-account"
      }
    }
  ]
}
```

### Pattern 5: Callback Queue

Offer customers a callback instead of waiting on hold.

```json
{
  "Version": "2019-10-30",
  "StartAction": "check-wait-time",
  "Actions": [
    {
      "Identifier": "check-wait-time",
      "Type": "CheckAttribute",
      "Parameters": {
        "Attribute": "$.Metrics.Queue.EstimatedWaitTime",
        "ComparisonType": "GreaterThan",
        "ComparisonValue": "300"
      },
      "Transitions": {
        "NextAction": "transfer-queue",
        "Conditions": [
          {
            "NextAction": "offer-callback",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["True"]
            }
          }
        ]
      }
    },
    {
      "Identifier": "offer-callback",
      "Type": "GetParticipantInput",
      "Parameters": {
        "Text": "Your estimated wait time is over 5 minutes. Press 1 to receive a callback, or press 2 to continue holding.",
        "InputTimeLimitSeconds": "5",
        "DTMFConfiguration": {
          "InputTerminationSequence": "#",
          "DisableInput": false
        }
      },
      "Transitions": {
        "NextAction": "transfer-queue",
        "Conditions": [
          {
            "NextAction": "create-callback",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["1"]
            }
          },
          {
            "NextAction": "transfer-queue",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["2"]
            }
          }
        ]
      }
    },
    {
      "Identifier": "create-callback",
      "Type": "CreateCallback",
      "Parameters": {
        "CallbackNumber": "$.CustomerEndpoint.Address",
        "QueueId": "${callback_queue_id}"
      },
      "Transitions": {
        "NextAction": "callback-confirm"
      }
    },
    {
      "Identifier": "callback-confirm",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you. We will call you back at your number as soon as an agent is available. Goodbye."
      },
      "Transitions": {
        "NextAction": "disconnect"
      }
    },
    {
      "Identifier": "transfer-queue",
      "Type": "TransferToQueue",
      "Parameters": {
        "QueueId": "${general_queue_id}"
      },
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          { "NextAction": "disconnect", "ErrorType": "QueueAtCapacity" }
        ]
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```



## Terraform Template Integration

### Using templatefile() for Dynamic Flows

Store flow JSON as `.json.tftpl` files and inject resource ARNs:

```hcl
# main.tf
resource "awscc_connect_contact_flow" "inbound" {
  instance_arn = aws_connect_instance.main.arn
  name         = "Main Inbound"
  type         = "CONTACT_FLOW"
  state        = "ACTIVE"

  content = templatefile("${path.module}/flows/inbound.json.tftpl", {
    hours_of_operation_id = local.hours_id
    general_queue_id      = awscc_connect_queue.general.queue_id
    billing_queue_id      = awscc_connect_queue.billing.queue_id
    technical_queue_id    = awscc_connect_queue.technical.queue_id
    lambda_arn            = aws_lambda_function.lookup.arn
    lex_bot_name          = aws_lexv2models_bot.support.name
    lex_bot_alias         = aws_lexv2models_bot_alias.live.name
    aws_region            = var.aws_region
  })
}
```

### Whisper Flow Templates

**Customer Whisper** — played to customer before agent connects:

```json
{
  "Version": "2019-10-30",
  "StartAction": "whisper-message",
  "Actions": [
    {
      "Identifier": "whisper-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "This call may be recorded for quality purposes. You are now being connected."
      },
      "Transitions": {
        "NextAction": "end-flow"
      }
    },
    {
      "Identifier": "end-flow",
      "Type": "EndFlowExecution",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```

**Agent Whisper** — played to agent before connecting:

```json
{
  "Version": "2019-10-30",
  "StartAction": "agent-whisper",
  "Actions": [
    {
      "Identifier": "agent-whisper",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Incoming call from the ${queue_name} queue."
      },
      "Transitions": {
        "NextAction": "end-flow"
      }
    },
    {
      "Identifier": "end-flow",
      "Type": "EndFlowExecution",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```

## Flow Best Practices

1. **Always include error transitions** — Every action should handle errors gracefully
2. **Set logging at the start** — Enable flow logging for debugging
3. **Check hours before queuing** — Avoid routing to unstaffed queues
4. **Check staffing after hours** — Even during hours, verify agents are available
5. **Limit Lambda timeout to 8s** — Connect enforces this; set it explicitly
6. **Use contact attributes** — Pass context between flows and to agents
7. **Keep flows modular** — Use `TransferToFlow` for reusable sub-flows
8. **Version flow JSON in git** — Track all changes to flow content
9. **Test in dev first** — Never deploy untested flows to production
10. **Use `SAVED` state for drafts** — Only set `ACTIVE` when ready for traffic

## Exporting Flows from Connect Console

To get the JSON for an existing flow:

```bash
# Using AWS CLI
aws connect describe-contact-flow \
  --instance-id <instance-id> \
  --contact-flow-id <flow-id> \
  --query 'ContactFlow.Content' \
  --output text | python3 -m json.tool > flow.json
```

Or export from the Connect admin UI:
1. Open the flow in the Flow Designer
2. Click the dropdown arrow next to "Save"
3. Select "Export flow (JSON)"
4. Save the file to your `contact-flows/` directory
