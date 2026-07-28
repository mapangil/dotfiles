# Testing Frameworks for Terraform

## Testing Pyramid

```
        /  E2E Tests  \         # Real infrastructure (expensive, slow)
       / Integration    \       # terraform test with apply (moderate)
      /   Plan Tests     \      # terraform test with plan (fast, cheap)
     /  Static Analysis   \     # fmt, validate, tfsec, checkov (instant)
    /________________________\
```

## Native Terraform Tests (>= 1.6)

### Plan-Only Test (fast, no cloud resources)

```hcl
# tests/unit.tftest.hcl

variables {
  name          = "test"
  instance_type = "t3.micro"
  environment   = "dev"
}

run "validates_naming" {
  command = plan

  assert {
    condition     = aws_instance.main.tags["Name"] == "test-web-server"
    error_message = "Instance name tag does not follow naming convention"
  }
}

run "validates_instance_type" {
  command = plan

  assert {
    condition     = aws_instance.main.instance_type == "t3.micro"
    error_message = "Instance type should match variable"
  }
}

run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "invalid"
  }

  expect_failures = [
    var.environment
  ]
}
```

### Integration Test (creates real resources)

```hcl
# tests/integration.tftest.hcl

variables {
  name        = "tftest-integration"
  environment = "test"
}

run "creates_vpc" {
  command = apply

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC was not created"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled"
  }
}

run "creates_subnets_in_vpc" {
  command = apply

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets"
  }
}
```

### Using Mocks (>= 1.7)

```hcl
# tests/with_mocks.tftest.hcl

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

run "handles_availability_zones" {
  command = plan

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Should create one subnet per AZ"
  }
}
```

## Running Tests

```bash
# Run all tests
terraform test

# Run specific test file
terraform test -filter=tests/unit.tftest.hcl

# Verbose output
terraform test -verbose

# With specific variable file
terraform test -var-file=testing.tfvars
```

## Static Analysis Tools

### tfsec
```bash
# Scan current directory
tfsec .

# With specific severity threshold
tfsec . --minimum-severity HIGH

# Output as SARIF for CI integration
tfsec . --format sarif > results.sarif
```

### checkov
```bash
# Scan directory
checkov -d .

# Skip specific checks
checkov -d . --skip-check CKV_AWS_79,CKV_AWS_88

# Output JUnit for CI
checkov -d . -o junitxml > results.xml
```

### terraform-docs
```bash
# Generate README for a module
terraform-docs markdown table . > README.md

# Validate docs are up to date (CI check)
terraform-docs markdown table . --output-check
```

## Best Practices

1. **Start with plan tests** — Fast, free, catch most issues
2. **Use mocks** — Avoid cloud costs for unit-level testing
3. **Integration tests in ephemeral environments** — Never test in production state
4. **Clean up** — terraform test auto-destroys, but verify
5. **Test validation rules** — Use `expect_failures` for negative tests
6. **Run static analysis in CI** — Block PRs with security issues
