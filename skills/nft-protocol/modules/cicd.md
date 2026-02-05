# CI/CD Pipeline

Continuous integration and deployment pipeline for NFT protocol: GitHub Actions workflows, automated testing, deployment scripts, and monitoring.

---

# MODULE 16: CI/CD PIPELINE

## GitHub Actions Workflow

File: `.github/workflows/ci.yml`

```yaml
name: Smart Contract CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  FOUNDRY_PROFILE: ci

jobs:
  # ==================== LINT ====================
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run Solhint
        run: npx solhint 'contracts/**/*.sol'

      - name: Run Prettier
        run: npx prettier --check 'contracts/**/*.sol'

  # ==================== COMPILE ====================
  compile:
    name: Compile
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Compile contracts
        run: npx hardhat compile

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: contract-artifacts
          path: |
            artifacts/
            cache/

  # ==================== TEST ====================
  test:
    name: Test
    runs-on: ubuntu-latest
    needs: compile
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          name: contract-artifacts

      - name: Run tests
        run: npx hardhat test
        env:
          REPORT_GAS: true

      - name: Run coverage
        run: npx hardhat coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: false

  # ==================== SECURITY ====================
  security:
    name: Security Analysis
    runs-on: ubuntu-latest
    needs: compile
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.10"

      - name: Install Slither
        run: pip3 install slither-analyzer

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Run Slither
        run: slither . --print human-summary --sarif slither.sarif
        continue-on-error: true

      - name: Upload Slither SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: slither.sarif
        continue-on-error: true

  # ==================== GAS REPORT ====================
  gas-report:
    name: Gas Report
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Generate gas report
        run: npx hardhat test --gas-report > gas-report.txt
        env:
          REPORT_GAS: true

      - name: Comment gas report
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('gas-report.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## Gas Report\n```\n' + report + '\n```'
            });

  # ==================== DEPLOY TESTNET ====================
  deploy-testnet:
    name: Deploy to Testnet
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/develop'
    environment: testnet
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Deploy to Sepolia
        run: npx hardhat run scripts/deploy_multichain.ts --network sepolia
        env:
          PRIVATE_KEY: ${{ secrets.DEPLOYER_PRIVATE_KEY }}
          ALCHEMY_KEY: ${{ secrets.ALCHEMY_KEY }}
          ETHERSCAN_KEY: ${{ secrets.ETHERSCAN_KEY }}

      - name: Upload deployment addresses
        uses: actions/upload-artifact@v4
        with:
          name: testnet-deployment
          path: deployments/

  # ==================== VERIFY CONTRACTS ====================
  verify:
    name: Verify Contracts
    runs-on: ubuntu-latest
    needs: deploy-testnet
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Download deployment
        uses: actions/download-artifact@v4
        with:
          name: testnet-deployment
          path: deployments/

      - name: Verify on Etherscan
        run: |
          ADDRESSES=$(cat deployments/sepolia.json)
          # Add verification commands here
        env:
          ETHERSCAN_KEY: ${{ secrets.ETHERSCAN_KEY }}

  # ==================== DEPLOY MAINNET ====================
  deploy-mainnet:
    name: Deploy to Mainnet
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: mainnet
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Install dependencies
        run: npm ci

      - name: Deploy to Mainnet
        run: npx hardhat run scripts/deploy_multichain.ts --network mainnet
        env:
          PRIVATE_KEY: ${{ secrets.MAINNET_DEPLOYER_KEY }}
          ALCHEMY_KEY: ${{ secrets.ALCHEMY_KEY }}
          ETHERSCAN_KEY: ${{ secrets.ETHERSCAN_KEY }}

      - name: Upload deployment addresses
        uses: actions/upload-artifact@v4
        with:
          name: mainnet-deployment
          path: deployments/
```

## Foundry CI Workflow (Alternative)

File: `.github/workflows/foundry.yml`

```yaml
name: Foundry CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  FOUNDRY_PROFILE: ci

jobs:
  check:
    name: Foundry Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
        with:
          version: nightly

      - name: Run Forge build
        run: |
          forge --version
          forge build --sizes
        id: build

      - name: Run Forge tests
        run: |
          forge test -vvv
        id: test

      - name: Run Forge coverage
        run: |
          forge coverage --report lcov
        id: coverage

      - name: Run Forge snapshot
        run: |
          forge snapshot
        id: snapshot

      - name: Run Slither
        uses: crytic/slither-action@v0.3.0
        id: slither
        with:
          fail-on: medium
          slither-args: --filter-paths "test|script"

  invariants:
    name: Invariant Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
        with:
          version: nightly

      - name: Run invariant tests
        run: |
          forge test --match-path "test/invariant/**" -vvv
```

## Pre-commit Hooks

File: `.husky/pre-commit`

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Lint Solidity
npx solhint 'contracts/**/*.sol'

# Format check
npx prettier --check 'contracts/**/*.sol'

# Run tests
npx hardhat test

# Run Slither (quick check)
slither . --print human-summary 2>/dev/null || true

echo "Pre-commit checks passed!"
```

## Package Scripts

File: `package.json` (scripts section)

```json
{
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "test:coverage": "hardhat coverage",
    "test:gas": "REPORT_GAS=true hardhat test",
    "lint": "solhint 'contracts/**/*.sol'",
    "lint:fix": "solhint 'contracts/**/*.sol' --fix",
    "format": "prettier --write 'contracts/**/*.sol'",
    "format:check": "prettier --check 'contracts/**/*.sol'",
    "security": "slither . --print human-summary",
    "security:full": "slither . --json slither-report.json",
    "deploy:sepolia": "hardhat run scripts/deploy_multichain.ts --network sepolia",
    "deploy:polygon": "hardhat run scripts/deploy_multichain.ts --network polygon",
    "deploy:base": "hardhat run scripts/deploy_multichain.ts --network base",
    "deploy:mainnet": "hardhat run scripts/deploy_multichain.ts --network mainnet",
    "verify": "hardhat verify",
    "clean": "hardhat clean",
    "prepare": "husky install"
  }
}
```

---

# COMPLETE REPOSITORY STRUCTURE

```
institutional-nft-protocol/
|- .github/
|   |- workflows/
|       |- ci.yml
|       |- foundry.yml
|- .husky/
|   |- pre-commit
|- contracts/
|   |- core/
|   |   |- ERC721SecureUUPS.sol
|   |   |- RentableNFT.sol
|   |- marketplace/
|   |   |- NFTMarketplace.sol
|   |- defi/
|   |   |- FractionalVault.sol
|   |   |- NFTLending.sol
|   |   |- NFTRental.sol
|   |- governance/
|   |   |- GovToken.sol
|   |   |- GovTimelock.sol
|   |   |- GovGovernor.sol
|   |- compliance/
|   |   |- ComplianceRegistry.sol
|   |- oracle/
|   |   |- AssetOracle.sol
|   |- payments/
|   |   |- RoyaltyRouter.sol
|   |- interfaces/
|       |- IComplianceRegistry.sol
|       |- IAssetOracle.sol
|       |- IERC4907.sol
|- scripts/
|   |- deploy_erc721_uups.js
|   |- deploy_dao.js
|   |- deploy_vault.js
|   |- deploy_multichain.ts
|   |- upgrade_erc721_uups.js
|   |- deploy_all_networks.sh
|- test/
|   |- ERC721SecureUUPS.test.js
|   |- FractionalVault.test.js
|   |- Governance.test.js
|   |- NFTMarketplace.test.js
|   |- NFTLending.test.js
|   |- ComplianceRegistry.test.js
|- subgraph/
|   |- schema.graphql
|   |- subgraph.yaml
|   |- src/
|   |   |- nft.ts
|   |   |- marketplace.ts
|   |   |- lending.ts
|   |- package.json
|- frontend/
|   |- hooks/
|   |   |- useNFT.ts
|   |   |- useIPFS.ts
|   |- components/
|   |   |- WalletConnect.tsx
|   |- lib/
|       |- wagmi.ts
|- docs/
|   |- legal/
|   |   |- spv-operating-agreement.md
|   |   |- token-holder-agreement.md
|   |   |- regulatory-guide.md
|   |- architecture.md
|   |- deployment-guide.md
|- deployments/
|   |- mainnet.json
|   |- polygon.json
|   |- base.json
|   |- sepolia.json
|- abis/
|   |- ERC721SecureUUPS.json
|   |- NFTMarketplace.json
|   |- ...
|- hardhat.config.ts
|- foundry.toml
|- package.json
|- slither.config.json
|- .env.example
|- .gitignore
|- README.md
```

---

# FINAL DEPLOYMENT CHECKLIST

```
+--------------------------------------------------------------------+
|                    PRODUCTION DEPLOYMENT CHECKLIST                   |
+--------------------------------------------------------------------+

PRE-DEPLOYMENT
|- [ ] All tests passing (unit, integration, invariant)
|- [ ] Coverage > 90%
|- [ ] Slither: No high/medium findings
|- [ ] External audit completed
|- [ ] Gas optimization verified
|- [ ] Access controls reviewed
|- [ ] Upgrade path documented
|- [ ] Emergency procedures documented

DEPLOYMENT
|- [ ] Deploy to testnet first
|- [ ] Verify all contracts on explorer
|- [ ] Test all functions on testnet
|- [ ] Configure multisig wallets
|- [ ] Set up monitoring (Tenderly/Forta)
|- [ ] Deploy to mainnet
|- [ ] Verify mainnet contracts
|- [ ] Transfer ownership to multisig

POST-DEPLOYMENT
|- [ ] Subgraph deployed and synced
|- [ ] Frontend connected and tested
|- [ ] Documentation published
|- [ ] Bug bounty program launched
|- [ ] Monitoring alerts configured
|- [ ] Incident response plan ready
|- [ ] Legal review completed
|- [ ] Compliance registry configured

ONGOING
|- [ ] Regular security reviews
|- [ ] Monitor for new vulnerabilities
|- [ ] Keep dependencies updated
|- [ ] Review gas costs
|- [ ] Community feedback integration
```

---
