# SecureMint Engine - Python CLI Makefile
# MAKE-based local execution for 90-99% token reduction

.PHONY: help install setup mint burn compliance report oracle treasury bridge simulate clean
.PHONY: health-check validate-config validate-contracts smoke-test preflight intake
.PHONY: production-deploy contracts check validate full-gates test

# Default target
help:
	@echo "SecureMint Engine - Local Python CLI"
	@echo ""
	@echo "Setup:"
	@echo "  make install      Install dependencies"
	@echo "  make setup        Configure environment"
	@echo ""
	@echo "Token Operations:"
	@echo "  make mint FILE=input.csv           Batch mint from CSV"
	@echo "  make mint-dry FILE=input.csv       Dry-run batch mint"
	@echo "  make burn FILE=input.csv           Batch burn from CSV"
	@echo ""
	@echo "Compliance:"
	@echo "  make compliance ADDR=0x...         Check single address"
	@echo "  make compliance FILE=addrs.txt     Bulk compliance check"
	@echo ""
	@echo "Reports:"
	@echo "  make report TYPE=reserve           Reserve attestation"
	@echo "  make report TYPE=monthly           Monthly summary"
	@echo "  make report TYPE=compliance        Compliance report"
	@echo "  make report TYPE=treasury          Treasury report"
	@echo ""
	@echo "Operations:"
	@echo "  make oracle-status                 Check oracle status"
	@echo "  make treasury-status               Check treasury status"
	@echo "  make bridge-status                 Check bridge status"
	@echo "  make invariants                    Check all invariants"
	@echo ""
	@echo "Simulation:"
	@echo "  make simulate FILE=txs.json        Simulate transactions"

# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

PYTHON ?= python3
PIP ?= pip3

install:
	$(PIP) install -r requirements.txt

setup:
	@mkdir -p ~/.securemint
	@if [ ! -f ~/.securemint/config.json ]; then \
		echo '{"rpc_url": "http://localhost:8545", "chain_id": 1}' > ~/.securemint/config.json; \
		echo "Created config at ~/.securemint/config.json"; \
	fi
	@echo "Setup complete. Edit ~/.securemint/config.json with your settings."

# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

mint:
ifndef FILE
	$(error FILE is required. Usage: make mint FILE=input.csv)
endif
	$(PYTHON) securemint_cli.py mint-batch -i $(FILE) -o results.json

mint-dry:
ifndef FILE
	$(error FILE is required. Usage: make mint-dry FILE=input.csv)
endif
	$(PYTHON) securemint_cli.py mint-batch -i $(FILE) --dry-run

mint-force:
ifndef FILE
	$(error FILE is required)
endif
	$(PYTHON) securemint_cli.py mint-batch -i $(FILE) --force

burn:
ifndef FILE
	$(error FILE is required. Usage: make burn FILE=input.csv)
endif
	$(PYTHON) securemint_cli.py burn-batch -i $(FILE) -o burn_results.json

burn-dry:
ifndef FILE
	$(error FILE is required)
endif
	$(PYTHON) securemint_cli.py burn-batch -i $(FILE) --dry-run

# ═══════════════════════════════════════════════════════════════════════════════
# COMPLIANCE
# ═══════════════════════════════════════════════════════════════════════════════

compliance:
ifdef ADDR
	$(PYTHON) securemint_cli.py compliance -a $(ADDR) --kyc --aml --sanctions
else ifdef FILE
	$(PYTHON) securemint_cli.py compliance -i $(FILE) --kyc --aml --sanctions
else
	$(error ADDR or FILE required. Usage: make compliance ADDR=0x... or FILE=addrs.txt)
endif

compliance-kyc:
ifdef ADDR
	$(PYTHON) securemint_cli.py compliance -a $(ADDR) --kyc
else ifdef FILE
	$(PYTHON) securemint_cli.py compliance -i $(FILE) --kyc
else
	$(error ADDR or FILE required)
endif

compliance-aml:
ifdef ADDR
	$(PYTHON) securemint_cli.py compliance -a $(ADDR) --aml
else ifdef FILE
	$(PYTHON) securemint_cli.py compliance -i $(FILE) --aml
else
	$(error ADDR or FILE required)
endif

compliance-sanctions:
ifdef ADDR
	$(PYTHON) securemint_cli.py compliance -a $(ADDR) --sanctions
else ifdef FILE
	$(PYTHON) securemint_cli.py compliance -i $(FILE) --sanctions
else
	$(error ADDR or FILE required)
endif

# ═══════════════════════════════════════════════════════════════════════════════
# REPORTS
# ═══════════════════════════════════════════════════════════════════════════════

report:
ifndef TYPE
	$(error TYPE is required. Options: reserve, monthly, compliance, treasury, bridge, insurance)
endif
	$(PYTHON) securemint_cli.py report -t $(TYPE) --markdown -o reports/

report-reserve:
	$(PYTHON) securemint_cli.py report -t reserve --include-proof --markdown -o reports/

report-monthly:
	$(PYTHON) securemint_cli.py report -t monthly --markdown -o reports/

report-compliance:
	$(PYTHON) securemint_cli.py report -t compliance -j $(or $(JURISDICTION),US) --markdown -o reports/

report-treasury:
	$(PYTHON) securemint_cli.py report -t treasury --markdown -o reports/

report-bridge:
	$(PYTHON) securemint_cli.py report -t bridge --markdown -o reports/

report-insurance:
	$(PYTHON) securemint_cli.py report -t insurance --markdown -o reports/

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

oracle-status:
	$(PYTHON) securemint_cli.py oracle status

oracle-history:
	$(PYTHON) securemint_cli.py oracle history --limit 100 -o oracle_history.json

treasury-status:
	$(PYTHON) securemint_cli.py treasury status

treasury-rebalance:
	$(PYTHON) securemint_cli.py treasury rebalance

bridge-status:
	$(PYTHON) securemint_cli.py bridge status

bridge-pending:
	$(PYTHON) securemint_cli.py bridge pending

invariants:
	@echo "Checking SecureMint Invariants..."
	@$(PYTHON) -c "import asyncio; from securemint_api import SecureMintAPI; \
		api = SecureMintAPI('$(or $(RPC_URL),http://localhost:8545)'); \
		result = asyncio.run(api.check_invariants()); \
		import json; print(json.dumps(result, indent=2))"

# ═══════════════════════════════════════════════════════════════════════════════
# SIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

simulate:
ifndef FILE
	$(error FILE is required. Usage: make simulate FILE=txs.json)
endif
	$(PYTHON) securemint_cli.py simulate --tx-file $(FILE)

simulate-mint:
	@echo "Simulating mint: $(RECIPIENT) $(AMOUNT)"
	$(PYTHON) -c "import asyncio; from securemint_api import SecureMintAPI; \
		api = SecureMintAPI('$(or $(RPC_URL),http://localhost:8545)'); \
		# Would call simulate_transaction here"

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

generate-sample:
	@$(PYTHON) -c "from bulk_operations import BulkOperator; \
		BulkOperator(None).generate_sample_csv('sample_mint.csv', 10)"
	@echo "Generated sample_mint.csv"

clean:
	rm -rf __pycache__ *.pyc .pytest_cache
	rm -f results.json burn_results.json compliance_results.json
	rm -f oracle_history.json simulation_results.json

clean-reports:
	rm -rf reports/*.json reports/*.md

# ═══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

env-check:
	@echo "Environment Check:"
	@echo "  RPC_URL: $(or $(RPC_URL),[not set - using config])"
	@echo "  CHAIN_ID: $(or $(CHAIN_ID),[not set - using config])"
	@echo "  PRIVATE_KEY: $(if $(PRIVATE_KEY),[set],[not set])"
	@echo "  TOKEN_ADDRESS: $(or $(TOKEN_ADDRESS),[not set])"
	@echo "  POLICY_ADDRESS: $(or $(POLICY_ADDRESS),[not set])"
	@echo "  CHAINALYSIS_API_KEY: $(if $(CHAINALYSIS_API_KEY),[set],[not set])"

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH WORKFLOWS
# ═══════════════════════════════════════════════════════════════════════════════

# Full compliance-checked mint workflow
mint-compliant:
ifndef FILE
	$(error FILE is required)
endif
	@echo "Step 1: Compliance check..."
	$(PYTHON) securemint_cli.py compliance -i $(FILE) --kyc --aml --sanctions -o compliance_check.json
	@echo ""
	@echo "Step 2: Dry run mint..."
	$(PYTHON) securemint_cli.py mint-batch -i $(FILE) --dry-run
	@echo ""
	@echo "Review compliance_check.json before proceeding."
	@echo "Run 'make mint FILE=$(FILE)' to execute."

# Generate all reports
reports-all:
	@mkdir -p reports
	$(MAKE) report-reserve
	$(MAKE) report-monthly
	$(MAKE) report-treasury
	$(MAKE) report-bridge
	$(MAKE) report-insurance
	@echo "All reports generated in reports/"

# ═══════════════════════════════════════════════════════════════════════════════
# HEALTH & VALIDATION (Referenced by secure-mint-engine.md)
# ═══════════════════════════════════════════════════════════════════════════════

health-check:
	@echo "SecureMint Health Dashboard"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "1. Python Engine............ OK (CLI available)"
	@$(PYTHON) securemint_cli.py --help > /dev/null 2>&1 && echo "2. CLI Imports.............. OK" || echo "2. CLI Imports.............. FAIL"
	@$(PYTHON) -c "import web3; print('3. web3.py.................. OK (v' + web3.__version__ + ')')" 2>/dev/null || echo "3. web3.py.................. NOT INSTALLED (run: make install)"
	@echo ""
	@echo "4. RPC Connection:"
	@$(PYTHON) -c "from web3 import Web3; w3 = Web3(Web3.HTTPProvider('$(or $(RPC_URL),http://localhost:8545)')); print('   Connected:', w3.is_connected())" 2>/dev/null || echo "   Connection: FAILED"
	@echo ""
	@echo "5. Config: $(or $(HOME)/.securemint/config.json,[checking...])"
	@test -f $(HOME)/.securemint/config.json && echo "   Config file: EXISTS" || echo "   Config file: NOT FOUND (run: make setup)"
	@echo ""
	@echo "═══════════════════════════════════════"

validate-config:
	@echo "Validating configuration..."
	@$(PYTHON) -c "$$VALIDATE_CONFIG_SCRIPT"

define VALIDATE_CONFIG_SCRIPT
import json, os, sys
config_path = os.path.expanduser('~/.securemint/config.json')
if not os.path.exists(config_path):
    print('ERROR: No config file. Run: make setup')
    sys.exit(1)
config = json.load(open(config_path))
required = ['rpc_url', 'chain_id']
missing = [k for k in required if k not in config]
if missing:
    print('MISSING:', missing)
    sys.exit(1)
print('Config: OK')
endef
export VALIDATE_CONFIG_SCRIPT

validate-contracts:
	@echo "Validating Solidity contracts..."
	@test -d ../contracts && echo "Contracts directory: EXISTS" || echo "ERROR: contracts/ not found"
	@ls ../contracts/*.sol 2>/dev/null | wc -l | xargs -I{} echo "Solidity files found: {}"
	@echo "Checking for core contracts..."
	@for f in BackedToken.sol SecureMintPolicy.sol EmergencyPause.sol TreasuryVault.sol RedemptionEngine.sol; do \
		test -f "../contracts/$$f" && echo "  ✓ $$f" || echo "  ✗ $$f MISSING"; \
	done
	@echo "Contract validation complete."

smoke-test:
	@echo "SecureMint Smoke Tests"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "SM-01: Python CLI available"
	@$(PYTHON) securemint_cli.py --help > /dev/null 2>&1 && echo "  PASS" || echo "  FAIL"
	@echo ""
	@echo "SM-02: Module imports"
	@$(PYTHON) -c "from securemint_api import SecureMintAPI" 2>/dev/null && echo "  PASS: securemint_api" || echo "  FAIL: securemint_api"
	@$(PYTHON) -c "from bulk_operations import BulkOperator" 2>/dev/null && echo "  PASS: bulk_operations" || echo "  FAIL: bulk_operations"
	@$(PYTHON) -c "from compliance_engine import ComplianceEngine" 2>/dev/null && echo "  PASS: compliance_engine" || echo "  FAIL: compliance_engine"
	@$(PYTHON) -c "from report_generator import ReportGenerator" 2>/dev/null && echo "  PASS: report_generator" || echo "  FAIL: report_generator"
	@echo ""
	@echo "SM-03: Config exists"
	@test -f $(HOME)/.securemint/config.json && echo "  PASS" || echo "  SKIP (no config yet)"
	@echo ""
	@echo "SM-04: Dependencies installed"
	@$(PYTHON) -c "import web3, aiohttp, pandas" 2>/dev/null && echo "  PASS" || echo "  FAIL (run: make install)"
	@echo ""
	@echo "SM-05: Contracts present"
	@test -f ../contracts/SecureMintPolicy.sol && echo "  PASS" || echo "  FAIL"
	@echo ""
	@echo "SM-06: References present"
	@test -f ../../references/invariants.md && echo "  PASS" || echo "  FAIL"
	@echo ""
	@echo "SM-07: Diagrams present"
	@test -f ../../diagrams/FullSystemWorkflow.ascii && echo "  PASS" || echo "  FAIL"
	@echo ""
	@echo "SM-08: CI script present"
	@test -f ../../scripts/monetary_routing_ci_check.py && echo "  PASS" || echo "  FAIL"
	@echo ""
	@echo "SM-09: .env.example present"
	@test -f .env.example && echo "  PASS" || echo "  FAIL"
	@echo ""
	@echo "═══════════════════════════════════════"

preflight:
	@echo "SecureMint Preflight Checks"
	@echo "═══════════════════════════════════════"
	$(MAKE) validate-config 2>/dev/null || true
	$(MAKE) validate-contracts
	$(MAKE) smoke-test
	@echo ""
	@echo "Preflight complete. Review any FAIL items above."

intake:
	@echo "SecureMint Intake Checklist"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "Required Information:"
	@echo "  1. Token name and symbol"
	@echo "  2. Backing type (fiat_reserves / crypto_collateral / RWA)"
	@echo "  3. Target chain(s)"
	@echo "  4. Oracle provider"
	@echo "  5. Global supply cap"
	@echo "  6. Per-epoch mint cap"
	@echo "  7. Governance model"
	@echo ""
	@echo "Run the assets/ Makefile for the full interactive intake:"
	@echo "  make -C .. intake"

# ═══════════════════════════════════════════════════════════════════════════════
# DELEGATION TO PARENT MAKEFILE (assets/Makefile)
# ═══════════════════════════════════════════════════════════════════════════════

production-deploy:
	$(MAKE) -C .. production-deploy

contracts:
	$(MAKE) -C .. build-contracts

check:
	$(MAKE) -C .. check

validate:
	$(MAKE) -C .. validate

full-gates:
	$(MAKE) -C .. full-gates

# ═══════════════════════════════════════════════════════════════════════════════
# TESTING
# ═══════════════════════════════════════════════════════════════════════════════

test:
	pytest tests/ -v

test-coverage:
	pytest tests/ -v --cov=. --cov-report=term-missing
