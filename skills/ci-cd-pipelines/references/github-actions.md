# GitHub Actions Patterns

## Anatomy of a Workflow

```yaml
name: CI                      # workflow name shown in the UI
on:                           # triggers
  push:
    branches: [main]
  pull_request:

permissions:                  # least privilege — default read-only
  contents: read

concurrency:                  # cancel superseded runs on the same ref
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "hello"
```

## Fail-Fast Build + Test Pipeline

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        node: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: npm
      - run: npm ci
      - run: npm test
```



## Build-Once, Promote-Many with Environments

Build and push an image tagged by commit SHA, then promote the same image to staging
and (after approval) production.

```yaml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write        # required for OIDC
  packages: write        # push to GHCR

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.meta.outputs.image }}
    steps:
      - uses: actions/checkout@v4

      - id: meta
        run: echo "image=ghcr.io/${{ github.repository }}:${{ github.sha }}" >> "$GITHUB_OUTPUT"

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.image }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-staging:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: staging          # auto-deploy
    steps:
      - run: ./deploy.sh "${{ needs.build-and-push.outputs.image }}" staging

  deploy-production:
    needs: [build-and-push, deploy-staging]
    runs-on: ubuntu-latest
    environment: production       # protected: requires manual approval
    steps:
      - run: ./deploy.sh "${{ needs.build-and-push.outputs.image }}" production
```

The `environment: production` gate uses GitHub's protected-environment rules to require
a manual approval before the job runs. Note the SAME image SHA flows to both stages.



## Reusable Workflows (DRY across repos)

Define a workflow once and call it from many places.

```yaml
# .github/workflows/reusable-node-ci.yml
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: "20"
    secrets:
      NPM_TOKEN:
        required: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: npm
      - run: npm ci
      - run: npm run build --if-present
      - run: npm test
```

```yaml
# caller: .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  call-ci:
    uses: ./.github/workflows/reusable-node-ci.yml
    with:
      node-version: "22"
    secrets: inherit
```

## Composite Actions (DRY across steps)

Bundle repeated steps into a local action.

```yaml
# .github/actions/setup/action.yml
name: Setup
runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: 20
        cache: npm
    - run: npm ci
      shell: bash
```

## Key Gotchas

| Gotcha | Guidance |
|--------|----------|
| `pull_request_target` | Runs with write token + secrets in the base repo context — never check out and execute untrusted PR head code with it |
| Mutable action tags | `uses: some/action@v1` can change under you — pin to a commit SHA for third-party actions |
| Default `GITHUB_TOKEN` scope | Set `permissions:` explicitly; default to `contents: read` |
| Caching secrets | Never cache directories that may contain credentials or `.env` files |
| Job outputs | Use `>> "$GITHUB_OUTPUT"`; the old `::set-output` is removed |
| Concurrency waste | Add a `concurrency` group to cancel superseded runs |
