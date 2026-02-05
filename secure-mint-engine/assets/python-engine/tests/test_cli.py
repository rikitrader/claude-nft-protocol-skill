"""Tests for securemint_cli.py subcommands."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest import mock

import pytest

# Resolve the CLI script path relative to this test file
CLI_DIR = Path(__file__).resolve().parent.parent
CLI_SCRIPT = CLI_DIR / "securemint_cli.py"


def run_cli(*args: str, env_override: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    """Helper to invoke the CLI as a subprocess and capture output."""
    env = os.environ.copy()
    # Strip vars that might leak from the host environment
    for key in ("RPC_URL", "TOKEN_ADDRESS", "POLICY_ADDRESS", "CHAIN_ID",
                "PRIVATE_KEY", "ORACLE_ADDRESS", "TREASURY_ADDRESS", "BRIDGE_ADDRESS"):
        env.pop(key, None)
    if env_override:
        env.update(env_override)
    return subprocess.run(
        [sys.executable, str(CLI_SCRIPT), *args],
        capture_output=True,
        text=True,
        timeout=30,
        env=env,
    )


class TestBuildParser:
    """Verify that the argument parser knows about all expected subcommands."""

    def test_build_parser(self) -> None:
        # Import the module dynamically so tests work without web3 installed
        sys.path.insert(0, str(CLI_DIR))
        try:
            import securemint_cli
            parser = securemint_cli.build_parser()
            # The subparsers action stores choices (subcommand names)
            subparsers_actions = [
                action for action in parser._subparsers._actions
                if isinstance(action, type(parser._subparsers._actions[-1]))
                and hasattr(action, "choices")
            ]
            assert len(subparsers_actions) > 0, "No subparsers found"
            choices = subparsers_actions[-1].choices
            expected = [
                "mint-batch", "burn", "compliance", "report", "oracle-status",
                "invariants", "simulate", "config-check", "validate-contracts",
                "health-check", "treasury-status", "bridge-status", "smoke-test",
                "preflight", "intake",
            ]
            for cmd in expected:
                assert cmd in choices, f"Subcommand '{cmd}' not registered in parser"
        finally:
            sys.path.pop(0)


class TestConfigCheck:
    """config-check subcommand."""

    def test_config_check_no_env(self) -> None:
        result = run_cli("--format", "json", "config-check")
        # Should complete (exit 0 or 1), and output must contain FAIL
        output = result.stdout + result.stderr
        assert "FAIL" in output, "Expected FAIL when no env vars are set"


class TestValidateContracts:
    """validate-contracts subcommand."""

    def test_validate_contracts(self) -> None:
        result = run_cli("--format", "json", "validate-contracts")
        data = json.loads(result.stdout)
        # The contracts directory has all 15 expected files
        assert data["summary"]["found"] == 15, (
            f"Expected 15/15 contracts found, got {data['summary']['found']}/{data['summary']['total']}"
        )


class TestMintBatch:
    """mint-batch subcommand."""

    def test_mint_batch_missing_file(self) -> None:
        result = run_cli("--format", "json", "mint-batch", "--file", "/tmp/nonexistent_file_12345.json")
        assert result.returncode == 1, "Expected exit code 1 for missing file"


class TestCompliance:
    """compliance subcommand."""

    def test_compliance_no_address(self) -> None:
        result = run_cli("--format", "json", "compliance")
        assert result.returncode == 1, "Expected exit code 1 when no address provided"


class TestSimulate:
    """simulate subcommand."""

    def test_simulate_missing_bundle(self) -> None:
        result = run_cli("--format", "json", "simulate", "--bundle", "/tmp/nonexistent_bundle_12345.json")
        assert result.returncode == 1, "Expected exit code 1 for missing bundle"

    def test_simulate_invalid_schema(self) -> None:
        # Write a temporary JSON file that is missing the required "transactions" key
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump({"not_transactions": []}, f)
            tmp_path = f.name

        try:
            result = run_cli("--format", "json", "simulate", "--bundle", tmp_path)
            assert result.returncode == 1, "Expected exit code 1 for invalid bundle schema"
        finally:
            os.unlink(tmp_path)


class TestBurn:
    """burn subcommand."""

    def test_burn_missing_file(self) -> None:
        result = run_cli("--format", "json", "burn", "--file", "/tmp/nonexistent_burn_12345.json")
        assert result.returncode == 1, "Expected exit code 1 for missing file"


class TestReport:
    """report subcommand."""

    def test_report_no_env(self) -> None:
        result = run_cli("--format", "json", "report", "--type", "reserve")
        # Should complete without crashing; may fail gracefully or succeed with error info
        assert result.returncode in (0, 1), f"Unexpected exit code: {result.returncode}"


class TestOracleStatus:
    """oracle-status subcommand."""

    def test_oracle_status_no_env(self) -> None:
        result = run_cli("--format", "json", "oracle-status")
        assert result.returncode == 1, "Expected exit code 1 when ORACLE_ADDRESS not set"


class TestInvariants:
    """invariants subcommand."""

    def test_invariants_no_env(self) -> None:
        result = run_cli("--format", "json", "invariants")
        # Should complete; invariants may be UNKNOWN without RPC
        assert result.returncode in (0, 1), f"Unexpected exit code: {result.returncode}"


class TestHealthCheck:
    """health-check subcommand."""

    def test_health_check_runs(self) -> None:
        result = run_cli("--format", "json", "health-check")
        output = result.stdout + result.stderr
        assert "SecureMint Health Dashboard" in output or "health" in output.lower(), (
            "Expected health-check to produce output"
        )


class TestTreasuryStatus:
    """treasury-status subcommand."""

    def test_treasury_status_no_env(self) -> None:
        result = run_cli("--format", "json", "treasury-status")
        assert result.returncode == 1, "Expected exit code 1 when TREASURY_ADDRESS not set"


class TestBridgeStatus:
    """bridge-status subcommand."""

    def test_bridge_status_no_env(self) -> None:
        result = run_cli("--format", "json", "bridge-status")
        assert result.returncode == 1, "Expected exit code 1 when BRIDGE_ADDRESS not set"


class TestSmokeTest:
    """smoke-test subcommand."""

    def test_smoke_test_no_env(self) -> None:
        result = run_cli("--format", "json", "smoke-test")
        # Should handle missing env gracefully (exit 0 or 1)
        assert result.returncode in (0, 1), f"Unexpected exit code: {result.returncode}"


class TestPreflight:
    """preflight subcommand."""

    def test_preflight_no_env(self) -> None:
        result = run_cli("--format", "json", "preflight")
        output = result.stdout + result.stderr
        assert "FAIL" in output, "Expected FAIL results when no env vars are set"


class TestIntake:
    """intake subcommand."""

    def test_intake_runs(self) -> None:
        result = run_cli("--format", "json", "intake")
        output = result.stdout + result.stderr
        assert "Intake" in output or "intake" in output.lower() or "checks" in output.lower(), (
            "Expected intake output to contain relevant content"
        )
