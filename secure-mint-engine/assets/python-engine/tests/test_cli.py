"""
SecureMint Engine - CLI Unit Tests
17+ pytest tests covering all CLI subcommands.
"""

import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from securemint_cli import SecureMintCLI, main


# ═══════════════════════════════════════════════════════════════════════════════
# FIXTURES
# ═══════════════════════════════════════════════════════════════════════════════


@pytest.fixture
def cli():
    """Create a CLI instance with mocked config."""
    with patch.object(SecureMintCLI, "load_config") as mock_load:
        instance = SecureMintCLI()
        instance.config = {
            "rpc_url": "http://localhost:8545",
            "chain_id": 1,
            "private_key": "",
            "contracts": {
                "token": "0x" + "00" * 20,
                "policy": "0x" + "00" * 20,
                "oracle": "0x" + "00" * 20,
                "treasury": "0x" + "00" * 20,
                "bridge": "0x" + "00" * 20,
            },
        }
        yield instance


@pytest.fixture
def sample_csv(tmp_path: Path) -> Path:
    """Create a sample CSV file for batch operations."""
    csv_file = tmp_path / "mint_requests.csv"
    csv_file.write_text(
        "recipient,amount\n"
        "0x1234567890abcdef1234567890abcdef12345678,1000000\n"
        "0xabcdef1234567890abcdef1234567890abcdef12,2500000\n"
        "0x9876543210fedcba9876543210fedcba98765432,500000\n"
    )
    return csv_file


@pytest.fixture
def sample_json(tmp_path: Path) -> Path:
    """Create a sample JSON file for batch operations."""
    json_file = tmp_path / "mint_requests.json"
    data = [
        {"recipient": "0x1234567890abcdef1234567890abcdef12345678", "amount": "1000000"},
        {"recipient": "0xabcdef1234567890abcdef1234567890abcdef12", "amount": "2500000"},
    ]
    json_file.write_text(json.dumps(data))
    return json_file


@pytest.fixture
def sample_addresses(tmp_path: Path) -> Path:
    """Create a sample addresses file for compliance checks."""
    addr_file = tmp_path / "addresses.txt"
    addr_file.write_text(
        "0x1234567890abcdef1234567890abcdef12345678\n"
        "0xabcdef1234567890abcdef1234567890abcdef12\n"
    )
    return addr_file


# ═══════════════════════════════════════════════════════════════════════════════
# CLI INITIALIZATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestCLIInit:
    """Tests for CLI initialization."""

    def test_cli_creates_instance(self, cli: SecureMintCLI) -> None:
        assert cli is not None
        assert cli.api is None

    def test_cli_loads_config(self, cli: SecureMintCLI) -> None:
        assert cli.config["rpc_url"] == "http://localhost:8545"
        assert cli.config["chain_id"] == 1

    def test_cli_config_has_contracts(self, cli: SecureMintCLI) -> None:
        contracts = cli.config["contracts"]
        assert "token" in contracts
        assert "policy" in contracts
        assert "oracle" in contracts
        assert "treasury" in contracts

    def test_cli_connect_creates_api(self, cli: SecureMintCLI) -> None:
        with patch("securemint_cli.SecureMintAPI") as mock_api_cls:
            mock_api_cls.return_value = MagicMock()
            api = cli.connect()
            assert api is not None
            mock_api_cls.assert_called_once()


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestMainEntry:
    """Tests for main() entry point."""

    def test_main_no_args_shows_help(self) -> None:
        with patch("sys.argv", ["securemint_cli.py"]):
            result = main()
            assert result == 1

    def test_main_invalid_command_shows_help(self) -> None:
        with patch("sys.argv", ["securemint_cli.py", "invalid-command"]):
            result = main()
            assert result == 1


# ═══════════════════════════════════════════════════════════════════════════════
# BATCH MINT TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestMintBatch:
    """Tests for mint-batch command."""

    @pytest.mark.asyncio
    async def test_mint_batch_file_not_found(self, cli: SecureMintCLI) -> None:
        args = MagicMock()
        args.input = "/nonexistent/file.csv"
        args.output = None
        args.batch_size = 50
        args.gas_price = None
        args.retries = 3
        args.dry_run = False
        args.force = False

        result = await cli.mint_batch(args)
        assert result == 1

    @pytest.mark.asyncio
    async def test_mint_batch_loads_csv(
        self, cli: SecureMintCLI, sample_csv: Path
    ) -> None:
        mock_api = MagicMock()
        mock_bulk = MagicMock()
        mock_bulk.load_csv.return_value = [
            {"recipient": "0x1234", "amount": 1000000},
            {"recipient": "0xabcd", "amount": 2500000},
        ]
        mock_bulk.validate_mint_batch = AsyncMock(
            return_value={"errors": []}
        )
        mock_api.check_invariants = AsyncMock(
            return_value={"all_valid": True, "results": {}}
        )
        mock_bulk.execute_mint_batch = AsyncMock(
            return_value={
                "success_count": 2,
                "failure_count": 0,
                "total_gas_used": 42000,
            }
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api), \
             patch("securemint_cli.BulkOperator", return_value=mock_bulk):
            args = MagicMock()
            args.input = str(sample_csv)
            args.output = None
            args.batch_size = 50
            args.gas_price = None
            args.retries = 3
            args.dry_run = False
            args.force = False

            result = await cli.mint_batch(args)
            assert result == 0
            mock_bulk.load_csv.assert_called_once()

    @pytest.mark.asyncio
    async def test_mint_batch_dry_run(
        self, cli: SecureMintCLI, sample_csv: Path
    ) -> None:
        mock_api = MagicMock()
        mock_bulk = MagicMock()
        mock_bulk.load_csv.return_value = [{"recipient": "0x1234", "amount": 1000000}]
        mock_bulk.validate_mint_batch = AsyncMock(return_value={"errors": []})
        mock_api.check_invariants = AsyncMock(
            return_value={"all_valid": True, "results": {}}
        )
        mock_bulk.simulate_mint_batch = AsyncMock(
            return_value={
                "success_count": 1,
                "failure_count": 0,
                "total_gas_used": 21000,
            }
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api), \
             patch("securemint_cli.BulkOperator", return_value=mock_bulk):
            args = MagicMock()
            args.input = str(sample_csv)
            args.output = None
            args.batch_size = 50
            args.gas_price = None
            args.retries = 3
            args.dry_run = True
            args.force = False

            result = await cli.mint_batch(args)
            assert result == 0
            mock_bulk.simulate_mint_batch.assert_called_once()


# ═══════════════════════════════════════════════════════════════════════════════
# COMPLIANCE TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestCompliance:
    """Tests for compliance command."""

    @pytest.mark.asyncio
    async def test_compliance_requires_address_or_input(
        self, cli: SecureMintCLI
    ) -> None:
        args = MagicMock()
        args.address = None
        args.input = None
        args.output = None
        args.jurisdiction = "US"
        args.kyc = True
        args.aml = True
        args.sanctions = True

        result = await cli.compliance_check(args)
        assert result == 1

    @pytest.mark.asyncio
    async def test_compliance_single_address(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()
        mock_compliance = MagicMock()
        mock_compliance.check_batch = AsyncMock(
            return_value={
                "results": [{"address": "0x1234", "compliant": True}]
            }
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api), \
             patch("securemint_cli.ComplianceEngine", return_value=mock_compliance):
            args = MagicMock()
            args.address = "0x1234567890abcdef1234567890abcdef12345678"
            args.input = None
            args.output = None
            args.jurisdiction = "US"
            args.kyc = True
            args.aml = True
            args.sanctions = True

            result = await cli.compliance_check(args)
            assert result == 0


# ═══════════════════════════════════════════════════════════════════════════════
# REPORT GENERATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestReportGeneration:
    """Tests for report command."""

    @pytest.mark.asyncio
    async def test_report_invalid_type(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api), \
             patch("securemint_cli.ReportGenerator"):
            args = MagicMock()
            args.type = "invalid_type"
            args.output_dir = None
            args.days = 30
            args.start_date = None
            args.jurisdiction = None
            args.include_proof = False
            args.markdown = False

            result = await cli.generate_report(args)
            assert result == 1

    @pytest.mark.asyncio
    async def test_report_reserve(self, cli: SecureMintCLI, tmp_path: Path) -> None:
        mock_api = MagicMock()
        mock_reporter = MagicMock()
        mock_reporter.generate_reserve_attestation = AsyncMock(
            return_value={"type": "reserve", "data": {}}
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api), \
             patch("securemint_cli.ReportGenerator", return_value=mock_reporter):
            args = MagicMock()
            args.type = "reserve"
            args.output_dir = str(tmp_path)
            args.days = 30
            args.start_date = None
            args.jurisdiction = None
            args.include_proof = True
            args.markdown = False

            result = await cli.generate_report(args)
            assert result == 0
            mock_reporter.generate_reserve_attestation.assert_called_once()


# ═══════════════════════════════════════════════════════════════════════════════
# ORACLE OPERATIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestOracleOperations:
    """Tests for oracle command."""

    @pytest.mark.asyncio
    async def test_oracle_status(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()
        mock_api.get_oracle_status = AsyncMock(
            return_value={"healthy": True, "age": 120}
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api):
            cli.api = mock_api
            args = MagicMock()
            args.action = "status"
            args.backing = None
            args.limit = None
            args.output = None

            result = await cli.oracle(args)
            assert result == 0
            mock_api.get_oracle_status.assert_called_once()

    @pytest.mark.asyncio
    async def test_oracle_update_requires_backing(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api):
            cli.api = mock_api
            args = MagicMock()
            args.action = "update"
            args.backing = None
            args.limit = None
            args.output = None

            result = await cli.oracle(args)
            assert result == 1


# ═══════════════════════════════════════════════════════════════════════════════
# TREASURY OPERATIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestTreasuryOperations:
    """Tests for treasury command."""

    @pytest.mark.asyncio
    async def test_treasury_status(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()
        mock_api.get_treasury_status = AsyncMock(
            return_value={
                "total_reserves": 1000000,
                "tiers": {"hot": 100000, "warm": 300000, "cold": 500000, "rwa": 100000},
            }
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api):
            cli.api = mock_api
            args = MagicMock()
            args.action = "status"
            args.tier = None
            args.amount = None
            args.target = None
            args.recipient = None

            result = await cli.treasury(args)
            assert result == 0


# ═══════════════════════════════════════════════════════════════════════════════
# BRIDGE OPERATIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestBridgeOperations:
    """Tests for bridge command."""

    @pytest.mark.asyncio
    async def test_bridge_status(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()
        mock_api.get_bridge_status = AsyncMock(
            return_value={"active_chains": 3, "pending_transfers": 0}
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api):
            cli.api = mock_api
            args = MagicMock()
            args.action = "status"
            args.transfer_id = None

            result = await cli.bridge(args)
            assert result == 0


# ═══════════════════════════════════════════════════════════════════════════════
# SIMULATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════


class TestSimulation:
    """Tests for simulate command."""

    @pytest.mark.asyncio
    async def test_simulate_success(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()
        mock_api.simulate_bundle = AsyncMock(
            return_value={
                "success": True,
                "gas_used": 42000,
                "invariant_violations": [],
            }
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api):
            cli.api = mock_api
            args = MagicMock()
            args.tx_file = None
            args.to = "0x1234567890abcdef1234567890abcdef12345678"
            args.data = "0x"
            args.value = "0"
            args.output = None

            result = await cli.simulate(args)
            assert result == 0

    @pytest.mark.asyncio
    async def test_simulate_failure(self, cli: SecureMintCLI) -> None:
        mock_api = MagicMock()
        mock_api.simulate_bundle = AsyncMock(
            return_value={
                "success": False,
                "error": "Insufficient backing",
            }
        )

        with patch("securemint_cli.SecureMintAPI", return_value=mock_api):
            cli.api = mock_api
            args = MagicMock()
            args.tx_file = None
            args.to = "0x1234567890abcdef1234567890abcdef12345678"
            args.data = "0x"
            args.value = "0"
            args.output = None

            result = await cli.simulate(args)
            assert result == 1
