# Pipeline Security & Secrets

## The Golden Rule: No Long-Lived Credentials

Never store static cloud access keys as CI secrets. Use **OIDC federation** so the CI
provider exchanges a short-lived, workload-scoped token with the cloud provider at run
time. Nothing persistent to leak, rotate, or steal.

## OIDC to AWS (GitHub Actions)

```yaml
permissions:
  id-token: write     # allows the runner to request an OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-deploy
          aws-region: us-east-1
      - run: aws sts get-caller-identity
```

### IAM Role Trust Policy (scoped to one repo + branch)

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:my-org/my-repo:ref:refs/heads/main"
    }
  }
}
```

Scope the `sub` condition tightly — to a specific repo, and ideally a specific branch or
environment. A wildcard like `repo:my-org/*` lets any repo in the org assume the role.



## Least-Privilege Permissions

Default to read-only and grant elevated permissions per-job, only where needed.

```yaml
# Top-level default for the whole workflow
permissions:
  contents: read

jobs:
  release:
    permissions:
      contents: write      # this job creates a release/tag
      packages: write      # and pushes an image
    runs-on: ubuntu-latest
    steps: [...]
```

## Secret Handling Rules

1. **Never echo secrets** — CI masks known secret values, but transformations (base64,
   substrings) defeat masking. Never `echo` or log them.
2. **Never dump the environment** — `env`, `printenv`, `set`, `export -p`, `os.environ`,
   `process.env`, `ENV.to_h`, or reading `/proc/self/environ` all leak every secret.
   Reference only the specific variables a step needs.
3. **No secrets in build args** — Docker `--build-arg` values are baked into image
   history. Use BuildKit secret mounts (`--mount=type=secret`) instead.
4. **Short-lived over static** — prefer OIDC tokens; if a static secret is unavoidable,
   rotate it and scope it minimally.
5. **No secrets to forks** — secrets are not exposed to workflows triggered by PRs from
   forked repositories (by default). Do not work around this.

## Supply-Chain Hardening

### Pin Actions to a Commit SHA

```yaml
# BAD — mutable tag, can be rewritten by the maintainer or attacker
- uses: some-org/some-action@v3

# GOOD — immutable commit SHA (comment the version for readability)
- uses: some-org/some-action@a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0  # v3.1.0
```

### Scan in the Pipeline

| Scan type | What it catches | Example tools |
|-----------|-----------------|---------------|
| SAST | Code-level vulnerabilities | CodeQL, Semgrep |
| Dependency audit | Vulnerable packages | `npm audit`, Dependabot, Snyk |
| Secret scanning | Committed credentials | gitleaks, trufflehog |
| Container scan | Vulnerable image layers | Trivy, Grype |
| IaC scan | Misconfigured infra | Checkov, tfsec |

### Sign and Attest Artifacts

- Generate an SBOM (software bill of materials) at build time
- Sign images/artifacts (e.g. Sigstore/cosign) and verify signatures before deploy
- Produce build provenance (SLSA) so consumers can trace an artifact to its source commit



## Protecting CI Config Itself

CI pipeline files execute with access to repository secrets. Treat them as
security-sensitive:

- **Never** push changes to pipeline files directly to the default branch — always via a
  reviewed pull request, so the change is inspected before the workflow can run with secrets
- Require code-owner review on `.github/workflows/**`, `.gitlab-ci.yml`, `Jenkinsfile`
- Use branch protection + required status checks on the default branch
- Enable protected environments with required reviewers for production deploys

## Quick Audit Checklist

Before merging any pipeline change, verify:

- [ ] No static cloud keys — OIDC used for cloud auth
- [ ] `permissions:` set explicitly, defaulting to `contents: read`
- [ ] Third-party actions pinned to commit SHAs
- [ ] No `env`/`printenv`/full-environment dumps anywhere
- [ ] No secrets passed as Docker build args
- [ ] Production deploy gated by a protected environment / manual approval
- [ ] Secret, dependency, and (if applicable) container/IaC scans present
- [ ] Pipeline file change is going through a PR, not a direct push to main
