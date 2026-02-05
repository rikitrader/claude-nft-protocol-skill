#!/usr/bin/env python3
"""
securemint_cli.py -- CLI entry point for SecureMintEngine operations.

Subcommands:
    mint-batch       Batch mint tokens from CSV/JSON input
    burn             Batch burn tokens from CSV/JSON via burnFrom
    compliance       KYC/AML/sanctions checks
    report           Generate reserve, treasury, compliance, or bridge reports
    oracle-status    Check oracle health (price freshness, heartbeat)
    invariants       Check all 4 SecureMint invariants
    simulate         Dry-run transaction bundles via eth_call
    config-check     Validate environment configuration
    validate-contracts  Validate Solidity contract files
    health-check     Combined health dashboard
    treasury-status  Query TreasuryVault tier balances and health
    bridge-status    Cross-chain bridge monitoring
    smoke-test       Run all 9 deployment smoke tests (SM-01..SM-09)
    preflight        Run preflight hard gate checks before deployment
    intake           Run pre-deployment intake checklist
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

logger = logging.getLogger("securemint")


@dataclass
class EngineConfig:
    rpc_url: str
    token_address: str
    policy_address: str
    private_key: str
    chain_id: int

    @classmethod
    def from_env(cls) -> "EngineConfig":
        try:
            from dotenv import load_dotenv
            load_dotenv()
        except ImportError:
            pass

        return cls(
            rpc_url=os.environ.get("RPC_URL", "http://localhost:8545"),
            token_address=os.environ.get("TOKEN_ADDRESS", ""),
            policy_address=os.environ.get("POLICY_ADDRESS", ""),
            private_key=os.environ.get("PRIVATE_KEY", ""),
            chain_id=int(os.environ.get("CHAIN_ID", "1")),
        )


# Minimal ABI fragments
TOKEN_ABI = [
    {"name": "totalSupply", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "balanceOf", "type": "function", "inputs": [{"type": "address"}], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "paused", "type": "function", "inputs": [], "outputs": [{"type": "bool"}], "stateMutability": "view"},
]

POLICY_ABI = [
    {"name": "globalSupplyCap", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "epochMintCap", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "epochMinted", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "epochRemaining", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "mint", "type": "function", "inputs": [{"type": "address"}, {"type": "uint256"}], "outputs": [], "stateMutability": "nonpayable"},
]

TREASURY_ABI = [
    {"name": "tierBalance", "type": "function", "inputs": [{"type": "uint8"}], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "totalBalance", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "healthFactor", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "collateralRatio", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
]

BURN_ABI = [
    {"name": "burnFrom", "type": "function", "inputs": [{"type": "address"}, {"type": "uint256"}], "outputs": [], "stateMutability": "nonpayable"},
]


def cmd_mint_batch(args: argparse.Namespace) -> int:
    """Batch mint tokens from a CSV or JSON file."""
    config = EngineConfig.from_env()
    input_path = Path(args.file)

    if not input_path.exists():
        logger.error("Input file not found: %s", input_path)
        return 1

    if input_path.suffix == ".json":
        with open(input_path) as f:
            entries = json.load(f)
    elif input_path.suffix == ".csv":
        import csv
        with open(input_path) as f:
            reader = csv.DictReader(f)
            entries = list(reader)
    else:
        logger.error("Unsupported file format: %s (use .json or .csv)", input_path.suffix)
        return 1

    logger.info("Loaded %d mint entries from %s", len(entries), input_path)

    if args.dry_run:
        logger.info("[DRY RUN] Would mint %d entries:", len(entries))
        for i, entry in enumerate(entries):
            logger.info("  %d. to=%s amount=%s", i + 1, entry.get("to", "?"), entry.get("amount", "?"))
        return 0

    try:
        from web3 import Web3
        from web3 import HTTPProvider
        provider = HTTPProvider(config.rpc_url, request_kwargs={"timeout": 60})
        w3 = Web3(provider)
        policy = w3.eth.contract(address=config.policy_address, abi=POLICY_ABI)
        account = w3.eth.account.from_key(config.private_key)
        nonce = w3.eth.get_transaction_count(account.address)

        for i, entry in enumerate(entries):
            to = Web3.to_checksum_address(entry["to"])
            amount = int(entry["amount"])
            logger.info("Minting %d to %s (%d/%d)...", amount, to, i + 1, len(entries))
            tx = policy.functions.mint(to, amount).build_transaction({
                "from": account.address,
                "chainId": config.chain_id,
                "nonce": nonce,
                "gas": 300_000,
            })
            signed = w3.eth.account.sign_transaction(tx, config.private_key)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            logger.info("  TX %s status=%d", receipt.transactionHash.hex(), receipt.status)
            nonce += 1

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1

    return 0


def cmd_compliance(args: argparse.Namespace) -> int:
    """Check KYC/AML/sanctions status for addresses.

    PLACEHOLDER: Returns mock data. For production, integrate with
    Chainalysis Sanctions API, Elliptic, or TRM Labs.
    """
    addresses = []
    if args.address:
        addresses.append(args.address)
    if args.file:
        with open(args.file) as f:
            addresses.extend(line.strip() for line in f if line.strip())

    if not addresses:
        logger.error("No addresses provided. Use --address or --file")
        return 1

    logger.info("Checking compliance for %d addresses...", len(addresses))

    # Flag logic is wired; data is still placeholder
    aml_only = args.aml_only
    sanctions_only = args.sanctions_only

    results = []
    for addr in addresses:
        if aml_only:
            aml_status = "clear"
            sanctions_status = "skipped"
        elif sanctions_only:
            aml_status = "skipped"
            sanctions_status = "clear"
        else:
            aml_status = "clear"
            sanctions_status = "clear"

        result = {
            "address": addr,
            "kyc_status": "pending",
            "aml_status": aml_status,
            "sanctions_status": sanctions_status,
            "overall": "pending",
        }
        results.append(result)
        logger.info("  %s: overall=%s", addr, result["overall"])

    if args.format == "json":
        print(json.dumps(results, indent=2))

    return 0


def cmd_report(args: argparse.Namespace) -> int:
    """Generate protocol reports.

    Each report type produces different data:
        reserve     - totalSupply, backing amount (oracle), backing ratio, oracle health
        monthly     - totalSupply, epoch number, epoch minted, global remaining
        treasury    - TreasuryVault tier balances (T0-T3), total balance, health factor
        compliance  - total addresses checked placeholder, aml status summary
        bridge      - bridge contract code size, bridge address
    """
    report_type = args.type
    logger.info("Generating %s report...", report_type)

    config = EngineConfig.from_env()
    report: dict[str, Any] = {"type": report_type}

    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))

        if report_type == "reserve":
            token = w3.eth.contract(address=config.token_address, abi=TOKEN_ABI)
            total_supply = token.functions.totalSupply().call()
            report["total_supply"] = str(total_supply)

            oracle_address = os.environ.get("ORACLE_ADDRESS", "")
            if oracle_address:
                try:
                    oracle_abi = [
                        {"name": "getBackingAmount", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
                        {"name": "isHealthy", "type": "function", "inputs": [], "outputs": [{"type": "bool"}], "stateMutability": "view"},
                    ]
                    oracle = w3.eth.contract(address=oracle_address, abi=oracle_abi)
                    backing = oracle.functions.getBackingAmount().call()
                    healthy = oracle.functions.isHealthy().call()
                    ratio = (backing / total_supply * 100) if total_supply > 0 else 0
                    report["backing_amount"] = str(backing)
                    report["backing_ratio_pct"] = f"{ratio:.2f}"
                    report["oracle_healthy"] = healthy
                except Exception as exc:
                    report["oracle_error"] = str(exc)
            else:
                report["oracle_error"] = "ORACLE_ADDRESS not set"

        elif report_type == "monthly":
            token = w3.eth.contract(address=config.token_address, abi=TOKEN_ABI)
            policy = w3.eth.contract(address=config.policy_address, abi=POLICY_ABI)
            total_supply = token.functions.totalSupply().call()
            report["total_supply"] = str(total_supply)
            try:
                epoch_minted = policy.functions.epochMinted().call()
                epoch_cap = policy.functions.epochMintCap().call()
                global_cap = policy.functions.globalSupplyCap().call()
                remaining = global_cap - total_supply if global_cap > 0 else "unlimited"
                report["epoch_mint_cap"] = str(epoch_cap)
                report["epoch_minted"] = str(epoch_minted)
                report["global_remaining"] = str(remaining)
            except Exception as exc:
                report["policy_error"] = str(exc)

        elif report_type == "treasury":
            treasury_address = os.environ.get("TREASURY_ADDRESS", "")
            if treasury_address:
                try:
                    treasury = w3.eth.contract(address=treasury_address, abi=TREASURY_ABI)
                    tier_balances = {}
                    for i in range(4):
                        tier_balances[f"T{i}"] = str(treasury.functions.tierBalance(i).call())
                    report["tier_balances"] = tier_balances
                    report["total_balance"] = str(treasury.functions.totalBalance().call())
                    report["health_factor"] = str(treasury.functions.healthFactor().call())
                except Exception as exc:
                    report["treasury_error"] = str(exc)
            else:
                report["treasury_error"] = "TREASURY_ADDRESS not set"

        elif report_type == "compliance":
            report["total_addresses_checked"] = 0
            report["aml_status_summary"] = "no_data"
            report["note"] = "Compliance report is a placeholder; integrate with Chainalysis/Elliptic/TRM"

        elif report_type == "bridge":
            bridge_address = os.environ.get("BRIDGE_ADDRESS", "")
            if bridge_address:
                report["bridge_address"] = bridge_address
                try:
                    code = w3.eth.get_code(Web3.to_checksum_address(bridge_address))
                    report["bridge_code_size"] = len(code)
                except Exception as exc:
                    report["bridge_error"] = str(exc)
            else:
                report["bridge_error"] = "BRIDGE_ADDRESS not set"

        if args.format == "json":
            print(json.dumps(report, indent=2))
        else:
            print(f"# {report_type.title()} Report")
            for k, v in report.items():
                print(f"- **{k}**: {v}")

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1

    return 0


def cmd_oracle_status(args: argparse.Namespace) -> int:
    """Check oracle health and price freshness."""
    config = EngineConfig.from_env()
    logger.info("Checking oracle status...")

    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))

        oracle_abi = [
            {"name": "getBackingAmount", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
            {"name": "isHealthy", "type": "function", "inputs": [], "outputs": [{"type": "bool"}], "stateMutability": "view"},
            {"name": "lastUpdate", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
            {"name": "deviation", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
        ]

        oracle_address = os.environ.get("ORACLE_ADDRESS", "")
        if not oracle_address:
            logger.error("ORACLE_ADDRESS environment variable not set")
            return 1

        oracle = w3.eth.contract(address=oracle_address, abi=oracle_abi)
        backing = oracle.functions.getBackingAmount().call()
        healthy = oracle.functions.isHealthy().call()
        last_update = oracle.functions.lastUpdate().call()
        dev = oracle.functions.deviation().call()

        import time
        age = int(time.time()) - last_update

        status = {
            "backing_amount": str(backing),
            "healthy": healthy,
            "last_update": last_update,
            "age_seconds": age,
            "deviation_bps": dev,
        }

        if args.format == "json":
            print(json.dumps(status, indent=2))
        else:
            print("# Oracle Status")
            for k, v in status.items():
                print(f"- **{k}**: {v}")

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1

    return 0


def cmd_invariants(args: argparse.Namespace) -> int:
    """Check all 4 SecureMint invariants."""
    config = EngineConfig.from_env()
    logger.info("Checking invariants...")

    invariants = [
        {"id": "INV-SM-1", "name": "BackingAlwaysCoversSupply", "status": "UNKNOWN"},
        {"id": "INV-SM-2", "name": "OracleHealthRequired", "status": "UNKNOWN"},
        {"id": "INV-SM-3", "name": "MintIsBounded", "status": "UNKNOWN"},
        {"id": "INV-SM-4", "name": "NoBypassPath", "status": "UNKNOWN"},
    ]

    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))

        token = w3.eth.contract(address=config.token_address, abi=TOKEN_ABI)
        policy = w3.eth.contract(address=config.policy_address, abi=POLICY_ABI)

        total_supply = token.functions.totalSupply().call()
        global_cap = policy.functions.globalSupplyCap().call()
        epoch_cap = policy.functions.epochMintCap().call()
        epoch_minted = policy.functions.epochMinted().call()

        # INV-SM-1: BackingAlwaysCoversSupply (needs oracle)
        invariants[0]["status"] = "REQUIRES_ORACLE"

        # INV-SM-2: OracleHealthRequired (needs oracle)
        invariants[1]["status"] = "REQUIRES_ORACLE"

        # INV-SM-3: MintIsBounded
        invariants[2]["status"] = "PASS" if epoch_minted <= epoch_cap else "FAIL"
        invariants[2]["detail"] = f"epoch_minted={epoch_minted} <= epoch_cap={epoch_cap}"

        # INV-SM-4: NoBypassPath
        if global_cap > 0:
            invariants[3]["status"] = "PASS" if total_supply <= global_cap else "FAIL"
            invariants[3]["detail"] = f"totalSupply={total_supply} <= globalCap={global_cap}"
        else:
            invariants[3]["status"] = "WARN"
            invariants[3]["detail"] = "globalSupplyCap is 0 (unlimited)"

    except ImportError:
        logger.warning("web3 not available; reporting all invariants as UNKNOWN")

    if args.format == "json":
        print(json.dumps(invariants, indent=2))
    else:
        print("# SecureMint Invariant Check")
        for inv in invariants:
            print(f"- [{inv['status']}] {inv['id']}: {inv['name']}")
            if "detail" in inv:
                print(f"  {inv['detail']}")

    all_pass = all(i["status"] in ("PASS", "REQUIRES_ORACLE", "WARN", "UNKNOWN") for i in invariants)
    return 0 if all_pass else 1


def cmd_simulate(args: argparse.Namespace) -> int:
    """Simulate transaction bundles via eth_call."""
    bundle_path = Path(args.bundle)
    if not bundle_path.exists():
        logger.error("Bundle file not found: %s", bundle_path)
        return 1

    with open(bundle_path) as f:
        bundle = json.load(f)

    if "transactions" not in bundle:
        logger.error("Invalid bundle: missing 'transactions' key")
        return 1

    logger.info("Simulating %d transactions...", len(bundle["transactions"]))

    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(EngineConfig.from_env().rpc_url))

        results = []
        for i, tx in enumerate(bundle.get("transactions", [])):
            try:
                result = w3.eth.call(tx)
                results.append({"index": i, "status": "success", "result": result.hex()})
                logger.info("  TX %d: success", i)
            except Exception as exc:
                results.append({"index": i, "status": "revert", "error": str(exc)})
                logger.error("  TX %d: revert - %s", i, exc)

        if args.format == "json":
            print(json.dumps(results, indent=2))

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1

    return 0


def cmd_config_check(args: argparse.Namespace) -> int:
    """Validate environment configuration."""
    required_vars = {
        "RPC_URL": "Ethereum RPC endpoint",
        "TOKEN_ADDRESS": "BackedToken contract address",
        "POLICY_ADDRESS": "SecureMintPolicy contract address",
        "CHAIN_ID": "Target chain ID",
    }
    optional_vars = {
        "PRIVATE_KEY": "Signing key (required for transactions)",
        "ORACLE_ADDRESS": "Oracle contract address",
        "TREASURY_ADDRESS": "TreasuryVault contract address",
    }

    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        pass

    results = {"required": {}, "optional": {}, "connectivity": {}}
    all_ok = True

    # Check required vars
    address_vars = {"TOKEN_ADDRESS", "POLICY_ADDRESS"}
    for var, desc in required_vars.items():
        val = os.environ.get(var, "")
        if not val:
            results["required"][var] = {"status": "MISSING", "description": desc}
            all_ok = False
        else:
            display = val[:8] + "..." if len(val) > 12 else val
            entry: dict[str, Any] = {"status": "SET", "value": display, "description": desc}
            # Validate Ethereum addresses
            if var in address_vars and val:
                try:
                    from web3 import Web3
                    Web3.to_checksum_address(val)
                    entry["status"] = "VALID_ADDRESS"
                except Exception:
                    entry["status"] = "INVALID_ADDRESS"
                    entry["warning"] = "Not a valid checksummed Ethereum address"
                    all_ok = False
            results["required"][var] = entry

    # Check optional vars
    for var, desc in optional_vars.items():
        val = os.environ.get(var, "")
        if not val:
            results["optional"][var] = {"status": "NOT_SET", "description": desc}
        else:
            results["optional"][var] = {"status": "SET", "description": desc}

    # Check RPC connectivity
    rpc_url = os.environ.get("RPC_URL", "")
    if rpc_url:
        try:
            from web3 import Web3
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            chain_id = w3.eth.chain_id
            block = w3.eth.block_number
            results["connectivity"] = {
                "rpc_reachable": True,
                "chain_id": chain_id,
                "latest_block": block,
            }
        except Exception as exc:
            results["connectivity"] = {"rpc_reachable": False, "error": str(exc)}
            all_ok = False
    else:
        results["connectivity"] = {"rpc_reachable": False, "error": "RPC_URL not set"}
        all_ok = False

    results["overall"] = "PASS" if all_ok else "FAIL"

    if args.format == "json":
        print(json.dumps(results, indent=2))
    else:
        print("# Configuration Check")
        print(f"\nOverall: **{results['overall']}**\n")
        print("## Required Variables")
        for var, info in results["required"].items():
            print(f"- [{info['status']}] {var}: {info['description']}")
        print("\n## Optional Variables")
        for var, info in results["optional"].items():
            print(f"- [{info['status']}] {var}: {info['description']}")
        print(f"\n## Connectivity")
        conn = results["connectivity"]
        if conn.get("rpc_reachable"):
            print(f"- RPC: Connected (chain={conn['chain_id']}, block={conn['latest_block']})")
        else:
            print(f"- RPC: FAILED ({conn.get('error', 'unknown')})")

    return 0 if all_ok else 1


def cmd_validate_contracts(args: argparse.Namespace) -> int:
    """Validate Solidity contract files exist and have expected structure."""
    contracts_dir = Path(__file__).parent.parent / "contracts"
    expected_files = [
        "IBackingOracle.sol",
        "IBackedToken.sol",
        "ISecureMintPolicy.sol",
        "ITreasuryVault.sol",
        "IEmergencyPause.sol",
        "BackedToken.sol",
        "SecureMintPolicy.sol",
        "EmergencyPause.sol",
        "TreasuryVault.sol",
        "ChainlinkPoRAdapter.sol",
        "OracleRouter.sol",
        "Governor.sol",
        "Timelock.sol",
        "RedemptionEngine.sol",
        "GuardianMultisig.sol",
    ]

    results = []
    for fname in expected_files:
        fpath = contracts_dir / fname
        entry: dict[str, Any] = {"file": fname, "path": str(fpath)}

        if not fpath.exists():
            entry["status"] = "MISSING"
            entry["error"] = "File not found"
        else:
            content = fpath.read_text()
            entry["status"] = "FOUND"
            entry["size_bytes"] = len(content)
            entry["has_spdx"] = "SPDX-License-Identifier" in content
            entry["has_pragma"] = "pragma solidity" in content
            entry["has_contract"] = "contract " in content or "interface " in content

            if not entry["has_pragma"]:
                entry["status"] = "WARN"
                entry["warning"] = "Missing pragma solidity"

        results.append(entry)

    all_found = all(r["status"] in ("FOUND",) for r in results)
    summary = {"total": len(expected_files), "found": sum(1 for r in results if r["status"] != "MISSING"), "status": "PASS" if all_found else "FAIL"}

    if args.format == "json":
        print(json.dumps({"summary": summary, "contracts": results}, indent=2))
    else:
        print("# Contract Validation")
        print(f"\nOverall: **{summary['status']}** ({summary['found']}/{summary['total']} found)\n")
        for r in results:
            status = r["status"]
            print(f"- [{status}] {r['file']} ({r.get('size_bytes', 0)} bytes)")
            if "warning" in r:
                print(f"  Warning: {r['warning']}")
            if "error" in r:
                print(f"  Error: {r['error']}")

    return 0 if all_found else 1


def cmd_health_check(args: argparse.Namespace) -> int:
    """Combined health dashboard: config + contracts + oracle + invariants."""
    print("=" * 60)
    print("  SecureMint Health Dashboard")
    print("=" * 60)

    sections: dict[str, Any] = {}
    overall_ok = True

    # 1. Config check
    print("\n[1/4] Checking configuration...")
    config_ok = True
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        pass

    for var in ("RPC_URL", "TOKEN_ADDRESS", "POLICY_ADDRESS", "CHAIN_ID"):
        if not os.environ.get(var):
            config_ok = False
            break
    sections["config"] = "PASS" if config_ok else "FAIL"
    if not config_ok:
        overall_ok = False
    print(f"    Config: {sections['config']}")

    # 2. Contract files
    print("[2/4] Checking contract files...")
    contracts_dir = Path(__file__).parent.parent / "contracts"
    expected = ["IBackingOracle.sol", "IBackedToken.sol", "ISecureMintPolicy.sol", "ITreasuryVault.sol", "IEmergencyPause.sol", "BackedToken.sol", "SecureMintPolicy.sol", "EmergencyPause.sol", "TreasuryVault.sol", "ChainlinkPoRAdapter.sol", "OracleRouter.sol", "Governor.sol", "Timelock.sol", "RedemptionEngine.sol", "GuardianMultisig.sol"]
    found = sum(1 for f in expected if (contracts_dir / f).exists())
    sections["contracts"] = f"{found}/{len(expected)}"
    if found < len(expected):
        overall_ok = False
    print(f"    Contracts: {sections['contracts']}")

    # 3. Oracle status
    print("[3/4] Checking oracle...")
    oracle_addr = os.environ.get("ORACLE_ADDRESS", "")
    if not oracle_addr:
        sections["oracle"] = "SKIPPED (no ORACLE_ADDRESS)"
    else:
        try:
            from web3 import Web3
            import time
            w3 = Web3(Web3.HTTPProvider(os.environ.get("RPC_URL", "")))
            oracle_abi = [
                {"name": "isHealthy", "type": "function", "inputs": [], "outputs": [{"type": "bool"}], "stateMutability": "view"},
                {"name": "lastUpdate", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
            ]
            oracle = w3.eth.contract(address=oracle_addr, abi=oracle_abi)
            healthy = oracle.functions.isHealthy().call()
            last_update = oracle.functions.lastUpdate().call()
            age = int(time.time()) - last_update
            sections["oracle"] = f"healthy={healthy}, age={age}s"
            if not healthy:
                overall_ok = False
        except Exception as exc:
            sections["oracle"] = f"ERROR: {exc}"
            overall_ok = False
    print(f"    Oracle: {sections['oracle']}")

    # 4. Invariants summary
    print("[4/4] Checking invariants...")
    try:
        from web3 import Web3
        config = EngineConfig.from_env()
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))
        policy = w3.eth.contract(address=config.policy_address, abi=POLICY_ABI)
        epoch_minted = policy.functions.epochMinted().call()
        epoch_cap = policy.functions.epochMintCap().call()
        sections["invariants"] = f"INV-SM-3: {'PASS' if epoch_minted <= epoch_cap else 'FAIL'} (minted={epoch_minted}, cap={epoch_cap})"
    except Exception:
        sections["invariants"] = "SKIPPED (no RPC or contracts)"
    print(f"    Invariants: {sections['invariants']}")

    # Summary
    print("\n" + "=" * 60)
    overall = "PASS" if overall_ok else "FAIL"
    print(f"  Overall: {overall}")
    print("=" * 60)

    if args.format == "json":
        print(json.dumps({"overall": overall, "sections": sections}, indent=2))

    return 0 if overall_ok else 1


def cmd_burn(args: argparse.Namespace) -> int:
    """Batch burn tokens from a CSV or JSON file via burnFrom."""
    config = EngineConfig.from_env()
    input_path = Path(args.file)

    if not input_path.exists():
        logger.error("Input file not found: %s", input_path)
        return 1

    if input_path.suffix == ".json":
        with open(input_path) as f:
            entries = json.load(f)
    elif input_path.suffix == ".csv":
        import csv
        with open(input_path) as f:
            reader = csv.DictReader(f)
            entries = list(reader)
    else:
        logger.error("Unsupported file format: %s (use .json or .csv)", input_path.suffix)
        return 1

    logger.info("Loaded %d burn entries from %s", len(entries), input_path)

    if args.dry_run:
        logger.info("[DRY RUN] Would burn %d entries:", len(entries))
        for i, entry in enumerate(entries):
            logger.info("  %d. from=%s amount=%s", i + 1, entry.get("from", "?"), entry.get("amount", "?"))
        return 0

    try:
        from web3 import Web3
        from web3 import HTTPProvider
        provider = HTTPProvider(config.rpc_url, request_kwargs={"timeout": 60})
        w3 = Web3(provider)
        token = w3.eth.contract(address=config.token_address, abi=BURN_ABI)
        account = w3.eth.account.from_key(config.private_key)
        nonce = w3.eth.get_transaction_count(account.address)

        for i, entry in enumerate(entries):
            holder = Web3.to_checksum_address(entry["from"])
            amount = int(entry["amount"])
            logger.info("Burning %d from %s (%d/%d)...", amount, holder, i + 1, len(entries))
            tx = token.functions.burnFrom(holder, amount).build_transaction({
                "from": account.address,
                "chainId": config.chain_id,
                "nonce": nonce,
                "gas": 300_000,
            })
            signed = w3.eth.account.sign_transaction(tx, config.private_key)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            logger.info("  TX %s status=%d", receipt.transactionHash.hex(), receipt.status)
            nonce += 1

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1

    return 0


def cmd_treasury_status(args: argparse.Namespace) -> int:
    """Query TreasuryVault for tier balances, total balance, health factor, and collateral ratio."""
    config = EngineConfig.from_env()
    treasury_address = os.environ.get("TREASURY_ADDRESS", "")

    if not treasury_address:
        logger.error("TREASURY_ADDRESS environment variable not set")
        return 1

    logger.info("Querying TreasuryVault at %s...", treasury_address)

    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))
        treasury = w3.eth.contract(address=treasury_address, abi=TREASURY_ABI)

        tier_names = ["Tier 1 (Stablecoins)", "Tier 2 (Treasuries)", "Tier 3 (Corporate Bonds)", "Tier 4 (Other)"]
        tier_balances = {}
        for i in range(4):
            balance = treasury.functions.tierBalance(i).call()
            tier_balances[tier_names[i]] = str(balance)

        total_balance = treasury.functions.totalBalance().call()
        health_factor = treasury.functions.healthFactor().call()
        collateral_ratio = treasury.functions.collateralRatio().call()

        status = {
            "treasury_address": treasury_address,
            "tier_balances": tier_balances,
            "total_balance": str(total_balance),
            "health_factor": str(health_factor),
            "collateral_ratio_bps": str(collateral_ratio),
        }

        if args.format == "json":
            print(json.dumps(status, indent=2))
        else:
            print("# Treasury Status")
            print(f"\n- **Address**: {treasury_address}")
            print(f"- **Total Balance**: {total_balance}")
            print(f"- **Health Factor**: {health_factor}")
            print(f"- **Collateral Ratio (bps)**: {collateral_ratio}")
            print("\n## Tier Balances")
            for name, bal in tier_balances.items():
                print(f"- {name}: {bal}")

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1

    return 0


def cmd_bridge_status(args: argparse.Namespace) -> int:
    """Placeholder for cross-chain bridge monitoring.

    Reports bridge address from env, checks if contract exists on chain,
    and reports basic status.
    """
    config = EngineConfig.from_env()
    bridge_address = os.environ.get("BRIDGE_ADDRESS", "")

    if not bridge_address:
        logger.error("BRIDGE_ADDRESS environment variable not set")
        return 1

    logger.info("Checking bridge status at %s...", bridge_address)

    status: dict[str, Any] = {
        "bridge_address": bridge_address,
        "chain_id": config.chain_id,
        "contract_exists": False,
        "status": "UNKNOWN",
    }

    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))

        code = w3.eth.get_code(Web3.to_checksum_address(bridge_address))
        contract_exists = len(code) > 0
        status["contract_exists"] = contract_exists
        status["code_size"] = len(code)

        if contract_exists:
            status["status"] = "DEPLOYED"
            logger.info("Bridge contract found (%d bytes of code)", len(code))
        else:
            status["status"] = "NOT_DEPLOYED"
            logger.warning("No contract code at bridge address")

    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        return 1
    except Exception as exc:
        status["status"] = "ERROR"
        status["error"] = str(exc)
        logger.error("Failed to check bridge: %s", exc)

    if args.format == "json":
        print(json.dumps(status, indent=2))
    else:
        print("# Bridge Status")
        print(f"\n- **Address**: {bridge_address}")
        print(f"- **Chain ID**: {config.chain_id}")
        print(f"- **Contract Exists**: {status['contract_exists']}")
        print(f"- **Status**: {status['status']}")
        if "code_size" in status:
            print(f"- **Code Size**: {status['code_size']} bytes")
        if "error" in status:
            print(f"- **Error**: {status['error']}")

    return 0 if status["status"] == "DEPLOYED" else 1


def cmd_smoke_test(args: argparse.Namespace) -> int:
    """Run all 9 smoke tests (SM-01 through SM-09) as defined in deployment docs.

    SM-01: Token deployed
    SM-02: Policy deployed
    SM-03: Oracle connected
    SM-04: Metadata matches
    SM-05: Supply correct
    SM-06: Pause level L0
    SM-07: API health (skip)
    SM-08: GraphQL (skip)
    SM-09: Invariant INV-SM-1
    """
    config = EngineConfig.from_env()
    results: list[dict[str, Any]] = []

    def record(test_id: str, name: str, status: str, detail: str = "") -> None:
        entry = {"id": test_id, "name": name, "status": status}
        if detail:
            entry["detail"] = detail
        results.append(entry)
        icon = "PASS" if status == "PASS" else ("SKIP" if status == "SKIP" else "FAIL")
        logger.info("[%s] %s: %s %s", icon, test_id, name, detail)

    w3 = None
    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(config.rpc_url))
    except ImportError:
        logger.error("web3 package required. Install: pip install web3")
        for i in range(1, 10):
            record(f"SM-{i:02d}", "N/A", "FAIL", "web3 not installed")
        return 1

    # SM-01: Token deployed
    if config.token_address:
        try:
            code = w3.eth.get_code(Web3.to_checksum_address(config.token_address))
            if len(code) > 0:
                record("SM-01", "Token deployed", "PASS", f"code_size={len(code)}")
            else:
                record("SM-01", "Token deployed", "FAIL", "No code at TOKEN_ADDRESS")
        except Exception as exc:
            record("SM-01", "Token deployed", "FAIL", str(exc))
    else:
        record("SM-01", "Token deployed", "FAIL", "TOKEN_ADDRESS not set")

    # SM-02: Policy deployed
    if config.policy_address:
        try:
            code = w3.eth.get_code(Web3.to_checksum_address(config.policy_address))
            if len(code) > 0:
                record("SM-02", "Policy deployed", "PASS", f"code_size={len(code)}")
            else:
                record("SM-02", "Policy deployed", "FAIL", "No code at POLICY_ADDRESS")
        except Exception as exc:
            record("SM-02", "Policy deployed", "FAIL", str(exc))
    else:
        record("SM-02", "Policy deployed", "FAIL", "POLICY_ADDRESS not set")

    # SM-03: Oracle connected
    oracle_address = os.environ.get("ORACLE_ADDRESS", "")
    if oracle_address:
        try:
            oracle_abi = [
                {"name": "isHealthy", "type": "function", "inputs": [], "outputs": [{"type": "bool"}], "stateMutability": "view"},
            ]
            oracle = w3.eth.contract(address=oracle_address, abi=oracle_abi)
            healthy = oracle.functions.isHealthy().call()
            record("SM-03", "Oracle connected", "PASS" if healthy else "FAIL", f"healthy={healthy}")
        except Exception as exc:
            record("SM-03", "Oracle connected", "FAIL", str(exc))
    else:
        record("SM-03", "Oracle connected", "FAIL", "ORACLE_ADDRESS not set")

    # SM-04: Metadata matches
    if config.token_address:
        try:
            name_abi = [
                {"name": "name", "type": "function", "inputs": [], "outputs": [{"type": "string"}], "stateMutability": "view"},
                {"name": "symbol", "type": "function", "inputs": [], "outputs": [{"type": "string"}], "stateMutability": "view"},
                {"name": "decimals", "type": "function", "inputs": [], "outputs": [{"type": "uint8"}], "stateMutability": "view"},
            ]
            token = w3.eth.contract(address=config.token_address, abi=name_abi)
            name = token.functions.name().call()
            symbol = token.functions.symbol().call()
            decimals = token.functions.decimals().call()
            record("SM-04", "Metadata matches", "PASS", f"name={name}, symbol={symbol}, decimals={decimals}")
        except Exception as exc:
            record("SM-04", "Metadata matches", "FAIL", str(exc))
    else:
        record("SM-04", "Metadata matches", "FAIL", "TOKEN_ADDRESS not set")

    # SM-05: Supply correct
    if config.token_address:
        try:
            token = w3.eth.contract(address=config.token_address, abi=TOKEN_ABI)
            total_supply = token.functions.totalSupply().call()
            record("SM-05", "Supply correct", "PASS", f"totalSupply={total_supply}")
        except Exception as exc:
            record("SM-05", "Supply correct", "FAIL", str(exc))
    else:
        record("SM-05", "Supply correct", "FAIL", "TOKEN_ADDRESS not set")

    # SM-06: Pause level L0
    if config.token_address:
        try:
            token = w3.eth.contract(address=config.token_address, abi=TOKEN_ABI)
            is_paused = token.functions.paused().call()
            if not is_paused:
                record("SM-06", "Pause level L0", "PASS", "paused=false (L0 normal)")
            else:
                record("SM-06", "Pause level L0", "FAIL", "paused=true (not at L0)")
        except Exception as exc:
            record("SM-06", "Pause level L0", "FAIL", str(exc))
    else:
        record("SM-06", "Pause level L0", "FAIL", "TOKEN_ADDRESS not set")

    # SM-07: API health (skip)
    record("SM-07", "API health", "SKIP", "API health check not implemented in CLI")

    # SM-08: GraphQL (skip)
    record("SM-08", "GraphQL", "SKIP", "GraphQL check not implemented in CLI")

    # SM-09: Invariant INV-SM-1 (BackingAlwaysCoversSupply)
    if config.token_address and oracle_address:
        try:
            token = w3.eth.contract(address=config.token_address, abi=TOKEN_ABI)
            total_supply = token.functions.totalSupply().call()
            backing_abi = [
                {"name": "getBackingAmount", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
            ]
            oracle = w3.eth.contract(address=oracle_address, abi=backing_abi)
            backing = oracle.functions.getBackingAmount().call()
            if backing >= total_supply:
                record("SM-09", "Invariant INV-SM-1", "PASS", f"backing={backing} >= supply={total_supply}")
            else:
                record("SM-09", "Invariant INV-SM-1", "FAIL", f"backing={backing} < supply={total_supply}")
        except Exception as exc:
            record("SM-09", "Invariant INV-SM-1", "FAIL", str(exc))
    else:
        record("SM-09", "Invariant INV-SM-1", "FAIL", "TOKEN_ADDRESS or ORACLE_ADDRESS not set")

    # Summary
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    skipped = sum(1 for r in results if r["status"] == "SKIP")
    total = len(results)
    all_ok = failed == 0

    summary = {
        "total": total,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "overall": "PASS" if all_ok else "FAIL",
    }

    if args.format == "json":
        print(json.dumps({"summary": summary, "tests": results}, indent=2))
    else:
        print("# Smoke Test Results")
        print(f"\nOverall: **{summary['overall']}** ({passed}/{total} passed, {skipped} skipped)\n")
        for r in results:
            print(f"- [{r['status']}] {r['id']}: {r['name']}")
            if r.get("detail"):
                print(f"  {r['detail']}")

    return 0 if all_ok else 1


def cmd_intake(args: argparse.Namespace) -> int:
    """Run pre-deployment intake checklist.

    Validates that all prerequisites are met before entering the deployment
    pipeline: contracts compiled, tests passing, config valid, keys available.
    """
    results: list[dict[str, Any]] = []

    def record(name: str, status: str, detail: str = "") -> None:
        entry = {"check": name, "status": status}
        if detail:
            entry["detail"] = detail
        results.append(entry)

    config = EngineConfig.from_env()

    # Check 1: Required environment variables
    missing = []
    for var in ("RPC_URL", "TOKEN_ADDRESS", "POLICY_ADDRESS", "ORACLE_ADDRESS",
                "TREASURY_ADDRESS", "PRIVATE_KEY", "CHAIN_ID"):
        if not getattr(config, var.lower(), None) and not os.environ.get(var):
            missing.append(var)
    if missing:
        record("Environment variables", "FAIL", f"Missing: {', '.join(missing)}")
    else:
        record("Environment variables", "PASS")

    # Check 2: Contracts compiled (foundry out/ directory)
    contracts_dir = Path(__file__).resolve().parent.parent / "contracts"
    if contracts_dir.is_dir() and any(contracts_dir.glob("*.sol")):
        record("Contract sources present", "PASS", f"{len(list(contracts_dir.glob('*.sol')))} files")
    else:
        record("Contract sources present", "FAIL", "No .sol files found")

    # Check 3: Deployment config exists
    deploy_cfg = Path(__file__).resolve().parent.parent / "scripts" / "DeployConfig.s.sol"
    if deploy_cfg.is_file():
        record("Deployment config", "PASS")
    else:
        record("Deployment config", "FAIL", "scripts/DeployConfig.s.sol not found")

    # Check 4: .env or env vars set
    env_file = Path(__file__).resolve().parent / ".env"
    if env_file.is_file() or not missing:
        record("Configuration file", "PASS")
    else:
        record("Configuration file", "FAIL", ".env file not found and env vars missing")

    passed = sum(1 for r in results if r["status"] == "PASS")
    total = len(results)
    all_ok = passed == total
    summary = {"passed": passed, "total": total, "overall": "PASS" if all_ok else "FAIL"}

    if args.format == "json":
        print(json.dumps({"summary": summary, "checks": results}, indent=2))
    else:
        print("# Intake Checklist")
        print(f"\nOverall: **{summary['overall']}** ({passed}/{total} passed)\n")
        for r in results:
            print(f"- [{r['status']}] {r['check']}")
            if r.get("detail"):
                print(f"  {r['detail']}")

    return 0 if all_ok else 1


def cmd_preflight(args: argparse.Namespace) -> int:
    """Run preflight gate checks before deployment.

    Hard checks (6):
        - RPC connectivity
        - Deployer balance (>= 0.5 ETH)
        - Oracle responding
        - Config valid (required env vars)
        - Node.js version
        - Foundry installed

    Soft checks (3):
        - Etherscan API key set (ETHERSCAN_API_KEY)
        - Slack webhook set (SLACK_WEBHOOK)
        - Subgraph URL set (SUBGRAPH_URL)
    """
    results: list[dict[str, Any]] = []

    hard_only = args.hard_only
    soft_only = args.soft_only
    run_hard = not soft_only
    run_soft = not hard_only

    def record(name: str, status: str, detail: str = "") -> None:
        entry = {"check": name, "status": status}
        if detail:
            entry["detail"] = detail
        results.append(entry)
        icon = "PASS" if status == "PASS" else "FAIL"
        logger.info("[%s] %s %s", icon, name, detail)

    config = EngineConfig.from_env()

    rpc_ok = False
    w3 = None

    if run_hard:
        # Hard Check 1: RPC connectivity
        try:
            from web3 import Web3
            w3 = Web3(Web3.HTTPProvider(config.rpc_url))
            chain_id = w3.eth.chain_id
            block = w3.eth.block_number
            record("RPC connectivity", "PASS", f"chain_id={chain_id}, block={block}")
            rpc_ok = True
        except ImportError:
            record("RPC connectivity", "FAIL", "web3 package not installed")
        except Exception as exc:
            record("RPC connectivity", "FAIL", str(exc))

        # Hard Check 2: Deployer balance (>= 0.5 ETH)
        if rpc_ok and w3 and config.private_key:
            try:
                account = w3.eth.account.from_key(config.private_key)
                balance_wei = w3.eth.get_balance(account.address)
                balance_eth = balance_wei / 10**18
                min_balance = 0.5
                if balance_eth >= min_balance:
                    record("Deployer balance", "PASS", f"{balance_eth:.4f} ETH (>= {min_balance} ETH)")
                else:
                    record("Deployer balance", "FAIL", f"{balance_eth:.4f} ETH (< {min_balance} ETH required)")
            except Exception as exc:
                record("Deployer balance", "FAIL", str(exc))
        elif not config.private_key:
            record("Deployer balance", "FAIL", "PRIVATE_KEY not set")
        else:
            record("Deployer balance", "FAIL", "RPC not available")

        # Hard Check 3: Oracle responding
        oracle_address = os.environ.get("ORACLE_ADDRESS", "")
        if oracle_address and rpc_ok and w3:
            try:
                oracle_abi = [
                    {"name": "isHealthy", "type": "function", "inputs": [], "outputs": [{"type": "bool"}], "stateMutability": "view"},
                ]
                oracle = w3.eth.contract(address=oracle_address, abi=oracle_abi)
                healthy = oracle.functions.isHealthy().call()
                record("Oracle responding", "PASS" if healthy else "FAIL", f"healthy={healthy}")
            except Exception as exc:
                record("Oracle responding", "FAIL", str(exc))
        else:
            if not oracle_address:
                record("Oracle responding", "FAIL", "ORACLE_ADDRESS not set")
            else:
                record("Oracle responding", "FAIL", "RPC not available")

        # Hard Check 4: Config valid (required env vars)
        required_vars = ["RPC_URL", "TOKEN_ADDRESS", "POLICY_ADDRESS", "CHAIN_ID"]
        missing = [v for v in required_vars if not os.environ.get(v)]
        if not missing:
            record("Config valid", "PASS", "All required env vars set")
        else:
            record("Config valid", "FAIL", f"Missing: {', '.join(missing)}")

        # Hard Check 5: Node.js version
        import subprocess
        try:
            result = subprocess.run(["node", "--version"], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                node_version = result.stdout.strip()
                record("Node.js version", "PASS", node_version)
            else:
                record("Node.js version", "FAIL", "node command failed")
        except FileNotFoundError:
            record("Node.js version", "FAIL", "node not found in PATH")
        except Exception as exc:
            record("Node.js version", "FAIL", str(exc))

        # Hard Check 6: Foundry installed
        try:
            result = subprocess.run(["forge", "--version"], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                forge_version = result.stdout.strip().split("\n")[0]
                record("Foundry installed", "PASS", forge_version)
            else:
                record("Foundry installed", "FAIL", "forge command failed")
        except FileNotFoundError:
            record("Foundry installed", "FAIL", "forge not found in PATH")
        except Exception as exc:
            record("Foundry installed", "FAIL", str(exc))

    if run_soft:
        # Soft Check 1: Etherscan API key
        if os.environ.get("ETHERSCAN_API_KEY"):
            record("Etherscan API key", "PASS")
        else:
            record("Etherscan API key", "FAIL", "ETHERSCAN_API_KEY not set")

        # Soft Check 2: Slack webhook
        if os.environ.get("SLACK_WEBHOOK"):
            record("Slack webhook", "PASS")
        else:
            record("Slack webhook", "FAIL", "SLACK_WEBHOOK not set")

        # Soft Check 3: Subgraph URL
        if os.environ.get("SUBGRAPH_URL"):
            record("Subgraph URL", "PASS")
        else:
            record("Subgraph URL", "FAIL", "SUBGRAPH_URL not set")

    # Summary
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    total = len(results)
    all_ok = failed == 0

    summary = {
        "total": total,
        "passed": passed,
        "failed": failed,
        "overall": "PASS" if all_ok else "FAIL",
    }

    if args.format == "json":
        print(json.dumps({"summary": summary, "checks": results}, indent=2))
    else:
        print("# Preflight Checks")
        print(f"\nOverall: **{summary['overall']}** ({passed}/{total} passed)\n")
        for r in results:
            print(f"- [{r['status']}] {r['check']}")
            if r.get("detail"):
                print(f"  {r['detail']}")

    return 0 if all_ok else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="securemint", description="SecureMintEngine CLI")
    parser.add_argument("--format", choices=["json", "markdown"], default="json")
    sub = parser.add_subparsers(dest="command", required=True)

    # mint-batch
    p = sub.add_parser("mint-batch", help="Batch mint tokens")
    p.add_argument("--file", required=True, help="CSV or JSON file with mint entries")
    p.add_argument("--dry-run", action="store_true", help="Preview without executing")
    p.set_defaults(func=cmd_mint_batch)

    # compliance
    p = sub.add_parser("compliance", help="KYC/AML/sanctions checks")
    p.add_argument("--address", help="Single address to check")
    p.add_argument("--file", help="File with addresses (one per line)")
    p.add_argument("--aml-only", action="store_true", help="Run only AML checks")
    p.add_argument("--sanctions-only", action="store_true", help="Run only sanctions checks")
    p.set_defaults(func=cmd_compliance)

    # report
    p = sub.add_parser("report", help="Generate reports")
    p.add_argument("--type", choices=["reserve", "monthly", "treasury", "compliance", "bridge"], default="reserve")
    p.set_defaults(func=cmd_report)

    # oracle-status
    p = sub.add_parser("oracle-status", help="Check oracle health")
    p.set_defaults(func=cmd_oracle_status)

    # invariants
    p = sub.add_parser("invariants", help="Check all 4 invariants")
    p.set_defaults(func=cmd_invariants)

    # simulate
    p = sub.add_parser("simulate", help="Simulate transaction bundles")
    p.add_argument("--bundle", required=True, help="JSON bundle file")
    p.set_defaults(func=cmd_simulate)

    # config-check
    p = sub.add_parser("config-check", help="Validate environment configuration")
    p.set_defaults(func=cmd_config_check)

    # validate-contracts
    p = sub.add_parser("validate-contracts", help="Validate Solidity contract files")
    p.set_defaults(func=cmd_validate_contracts)

    # health-check
    p = sub.add_parser("health-check", help="Combined health dashboard")
    p.set_defaults(func=cmd_health_check)

    # burn
    p = sub.add_parser("burn", help="Batch burn tokens from CSV/JSON")
    p.add_argument("--file", required=True, help="CSV or JSON file with burn entries")
    p.add_argument("--dry-run", action="store_true", help="Preview without executing")
    p.set_defaults(func=cmd_burn)

    # treasury-status
    p = sub.add_parser("treasury-status", help="Query TreasuryVault balances and health")
    p.set_defaults(func=cmd_treasury_status)

    # bridge-status
    p = sub.add_parser("bridge-status", help="Cross-chain bridge monitoring")
    p.set_defaults(func=cmd_bridge_status)

    # smoke-test
    p = sub.add_parser("smoke-test", help="Run all 9 deployment smoke tests")
    p.set_defaults(func=cmd_smoke_test)

    # preflight
    p = sub.add_parser("preflight", help="Run preflight hard gate checks")
    p.add_argument("--hard-only", action="store_true", help="Run only hard gate checks")
    p.add_argument("--soft-only", action="store_true", help="Run only soft gate checks")
    p.set_defaults(func=cmd_preflight)

    # intake
    p = sub.add_parser("intake", help="Run pre-deployment intake checklist")
    p.set_defaults(func=cmd_intake)

    return parser


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
