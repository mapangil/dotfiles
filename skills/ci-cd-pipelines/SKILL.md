---
name: ci-cd-pipelines
description: "General-purpose CI/CD pipeline guidance for building, testing, and deploying software across any language or stack. Use when creating or reviewing CI/CD workflows, GitHub Actions, GitLab CI, or other pipelines; setting up build/test/deploy stages, caching, matrix builds, artifact management, environment gates, or release automation; and securing pipelines with OIDC, secrets management, and least-privilege permissions. Covers deployment strategies (blue-green, canary, rolling) and pipeline debugging."
---

# CI/CD Pipelines Skill

## Overview

This skill provides production-grade guidance for continuous integration and continuous
delivery pipelines, independent of any single language or platform. It complements the
`terraform-skill` (which covers Terraform-specific pipelines) by focusing on general
application build/test/deploy workflows, pipeline security, and release strategies.

## Critical Safety Rules

1. **NEVER** dump the full environment in a pipeline (`env`, `printenv`, `set`, `process.env`, `os.environ`) — it leaks secrets into logs
2. **NEVER** push CI pipeline config directly to the default branch — always via a reviewed pull request
3. **NEVER** store long-lived cloud credentials as CI secrets — use OIDC federation instead
4. **NEVER** run untrusted PR code with access to secrets (`pull_request_target` misuse)
5. **ALWAYS** pin third-party actions/images to a commit SHA or immutable digest, not a mutable tag
6. **ALWAYS** scope pipeline permissions to least privilege (default read-only, grant per-job)
7. **ALWAYS** gate production deployments behind manual approval or protected environments



## Pipeline Architecture

A well-structured pipeline separates concerns into distinct, ordered stages. Fail fast:
put the cheapest, most likely-to-fail checks first.

### Standard Stage Order

```
1. Lint / Format      — style and syntax (seconds, fails fast)
2. Build / Compile    — produce artifacts
3. Unit Tests         — fast, isolated tests
4. Security Scan      — SAST, dependency audit, secret scan
5. Integration Tests  — slower, need services
6. Package            — build image / bundle, tag with commit SHA
7. Publish Artifact   — push to registry
8. Deploy (staging)   — automatic
9. Smoke / E2E Tests  — verify staging
10. Deploy (prod)     — gated by approval
```

### Design Principles

- **Fail fast** — cheap checks (lint, unit tests) run before expensive ones (E2E)
- **Parallelize independent work** — lint, unit tests, and security scans can run concurrently
- **Build once, promote the same artifact** — never rebuild between environments; tag by commit SHA and promote the identical artifact through stages
- **Idempotent and reproducible** — same input commit always produces the same result
- **Ephemeral runners** — every job starts from a clean state
- **Cache dependencies, not build outputs** — speed up installs without staleness risk

## Build-Once, Promote-Many

The single most important deployment principle: build an artifact **once**, then promote
that exact artifact through environments. Rebuilding per environment risks drift.

```
build → image:sha-abc123 → push to registry
                │
                ├─ deploy sha-abc123 to staging
                ├─ (tests pass)
                └─ deploy sha-abc123 to production   # SAME artifact
```

Never do `docker build` again for production — pull and deploy the tested image.



## Caching Strategy

Cache dependency downloads keyed on the lockfile hash. When the lockfile changes, the
key changes and the cache is rebuilt.

| Ecosystem | Cache path | Key input |
|-----------|-----------|-----------|
| Node / npm | `~/.npm` | `package-lock.json` |
| Node / pnpm | `~/.pnpm-store` | `pnpm-lock.yaml` |
| Python / pip | `~/.cache/pip` | `requirements.txt` / `poetry.lock` |
| Java / Maven | `~/.m2/repository` | `pom.xml` |
| Go | `~/go/pkg/mod` | `go.sum` |
| Rust / Cargo | `~/.cargo`, `target/` | `Cargo.lock` |
| Docker | layer cache | Dockerfile + context |

**Rule:** cache inputs (dependencies), not outputs (compiled artifacts). Stale build
outputs cause "works on my machine" bugs that are hard to trace.

## Matrix Builds

Test across multiple versions/platforms in parallel. Keep the matrix minimal — every
combination is a runner-minute cost.

```yaml
strategy:
  fail-fast: false        # let all combos finish to see every failure
  matrix:
    node: [18, 20, 22]
    os: [ubuntu-latest, macos-latest]
```

## Deployment Strategies

| Strategy | How it works | Best for |
|----------|-------------|----------|
| **Rolling** | Replace instances gradually | Stateless services, default choice |
| **Blue-Green** | Stand up full new env, switch traffic atomically | Zero-downtime, instant rollback |
| **Canary** | Route small % of traffic to new version, ramp up | Risk-averse, gradual validation |
| **Recreate** | Stop old, start new (downtime) | Dev environments, breaking migrations |

### Rollback Is a First-Class Feature

Every deploy must have a defined rollback path. With build-once-promote-many, rollback
is simply redeploying the previous known-good artifact SHA. Test your rollback, not just
your deploy.



## Pipeline Debugging

When a pipeline fails, diagnose systematically rather than blindly re-running:

### Common Failure Modes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Works locally, fails in CI" | Environment drift, uncommitted files, cache staleness | Reproduce in clean container; check `.gitignore`d files |
| Flaky/intermittent tests | Race conditions, shared state, timing | Isolate state per test; add retries only as last resort |
| Secret / auth errors | Missing scope, expired token, wrong OIDC trust | Verify permissions block and OIDC role trust policy |
| Slow pipeline | No caching, serial jobs, oversized matrix | Add dependency cache; parallelize; trim matrix |
| "Permission denied" on deploy | Over-restricted or misconfigured IAM/OIDC | Check least-privilege role has exactly the needed actions |
| Cache never hits | Key too dynamic (includes timestamp/SHA) | Key on lockfile hash only |

### Debugging Checklist

1. Read the **first** error, not the last — cascading failures mask the root cause
2. Re-run with debug logging enabled before changing code
3. Reproduce in a clean container locally (`docker run` the same base image)
4. Check whether it's deterministic (fails every time) or flaky (intermittent)
5. Bisect: does it fail on a minimal change? Revert to last green commit and re-apply

## Platform Quick Reference

- **GitHub Actions** — see `references/github-actions.md`
- **Security & secrets (OIDC, scanning, SHA pinning)** — see `references/security-and-secrets.md`

## References

For detailed guidance on specific topics, see:
- `references/github-actions.md` — GitHub Actions workflow patterns and reusable workflows
- `references/security-and-secrets.md` — Pipeline security, OIDC, secret management, supply-chain hardening
