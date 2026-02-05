#!/usr/bin/env python3
"""Monetary Routing CI Check.

Validates PROJECT_CONTEXT.json and verifies that required contract files
exist for the declared money_mechanic_type.  Writes a markdown report to
outputs/MonetaryRoutingCIReport.md and exits 0 on success, 1 on failure.

This script uses only the Python standard library (no external deps).
It runs from the REPO ROOT, so all paths are relative to that.
"""

import json
import os
import sys
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CONTEXT_PATH = os.path.join("intake", "PROJECT_CONTEXT.json")
REPORT_DIR = "outputs"
REPORT_PATH = os.path.join(REPORT_DIR, "MonetaryRoutingCIReport.md")

VALID_MECHANIC_TYPES = {
    "stablecoin_backed",
    "algorithmic",
    "hybrid",
    "commodity_backed",
    "crypto_backed",
}

# Mechanic types that require a valid (non-"none") backing_type.
REQUIRES_BACKING = {
    "stablecoin_backed",
    "commodity_backed",
    "crypto_backed",
}

# Required contracts per mechanic type (paths relative to repo root).
REQUIRED_CONTRACTS: dict[str, list[str]] = {
    "stablecoin_backed": [
        "assets/contracts/BackedToken.sol",
        "assets/contracts/SecureMintPolicy.sol",
        "assets/contracts/ChainlinkPoRAdapter.sol",
        "assets/contracts/TreasuryVault.sol",
        "assets/contracts/EmergencyPause.sol",
    ],
    "algorithmic": [
        "assets/contracts/BackedToken.sol",
        "assets/contracts/SecureMintPolicy.sol",
        "assets/contracts/EmergencyPause.sol",
    ],
    "hybrid": [
        "assets/contracts/BackedToken.sol",
        "assets/contracts/SecureMintPolicy.sol",
        "assets/contracts/ChainlinkPoRAdapter.sol",
        "assets/contracts/TreasuryVault.sol",
        "assets/contracts/EmergencyPause.sol",
    ],
    "commodity_backed": [
        "assets/contracts/BackedToken.sol",
        "assets/contracts/SecureMintPolicy.sol",
        "assets/contracts/ChainlinkPoRAdapter.sol",
        "assets/contracts/TreasuryVault.sol",
        "assets/contracts/EmergencyPause.sol",
    ],
    "crypto_backed": [
        "assets/contracts/BackedToken.sol",
        "assets/contracts/SecureMintPolicy.sol",
        "assets/contracts/ChainlinkPoRAdapter.sol",
        "assets/contracts/TreasuryVault.sol",
        "assets/contracts/EmergencyPause.sol",
    ],
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def load_context() -> dict:
    """Load and return PROJECT_CONTEXT.json."""
    if not os.path.isfile(CONTEXT_PATH):
        raise FileNotFoundError(f"Context file not found: {CONTEXT_PATH}")
    with open(CONTEXT_PATH, "r", encoding="utf-8") as fh:
        return json.load(fh)


def validate_mechanic_type(ctx: dict) -> list[str]:
    """Return a list of error strings (empty if valid)."""
    errors: list[str] = []
    mechanic = ctx.get("money_mechanic_type")
    if mechanic is None:
        errors.append("Missing key: money_mechanic_type")
    elif mechanic not in VALID_MECHANIC_TYPES:
        errors.append(
            f"Invalid money_mechanic_type '{mechanic}'. "
            f"Valid types: {sorted(VALID_MECHANIC_TYPES)}"
        )
    return errors


def validate_backing_type(ctx: dict) -> list[str]:
    """Return a list of error strings (empty if valid)."""
    errors: list[str] = []
    mechanic = ctx.get("money_mechanic_type", "")
    backing = ctx.get("backing_type")
    if mechanic in REQUIRES_BACKING:
        if backing is None or str(backing).strip().lower() == "none":
            errors.append(
                f"money_mechanic_type '{mechanic}' requires a valid "
                f"backing_type (got '{backing}')"
            )
    return errors


def validate_contracts(ctx: dict) -> tuple[list[str], list[str]]:
    """Check that required contract files exist.

    Returns (missing, found) lists of file paths.
    """
    mechanic = ctx.get("money_mechanic_type", "")
    required = REQUIRED_CONTRACTS.get(mechanic, [])
    missing: list[str] = []
    found: list[str] = []
    for path in required:
        if os.path.isfile(path):
            found.append(path)
        else:
            missing.append(path)
    return missing, found


def write_report(
    ctx: dict,
    errors: list[str],
    missing_contracts: list[str],
    found_contracts: list[str],
) -> None:
    """Write the markdown CI report."""
    os.makedirs(REPORT_DIR, exist_ok=True)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    passed = len(errors) == 0 and len(missing_contracts) == 0
    status = "PASSED" if passed else "FAILED"

    lines: list[str] = [
        "# Monetary Routing CI Report",
        "",
        f"**Generated**: {now}",
        f"**Status**: {status}",
        "",
        "## Project Context",
        "",
        f"- `money_mechanic_type`: `{ctx.get('money_mechanic_type', 'N/A')}`",
        f"- `backing_type`: `{ctx.get('backing_type', 'N/A')}`",
        "",
    ]

    if errors:
        lines.append("## Validation Errors")
        lines.append("")
        for err in errors:
            lines.append(f"- {err}")
        lines.append("")

    if found_contracts:
        lines.append("## Contracts Found")
        lines.append("")
        for c in found_contracts:
            lines.append(f"- {c}")
        lines.append("")

    if missing_contracts:
        lines.append("## Missing Contracts")
        lines.append("")
        for c in missing_contracts:
            lines.append(f"- {c}")
        lines.append("")

    if passed:
        lines.append("All checks passed.")
    else:
        lines.append("One or more checks failed. See details above.")
    lines.append("")

    with open(REPORT_PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    try:
        ctx = load_context()
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        os.makedirs(REPORT_DIR, exist_ok=True)
        with open(REPORT_PATH, "w", encoding="utf-8") as fh:
            fh.write(f"# Monetary Routing CI Report\n\n**Status**: FAILED\n\nError: {exc}\n")
        return 1

    errors: list[str] = []
    errors.extend(validate_mechanic_type(ctx))
    errors.extend(validate_backing_type(ctx))

    missing_contracts, found_contracts = validate_contracts(ctx)
    if missing_contracts:
        errors.append(
            f"Missing {len(missing_contracts)} required contract(s): "
            + ", ".join(missing_contracts)
        )

    write_report(ctx, errors, missing_contracts, found_contracts)

    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1

    print("Monetary routing CI check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
