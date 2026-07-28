# CI/CD Workflows for Terraform

## GitHub Actions — Standard Pipeline

```yaml
name: Terraform
on:
  pull_request:
    paths: ['infrastructure/**']
  push:
    branches: [main]
    paths: ['infrastructure/**']

permissions:
  id-token: write   # OIDC
  contents: read
  pull-requests: write

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.9.x"

      - name: Format Check
        run: terraform fmt -check -recursive

      - name: Init
        run: terraform init -backend=false

      - name: Validate
        run: terraform validate

  security-scan:
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - uses: actions/checkout@v4

      - name: tfsec
        uses: aquasecurity/tfsec-action@v1.0.3

      - name: checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infrastructure/

  plan:
    runs-on: ubuntu-latest
    needs: [validate, security-scan]
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Terraform Plan
        run: |
          terraform init
          terraform plan -out=tfplan -no-color 2>&1 | tee plan-output.txt

      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('plan-output.txt', 'utf8');
            const body = `## Terraform Plan\n\`\`\`\n${plan.slice(-60000)}\n\`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });

  apply:
    runs-on: ubuntu-latest
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Apply
        run: |
          terraform init
          terraform apply -auto-approve
```

## Drift Detection (Scheduled)

```yaml
name: Drift Detection
on:
  schedule:
    - cron: '0 8 * * 1-5'  # Weekdays at 8am UTC

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3

      - name: Check for Drift
        run: |
          terraform init
          terraform plan -detailed-exitcode -no-color 2>&1 | tee drift.txt
        continue-on-error: true

      - name: Alert on Drift
        if: steps.plan.outcome == 'failure'
        run: |
          echo "::warning::Infrastructure drift detected!"
          # Send notification (Slack, email, etc.)
```

## Key Principles

1. **Plan and apply are separate** — Never re-plan during apply
2. **Use OIDC** — No long-lived credentials in CI
3. **Gate with environments** — Require approval for production
4. **Post plans to PRs** — Reviewers must see infrastructure changes
5. **Detect drift** — Scheduled plans catch manual changes
6. **Separate state per environment** — Reduce blast radius
