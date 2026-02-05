# GitHub Architecture Map

> Recommended GitHub repository structure, branch protection, permissions, security rules,
> team structure, and release workflow for crypto protocol projects.

---

## Table of Contents

1. [Repository Structure](#repository-structure)
2. [Branch Protection Rules](#branch-protection-rules)
3. [Token Permissions](#token-permissions)
4. [Security Rules](#security-rules)
5. [Team Structure & CODEOWNERS](#team-structure--codeowners)
6. [Release Workflow](#release-workflow)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Issue and PR Templates](#issue-and-pr-templates)
9. [Dependabot Configuration](#dependabot-configuration)

---

## Repository Structure

### Recommended Multi-Repo Architecture

```
organization/
+-- protocol-contracts/       # Smart contracts (Solidity/Rust)
+-- protocol-frontend/        # Web application
+-- protocol-backend/         # API, indexer, keeper bots
+-- protocol-sdk/             # JavaScript/TypeScript SDK
+-- protocol-docs/            # Documentation site
+-- protocol-subgraph/        # The Graph subgraph
+-- protocol-security/        # Security reports, audit management (PRIVATE)
+-- protocol-ops/             # Infrastructure, deployment configs (PRIVATE)
+-- protocol-governance/      # Governance proposals, voting
```

### Contract Repository Structure

```
protocol-contracts/
+-- .github/
|   +-- workflows/
|   |   +-- test.yml                   # Lint, compile, test on every PR
|   |   +-- security.yml              # Slither, Mythril on every PR
|   |   +-- invariant-tests.yml       # Foundry invariant tests (nightly)
|   |   +-- deploy-testnet.yml        # Testnet deployment
|   |   +-- deploy-mainnet.yml        # Mainnet deployment (manual trigger)
|   +-- PULL_REQUEST_TEMPLATE.md
|   +-- ISSUE_TEMPLATE/
|       +-- bug_report.yml
|       +-- feature_request.yml
|       +-- security_vulnerability.yml
+-- contracts/
|   +-- BackedToken.sol               # ERC-20 token contract
|   +-- SecureMintPolicy.sol          # Oracle-gated minting
|   +-- EmergencyPause.sol            # Circuit breaker
|   +-- TreasuryVault.sol             # Multi-tier reserve custody
|   +-- ChainlinkPoRAdapter.sol       # Chainlink PoR integration
|   +-- OracleRouter.sol              # Multi-oracle fallback
|   +-- Governor.sol                  # DAO governance contract
|   +-- Timelock.sol                  # Governance timelock
|   +-- RedemptionEngine.sol          # Burn-to-redeem mechanism
|   +-- GuardianMultisig.sol          # Guardian authority management
|   +-- IBackingOracle.sol            # Oracle interface
|   +-- IBackedToken.sol              # Token interface
|   +-- ISecureMintPolicy.sol         # Policy interface
|   +-- ITreasuryVault.sol            # Treasury interface
|   +-- IEmergencyPause.sol           # Pause interface
+-- test/
|   +-- unit/
|   |   +-- BackedToken.t.sol
|   |   +-- SecureMintPolicy.t.sol
|   |   +-- OracleRouter.t.sol
|   +-- integration/
|   |   +-- MintFlow.t.sol
|   |   +-- OracleFailover.t.sol
|   +-- invariant/
|   |   +-- InvariantTest.t.sol
|   |   +-- Handler.sol
|   +-- fork/
|       +-- MainnetFork.t.sol
+-- script/
|   +-- Deploy.s.sol
|   +-- ConfigureOracles.s.sol
|   +-- VerifyDeployment.s.sol
+-- audits/
|   +-- 2026-01-audit-firm-1/
|   +-- 2026-03-audit-firm-2/
+-- docs/
|   +-- ARCHITECTURE.md
|   +-- DEPLOYMENT.md
|   +-- SECURITY.md
+-- foundry.toml
+-- remappings.txt
+-- .solhint.json
+-- .slither.config.json
+-- SECURITY.md
+-- LICENSE
```

### Solana Program Repository Structure

```
protocol-solana/
+-- .github/
|   +-- workflows/
|   |   +-- ci.yml
|   |   +-- security.yml
|   |   +-- deploy-devnet.yml
|   |   +-- deploy-mainnet.yml
+-- programs/
|   +-- token_mint/
|   |   +-- src/
|   |   |   +-- lib.rs
|   |   |   +-- instructions/
|   |   |   +-- state/
|   |   |   +-- error.rs
|   |   +-- Cargo.toml
|   +-- burn_controller/
|   +-- treasury_vault/
|   +-- governance_multisig/
|   +-- emergency_pause/
+-- tests/
|   +-- token_mint.ts
|   +-- burn_controller.ts
|   +-- treasury_vault.ts
|   +-- integration.ts
+-- scripts/
|   +-- 00-env-check.ts
|   +-- 01-create-mint.ts
|   +-- ...
+-- app/                        # Optional: Frontend
+-- Anchor.toml
+-- Cargo.toml
+-- package.json
+-- tsconfig.json
```

---

## Branch Protection Rules

### `main` Branch

```json
{
  "branch": "main",
  "protection": {
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "ci / compile",
        "ci / test",
        "ci / lint",
        "security / slither",
        "security / mythril"
      ]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "required_approving_review_count": 2,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "require_last_push_approval": true
    },
    "restrictions": {
      "users": [],
      "teams": ["protocol-core"],
      "apps": ["github-actions"]
    },
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "required_conversation_resolution": true,
    "required_signatures": true,
    "lock_branch": false
  }
}
```

### `develop` Branch

```json
{
  "branch": "develop",
  "protection": {
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "ci / compile",
        "ci / test"
      ]
    },
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": false
    },
    "allow_force_pushes": false,
    "allow_deletions": false
  }
}
```

### Release Branches (`release/*`)

```json
{
  "branch": "release/*",
  "protection": {
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "ci / compile",
        "ci / test",
        "ci / lint",
        "security / slither",
        "security / mythril",
        "security / invariant-tests"
      ]
    },
    "required_pull_request_reviews": {
      "required_approving_review_count": 2,
      "require_code_owner_reviews": true
    },
    "allow_force_pushes": false
  }
}
```

---

## Token Permissions

### GitHub App / Fine-Grained Token Permissions

| Permission | Level | Rationale |
|-----------|-------|-----------|
| **Contents** | Read & Write | Push commits, manage branches |
| **Pull Requests** | Read & Write | Create/merge PRs, add reviewers |
| **Actions** | Read & Write | Trigger and manage workflows |
| **Webhooks** | Read & Write | Configure deployment notifications |
| **Issues** | Read & Write | Create issues from security findings |
| **Deployments** | Read & Write | Track deployment status |
| **Environments** | Read | Access environment secrets |
| **Packages** | Read | Pull private packages |
| **Security Events** | Read | Dependabot alerts |
| **Secrets** | None (admin only) | Secrets managed via UI only |

### Repository Secrets

| Secret | Used By | Rotation |
|--------|---------|----------|
| `DEPLOYER_PRIVATE_KEY` | Deploy workflows | Per-deployment (ephemeral) |
| `ETHERSCAN_API_KEY` | Contract verification | Annually |
| `RPC_URL_MAINNET` | Fork tests, deployment | As needed |
| `RPC_URL_TESTNET` | Testnet deployment | As needed |
| `SLITHER_SARIF_TOKEN` | Security uploads | Annually |
| `CODECOV_TOKEN` | Coverage reporting | Annually |
| `WEBHOOK_SECRET` | Deployment notifications | Quarterly |

### Environment Protections

```yaml
environments:
  testnet:
    protection_rules:
      - type: required_reviewers
        reviewers: []  # No approval needed
      - type: wait_timer
        wait_timer: 0
    deployment_branch_policy:
      protected_branches: false
      custom_branch_policies: true
      branch_patterns: ["develop", "feature/*"]

  mainnet:
    protection_rules:
      - type: required_reviewers
        reviewers:
          - team: protocol-core
        minimum_approvals: 2
      - type: wait_timer
        wait_timer: 60  # 1 hour delay
    deployment_branch_policy:
      protected_branches: true
      custom_branch_policies: true
      branch_patterns: ["main", "release/*"]
```

---

## Security Rules

### Rule 1: No Hardcoded Secrets

```yaml
# .github/workflows/security.yml
- name: Detect secrets
  uses: trufflesecurity/trufflehog@main
  with:
    extra_args: --only-verified
```

Patterns to block:
- Private keys (0x prefix + 64 hex chars)
- Mnemonics (12 or 24 word phrases)
- API keys (common patterns)
- JWT tokens
- AWS credentials

### Rule 2: Slither in CI

```yaml
- name: Run Slither
  uses: crytic/slither-action@v0.4.0
  with:
    target: contracts/
    slither-config: .slither.config.json
    fail-on: high
    sarif: results.sarif

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

### Rule 3: Mythril in CI

```yaml
- name: Run Mythril
  run: |
    docker run -v $(pwd):/code mythril/myth \
      analyze /code/contracts/SecureMintPolicy.sol \
      --solv 0.8.20 \
      --execution-timeout 300 \
      --max-depth 20
```

### Rule 4: Dependency Scanning

```yaml
- name: Check dependencies
  run: |
    # Foundry dependencies
    forge update --check

    # npm dependencies (if applicable)
    npm audit --audit-level=high

    # Rust dependencies (Solana)
    cargo audit
```

### Rule 5: License Compliance

```yaml
- name: Check licenses
  run: |
    # Ensure all dependencies have compatible licenses
    npx license-checker --failOn "GPL-3.0;AGPL-3.0;SSPL-1.0"
```

### Rule 6: Signed Commits

```
All commits to main and release branches MUST be signed.
Configure: Settings -> Branches -> Require signed commits
```

### Rule 7: Security Advisories

```markdown
# SECURITY.md

## Reporting Vulnerabilities

Please report security vulnerabilities through our bug bounty program
on Immunefi: https://immunefi.com/bounty/[protocol-name]

DO NOT report vulnerabilities via public GitHub issues.

## Severity Levels

- Critical: Direct fund loss potential -> $50,000 - $500,000 bounty
- High: Indirect fund loss or protocol disruption -> $10,000 - $50,000 bounty
- Medium: Griefing or limited impact -> $1,000 - $10,000 bounty
- Low: Informational -> $100 - $1,000 bounty

## Response Times

- Acknowledgment: 24 hours
- Severity assessment: 48 hours
- Fix timeline: 7 days (critical), 14 days (high), 30 days (medium/low)
```

---

## Team Structure & CODEOWNERS

### Team Hierarchy

```
organization/
+-- protocol-admins          (2-3 people: CTO, Security Lead, Lead Dev)
|   +-- Full admin access to all repos
|   +-- Can merge to main
|   +-- Manage secrets and environments
|
+-- protocol-core            (3-5 people: Smart contract developers)
|   +-- Write access to contract repos
|   +-- Required reviewers for main
|   +-- Can deploy to testnet
|
+-- protocol-security        (2-3 people: Security engineers)
|   +-- Write access to security repo
|   +-- Required reviewers for security-sensitive changes
|   +-- Access to audit management
|
+-- protocol-frontend        (2-4 people: Frontend developers)
|   +-- Write access to frontend repo
|   +-- Read access to contract repos
|
+-- protocol-ops             (1-2 people: DevOps engineers)
|   +-- Write access to ops repo
|   +-- Manage CI/CD pipelines
|   +-- Manage infrastructure
|
+-- protocol-community       (1-2 people: Community managers)
    +-- Triage access to all repos
    +-- Manage issues and discussions
```

### CODEOWNERS File

```
# /protocol-contracts/.github/CODEOWNERS

# Default: core team reviews everything
*                               @org/protocol-core

# Smart contracts: require core + security review
/contracts/                     @org/protocol-core @org/protocol-security
/contracts/SecureMintPolicy.sol  @org/protocol-admins @org/protocol-security
/contracts/EmergencyPause.sol   @org/protocol-admins @org/protocol-security
/contracts/GuardianMultisig.sol @org/protocol-admins @org/protocol-security

# Tests: core team
/test/                          @org/protocol-core

# Deployment scripts: admins only
/script/Deploy.s.sol            @org/protocol-admins
/script/ConfigureOracles.s.sol  @org/protocol-admins

# CI/CD: ops team
/.github/workflows/             @org/protocol-ops @org/protocol-admins

# Security config: security team
/.slither.config.json           @org/protocol-security
/SECURITY.md                    @org/protocol-security @org/protocol-admins

# Dependencies: core + security
/foundry.toml                   @org/protocol-core @org/protocol-security
/remappings.txt                 @org/protocol-core

# Audit reports: security team
/audits/                        @org/protocol-security @org/protocol-admins
```

---

## Release Workflow

### Versioning

Follow semantic versioning: `vMAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (new contract deployment required)
- **MINOR**: New features (backwards compatible, may need parameter update)
- **PATCH**: Bug fixes (no interface changes)

### Release Process

```
1. Create release branch from develop
   git checkout -b release/v1.2.0 develop

2. Freeze features, fix bugs only
   - Only bug fix PRs allowed to release branch
   - All PRs require 2 approvals

3. Run full security suite
   - Slither: Zero high/critical
   - Mythril: Zero violations
   - Invariant tests: All pass (1000+ sequences)
   - Fork tests: All pass against live data

4. External audit (if applicable)
   - Engage audit firm
   - Address all findings
   - Obtain clean report

5. Create release
   - Merge release branch to main
   - Tag: git tag -s v1.2.0 -m "Release v1.2.0"
   - Create GitHub release with:
     - Changelog
     - Contract addresses (if deployed)
     - Audit report links
     - Migration guide (if breaking)

6. Deploy
   - Testnet first (automated)
   - Verification on testnet
   - Mainnet (manual trigger, 2 approvals)
   - Contract verification on Etherscan

7. Post-release
   - Merge main back to develop
   - Update documentation
   - Announce to community
   - Monitor for 72 hours
```

### Release Checklist

```markdown
## Release v_._._

### Pre-Release
- [ ] All tests pass (unit, integration, invariant, fork)
- [ ] Slither: 0 high/critical findings
- [ ] Mythril: 0 violations
- [ ] Coverage >= 95% on core contracts
- [ ] Audit report clean (if applicable)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in foundry.toml

### Deployment
- [ ] Testnet deployment successful
- [ ] Testnet verification passed
- [ ] Mainnet deployment plan reviewed (2 approvals)
- [ ] Mainnet deployment executed
- [ ] Contract verified on Etherscan/Sourcify
- [ ] Multisig ownership transferred (if new deployment)
- [ ] Oracle feeds configured and verified
- [ ] Parameters set and verified

### Post-Deployment
- [ ] Frontend updated with new contract addresses
- [ ] SDK updated and published
- [ ] Subgraph updated and synced
- [ ] Monitoring configured for new contracts
- [ ] Community announcement published
- [ ] 72-hour monitoring period started
```

---

## CI/CD Pipeline

### Pipeline Architecture

```
PR Created
    |
    v
[Compile] -> [Lint] -> [Unit Tests] -> [Security Scan]
    |                       |                |
    v                       v                v
[Coverage Report]   [Gas Report]    [Slither SARIF]
    |                                       |
    +----------- All Pass? -----------------+
                    |
                    v
              [PR Approved (2x)]
                    |
                    v
              [Merge to develop]
                    |
                    v (on release branch)
              [Invariant Tests]
                    |
                    v
              [Fork Tests]
                    |
                    v
              [Deploy Testnet]
                    |
                    v
              [Verify Testnet]
                    |
                    v (manual approval)
              [Deploy Mainnet]
                    |
                    v
              [Verify Mainnet]
                    |
                    v
              [Post-Deploy Checks]
```

### Core CI Workflow

```yaml
name: CI
on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [develop]

jobs:
  compile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge build --sizes

  test:
    needs: compile
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge test -vvv --gas-report
      - run: forge coverage --report lcov
      - uses: codecov/codecov-action@v4

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install solhint
      - run: npx solhint 'contracts/**/*.sol'

  security:
    needs: compile
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: crytic/slither-action@v0.4.0
        with:
          fail-on: high
          sarif: results.sarif
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

---

## Issue and PR Templates

### Pull Request Template

```markdown
## Description

[Provide a brief description of the changes in this PR]

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Invariant tests added/updated (if applicable)
- [ ] Fork tests added/updated (if applicable)
- [ ] All tests pass locally

## Security

- [ ] No new security warnings from Slither
- [ ] No new security warnings from Mythril
- [ ] Security implications documented (if applicable)
- [ ] Access control reviewed

## Checklist

- [ ] Code follows the style guidelines
- [ ] Self-review performed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Gas optimization considered

## Related Issues

Closes #[issue number]

## Screenshots (if applicable)

[Add screenshots here]
```

### Bug Report Template

```yaml
name: Bug Report
description: Report a bug in the protocol
title: "[BUG] "
labels: ["bug"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to report a bug!

  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear description of the bug
    validations:
      required: true

  - type: textarea
    id: reproduction
    attributes:
      label: Steps to Reproduce
      description: Detailed steps to reproduce the bug
      placeholder: |
        1. Deploy contract with...
        2. Call function...
        3. Observe...
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What you expected to happen
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: Version
      description: Contract version or commit hash
    validations:
      required: true

  - type: dropdown
    id: severity
    attributes:
      label: Severity
      options:
        - Low
        - Medium
        - High
        - Critical
    validations:
      required: true
```

---

## Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    reviewers:
      - "protocol-core"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    reviewers:
      - "protocol-ops"

  # Cargo dependencies (Solana)
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    reviewers:
      - "protocol-core"
```

---

Last Updated: 2026-02-05
