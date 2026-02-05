#!/usr/bin/env python3
"""
monetary_routing_ci_check.py -- CI guardrail for SecureMintEngine routing consistency.

Reads PROJECT_CONTEXT.json and validates that declared routing tags are consistent
with the project's monetary configuration.

Routing Rules
-------------
1. stablecoin_backed == true OR backing_type != "none"  --> [ROUTE:SECURE_MINT]
2. emissions_schedule != "none"                         --> [ROUTE:EMISSIONS]
3. cross_chain_required == true                         --> [ROUTE:CROSS_CHAIN]
4. minting_required == false                            --> [ROUTE:FIXED]
5. chain == "solana" AND token_type in memecoin types   --> [ROUTE:MEMECOIN]

Exit Codes
----------
0  All routing rules satisfied.
1  One or more routing mismatches detected.

Usage
-----
    python3 monetary_routing_ci_check.py
    python3 monetary_routing_ci_check.py --config path/to/context.json --output reports/ --strict
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import textwrap
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = SCRIPT_DIR.parent / "intake" / "PROJECT_CONTEXT.json"
DEFAULT_OUTPUT_DIR = SCRIPT_DIR.parent / "outputs"

REQUIRED_TOP_LEVEL_KEYS = {"project_name", "token_type", "chain", "routes"}
KNOWN_ROUTES = {"SECURE_MINT", "EMISSIONS", "CROSS_CHAIN", "FIXED", "MEMECOIN"}
MEMECOIN_TOKEN_TYPES = {"memecoin", "meme", "fixed_supply"}

logger = logging.getLogger("routing_ci")


@dataclass
class RoutingViolation:
    rule_id: int
    rule_description: str
    expected_route: str
    context: dict[str, Any] = field(default_factory=dict)

    def as_markdown(self) -> str:
        ctx_lines = "\n".join(f"  - **{k}**: `{v}`" for k, v in self.context.items())
        return (
            f"- **Rule {self.rule_id}** -- {self.rule_description}\n"
            f"  - Missing route: `[ROUTE:{self.expected_route}]`\n"
            f"{ctx_lines}"
        )


@dataclass
class ValidationResult:
    violations: list[RoutingViolation] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    routes_present: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return len(self.violations) == 0


def validate_schema(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for key in REQUIRED_TOP_LEVEL_KEYS:
        if key not in config:
            errors.append(f"Missing required key: '{key}'")
    if "routes" in config:
        routes = config["routes"]
        if not isinstance(routes, list):
            errors.append("'routes' must be a list of route tag strings")
        else:
            for route in routes:
                if not isinstance(route, str):
                    errors.append(f"Route entry must be a string, got {type(route).__name__}: {route!r}")
    return errors


def normalise_route(tag: str) -> str:
    tag = tag.strip().upper()
    tag = tag.lstrip("[").rstrip("]")
    if tag.startswith("ROUTE:"):
        tag = tag[len("ROUTE:"):]
    return tag


def normalise_routes(routes: list[str]) -> set[str]:
    return {normalise_route(r) for r in routes}


def check_routing_rules(config: dict[str, Any]) -> ValidationResult:
    result = ValidationResult()
    raw_routes: list[str] = config.get("routes", [])
    routes: set[str] = normalise_routes(raw_routes)
    result.routes_present = sorted(routes)

    unknown = routes - KNOWN_ROUTES
    for unk in sorted(unknown):
        result.warnings.append(f"Unknown route tag: '{unk}' (not in {sorted(KNOWN_ROUTES)})")

    # Rule 1: stablecoin_backed or backing_type != "none" --> SECURE_MINT
    stablecoin_backed = config.get("stablecoin_backed", False)
    backing_type = str(config.get("backing_type", "none")).lower()
    if stablecoin_backed or backing_type != "none":
        if "SECURE_MINT" not in routes:
            result.violations.append(RoutingViolation(
                rule_id=1,
                rule_description="stablecoin_backed is true or backing_type is not 'none' -- requires [ROUTE:SECURE_MINT]",
                expected_route="SECURE_MINT",
                context={"stablecoin_backed": stablecoin_backed, "backing_type": backing_type},
            ))

    # Rule 2: emissions_schedule != "none" --> EMISSIONS
    emissions_schedule = str(config.get("emissions_schedule", "none")).lower()
    if emissions_schedule != "none":
        if "EMISSIONS" not in routes:
            result.violations.append(RoutingViolation(
                rule_id=2,
                rule_description="emissions_schedule is not 'none' -- requires [ROUTE:EMISSIONS]",
                expected_route="EMISSIONS",
                context={"emissions_schedule": emissions_schedule},
            ))

    # Rule 3: cross_chain_required == true --> CROSS_CHAIN
    cross_chain_required = config.get("cross_chain_required", False)
    if cross_chain_required:
        if "CROSS_CHAIN" not in routes:
            result.violations.append(RoutingViolation(
                rule_id=3,
                rule_description="cross_chain_required is true -- requires [ROUTE:CROSS_CHAIN]",
                expected_route="CROSS_CHAIN",
                context={"cross_chain_required": cross_chain_required},
            ))

    # Rule 4: minting_required == false --> FIXED
    minting_required = config.get("minting_required", True)
    if not minting_required:
        if "FIXED" not in routes:
            result.violations.append(RoutingViolation(
                rule_id=4,
                rule_description="minting_required is false -- requires [ROUTE:FIXED]",
                expected_route="FIXED",
                context={"minting_required": minting_required},
            ))

    # Rule 5: chain == "solana" and token_type in memecoin types --> MEMECOIN
    chain = str(config.get("chain", "")).lower()
    token_type = str(config.get("token_type", "")).lower()
    if chain == "solana" and token_type in MEMECOIN_TOKEN_TYPES:
        if "MEMECOIN" not in routes:
            result.violations.append(RoutingViolation(
                rule_id=5,
                rule_description="chain is 'solana' and token_type is memecoin variant -- requires [ROUTE:MEMECOIN]",
                expected_route="MEMECOIN",
                context={"chain": chain, "token_type": token_type},
            ))

    return result


def generate_report(config: dict[str, Any], result: ValidationResult, config_path: Path) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    project_name = config.get("project_name", "<unknown>")
    status = "PASS" if result.passed else "FAIL"

    sections: list[str] = []
    sections.append(textwrap.dedent(f"""\
        # Monetary Routing CI Report

        | Field          | Value                            |
        |----------------|----------------------------------|
        | **Project**    | {project_name}                   |
        | **Config**     | `{config_path}`                  |
        | **Timestamp**  | {now}                            |
        | **Status**     | **{status}**                     |
        | **Routes**     | {', '.join(result.routes_present) or '(none)'} |
    """))

    if result.violations:
        sections.append("## Violations\n")
        for v in result.violations:
            sections.append(v.as_markdown())
        sections.append("")
    else:
        sections.append("## Violations\n\nNone -- all routing rules are satisfied.\n")

    if result.warnings:
        sections.append("## Warnings\n")
        for w in result.warnings:
            sections.append(f"- {w}")
        sections.append("")

    sections.append(textwrap.dedent("""\
        ## Routing Rules Reference

        | # | Condition | Required Route |
        |---|-----------|---------------|
        | 1 | `stablecoin_backed` or `backing_type != "none"` | `[ROUTE:SECURE_MINT]` |
        | 2 | `emissions_schedule != "none"` | `[ROUTE:EMISSIONS]` |
        | 3 | `cross_chain_required == true` | `[ROUTE:CROSS_CHAIN]` |
        | 4 | `minting_required == false` | `[ROUTE:FIXED]` |
        | 5 | `chain == "solana"` and memecoin `token_type` | `[ROUTE:MEMECOIN]` |
    """))

    return "\n".join(sections)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="monetary_routing_ci_check",
        description="CI guardrail: validate SecureMintEngine routing consistency.",
    )
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help="Path to PROJECT_CONTEXT.json")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR, help="Directory for report output")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    parser.add_argument("--verbose", action="store_true", help="Enable DEBUG logging")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    config_path: Path = args.config.resolve()
    output_dir: Path = args.output.resolve()

    if not config_path.is_file():
        logger.error("Config file not found: %s", config_path)
        return 1

    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            config: dict[str, Any] = json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        logger.error("Could not read %s: %s", config_path, exc)
        return 1

    schema_errors = validate_schema(config)
    if schema_errors:
        for err in schema_errors:
            logger.error("Schema: %s", err)
        if args.strict:
            return 1

    result = check_routing_rules(config)

    for w in result.warnings:
        logger.warning("%s", w)

    if result.passed:
        logger.info("All routing rules PASSED. Routes: %s", result.routes_present)
    else:
        for v in result.violations:
            logger.error("VIOLATION Rule %d: %s (missing [ROUTE:%s])", v.rule_id, v.rule_description, v.expected_route)

    strict_fail = args.strict and (result.warnings or schema_errors)

    report = generate_report(config, result, config_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / "MonetaryRoutingCIReport.md"

    try:
        with open(report_path, "w", encoding="utf-8") as fh:
            fh.write(report)
        logger.info("Report written to %s", report_path)
    except OSError as exc:
        logger.error("Could not write report: %s", exc)
        return 1

    if not result.passed or strict_fail:
        logger.error("CI check FAILED.")
        return 1

    logger.info("CI check PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
