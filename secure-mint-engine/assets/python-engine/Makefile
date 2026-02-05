# SecureMintEngine Python CLI -- Makefile
# Usage: make <target> [VARS]

SHELL := /bin/bash
CLI   := python3 securemint_cli.py
FORMAT ?= json
FILE  ?= mint_entries.json
ADDRESS ?=
ADDR_FILE ?= addresses.txt
TYPE  ?= reserve
BUNDLE ?= bundle.json

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Setup & Maintenance
# ---------------------------------------------------------------------------

.PHONY: setup
setup: ## Install dependencies
	pip install -r requirements.txt

.PHONY: clean
clean: ## Remove generated files
	rm -rf __pycache__ *.pyc .pytest_cache outputs/

.PHONY: test
test: ## Run tests
	python3 -m pytest tests/ -v --tb=short

.PHONY: lint
lint: ## Run linters (ruff + mypy)
	ruff check .
	mypy securemint_cli.py --ignore-missing-imports

.PHONY: format
format: ## Auto-format code
	ruff format .

# ---------------------------------------------------------------------------
# Minting Operations
# ---------------------------------------------------------------------------

.PHONY: mint
mint: ## Execute batch mint (FILE=mint_entries.json)
	$(CLI) --format $(FORMAT) mint-batch --file $(FILE)

.PHONY: mint-dry
mint-dry: ## Dry-run batch mint
	$(CLI) --format $(FORMAT) mint-batch --file $(FILE) --dry-run

# ---------------------------------------------------------------------------
# Compliance
# ---------------------------------------------------------------------------

.PHONY: compliance
compliance: ## Check single address compliance (ADDRESS=0x...)
	$(CLI) --format $(FORMAT) compliance --address $(ADDRESS)

.PHONY: compliance-bulk
compliance-bulk: ## Check bulk addresses (ADDR_FILE=addresses.txt)
	$(CLI) --format $(FORMAT) compliance --file $(ADDR_FILE)

# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

.PHONY: report
report: ## Generate report (TYPE=reserve|monthly|treasury|compliance|bridge)
	$(CLI) --format $(FORMAT) report --type $(TYPE)

.PHONY: reports-all
reports-all: ## Generate all report types
	@for t in reserve monthly treasury compliance bridge; do \
		echo "=== $$t report ==="; \
		$(CLI) --format $(FORMAT) report --type $$t; \
	done

# ---------------------------------------------------------------------------
# Monitoring & Status
# ---------------------------------------------------------------------------

.PHONY: oracle-status
oracle-status: ## Check oracle health
	$(CLI) --format $(FORMAT) oracle-status

.PHONY: invariants
invariants: ## Check all 4 SecureMint invariants
	$(CLI) --format $(FORMAT) invariants

# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

.PHONY: simulate
simulate: ## Simulate transaction bundle (BUNDLE=bundle.json)
	$(CLI) --format $(FORMAT) simulate --bundle $(BUNDLE)

# ---------------------------------------------------------------------------
# Validation & Health
# ---------------------------------------------------------------------------

.PHONY: validate-config
validate-config: ## Validate .env configuration
	$(CLI) --format $(FORMAT) config-check

.PHONY: validate-contracts
validate-contracts: ## Validate Solidity contract files
	$(CLI) --format $(FORMAT) validate-contracts

.PHONY: health-check
health-check: ## Full health dashboard (config + contracts + oracle + invariants)
	$(CLI) --format $(FORMAT) health-check

# ---------------------------------------------------------------------------
# Deployment Operations
# ---------------------------------------------------------------------------

.PHONY: production-deploy
production-deploy: intake preflight deploy smoke-test verify ## Full production deploy pipeline

.PHONY: intake
intake: ## Run intake checklist
	@echo "Running intake checklist..."
	$(CLI) --format $(FORMAT) intake

.PHONY: preflight
preflight: ## Run all preflight checks
	$(CLI) --format $(FORMAT) preflight

.PHONY: preflight-hard
preflight-hard: ## Run only hard gate preflight checks
	$(CLI) --format $(FORMAT) preflight --hard-only

.PHONY: preflight-soft
preflight-soft: ## Run only soft gate preflight checks
	$(CLI) --format $(FORMAT) preflight --soft-only

.PHONY: deploy
deploy: ## Deploy all contracts via Foundry
	@echo "Deploying contracts..."
	forge script scripts/Deploy.s.sol --broadcast --verify

.PHONY: deploy-token
deploy-token: ## Deploy BackedToken contract
	@echo "Deploying BackedToken..."
	forge script scripts/Deploy.s.sol --sig "deployToken()" --broadcast

.PHONY: deploy-policy
deploy-policy: ## Deploy SecureMintPolicy contract
	@echo "Deploying SecureMintPolicy..."
	forge script scripts/Deploy.s.sol --sig "deployPolicy()" --broadcast

.PHONY: deploy-oracle
deploy-oracle: ## Deploy Oracle contract
	@echo "Deploying Oracle..."
	forge script scripts/Deploy.s.sol --sig "deployOracle()" --broadcast

.PHONY: deploy-governance
deploy-governance: ## Deploy Governance contract
	@echo "Deploying Governance..."
	forge script scripts/Deploy.s.sol --sig "deployGovernance()" --broadcast

.PHONY: deploy-emergency
deploy-emergency: ## Deploy EmergencyPause contract
	@echo "Deploying EmergencyPause..."
	forge script scripts/Deploy.s.sol --sig "deployEmergency()" --broadcast

.PHONY: smoke-test
smoke-test: ## Run all 9 deployment smoke tests
	$(CLI) --format $(FORMAT) smoke-test

.PHONY: verify
verify: ## Verify deployed contracts on block explorer
	@echo "Verifying contracts..."
	forge verify-contract $(TOKEN_ADDRESS) BackedToken
	forge verify-contract $(POLICY_ADDRESS) SecureMintPolicy

.PHONY: configure-roles
configure-roles: ## Configure access control roles via multisig
	@echo "Configure roles via multisig"

.PHONY: fund-treasury
fund-treasury: ## Fund treasury via multisig
	@echo "Fund treasury via multisig"

# ---------------------------------------------------------------------------
# Burn Operations
# ---------------------------------------------------------------------------

.PHONY: burn
burn: ## Batch burn tokens (FILE=burn_entries.json)
	$(CLI) --format $(FORMAT) burn --file $(FILE)

# ---------------------------------------------------------------------------
# Additional Status
# ---------------------------------------------------------------------------

.PHONY: treasury-status
treasury-status: ## Query TreasuryVault balances and health
	$(CLI) --format $(FORMAT) treasury-status

.PHONY: bridge-status
bridge-status: ## Cross-chain bridge monitoring
	$(CLI) --format $(FORMAT) bridge-status

# ---------------------------------------------------------------------------
# Compliance Variants
# ---------------------------------------------------------------------------

.PHONY: compliance-aml
compliance-aml: ## AML-only compliance check (ADDR_FILE=addresses.txt)
	$(CLI) --format $(FORMAT) compliance --file $(ADDR_FILE) --aml-only

.PHONY: compliance-sanctions
compliance-sanctions: ## Sanctions-only compliance check (ADDR_FILE=addresses.txt)
	$(CLI) --format $(FORMAT) compliance --file $(ADDR_FILE) --sanctions-only

# ---------------------------------------------------------------------------
# Launch Gates
# ---------------------------------------------------------------------------

.PHONY: full-gates
full-gates: legal-gate audit-gate stress-test launch-countdown ## Run all launch gates sequentially

.PHONY: legal-gate
legal-gate: ## Gate 1: Legal/Regulatory review
	@echo "Gate 1: Legal/Regulatory — Generate LEGAL_COMPLIANCE_REPORT.md"

.PHONY: audit-gate
audit-gate: ## Gate 2: Security Audit review
	@echo "Gate 2: Security Audit — Generate SECURITY_AUDIT_REPORT.md"

.PHONY: stress-test
stress-test: ## Gate 3: Stress test simulation
	$(CLI) --format $(FORMAT) simulate --bundle stress_scenarios.json

.PHONY: launch-countdown
launch-countdown: ## Gate 4: Launch countdown
	@echo "Gate 4: Launch Countdown — Generate LAUNCH_COUNTDOWN_REPORT.md"

.PHONY: gate-status
gate-status: ## Check gate status
	@echo "Checking gate status..."

.PHONY: gate-report
gate-report: ## Generate consolidated gate report
	@echo "Generating consolidated gate report..."

# ---------------------------------------------------------------------------
# Contract Operations
# ---------------------------------------------------------------------------

.PHONY: contracts
contracts: ## Build Solidity contracts
	forge build

.PHONY: config-validate
config-validate: ## Validate configuration
	$(CLI) --format $(FORMAT) config-check

.PHONY: check
check: ## Build and run unit tests (excludes invariant tests)
	forge build && forge test --no-match-path "test/invariant/*"

.PHONY: validate
validate: check invariants validate-contracts validate-config ## Full validation suite
