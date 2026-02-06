"""Template instantiation engine — generate project files with brief overrides."""
from __future__ import annotations

import json
import os
import re
import shutil
from pathlib import Path
from typing import Any, Dict, List, Optional


# Default substitution values (from execution_master_prompt.md locked defaults)
DEFAULTS: Dict[str, str] = {
    "TOKEN_NAME": "MyMemecoin",
    "TICKER": "TOKEN",
    "TOTAL_SUPPLY": "1000000000",
    "DECIMALS": "9",
    "LP_TOKEN_AMOUNT": "700000000",
    "LP_USDC_AMOUNT": "100000",
    "DISTRIBUTION_WALLETS": "10",
    "RPC_ENDPOINT": "https://api.mainnet-beta.solana.com",
    "NETWORK": "mainnet-beta",
    "PROGRAM_ID": "11111111111111111111111111111111",
    "TOKEN_MINT": "11111111111111111111111111111111",
    "TREASURY_PDA": "11111111111111111111111111111111",
    "AURA_CYAN": "#00F0FF",
    "AURA_PURPLE": "#9B59FF",
    "AURA_ORANGE": "#FF6B35",
}

# Regex for template variables: {{VAR_NAME}}
RE_TEMPLATE_VAR = re.compile(r"\{\{(\w+)\}\}")


def _load_brief(brief_path: Path) -> Dict[str, str]:
    """Parse a MEMECOIN_BRIEF.md and extract Section 7 design parameters."""
    if not brief_path.exists():
        return {}

    content = brief_path.read_text(encoding="utf-8")
    overrides: Dict[str, str] = {}

    # Look for Section 7 or "Design Parameters"
    in_section7 = False
    for line in content.split("\n"):
        stripped = line.strip()
        if re.match(r"^#+\s+.*(?:Section\s*7|Design\s*Parameters)", stripped, re.IGNORECASE):
            in_section7 = True
            continue
        if in_section7 and stripped.startswith("#"):
            break  # Next heading = end of section
        if in_section7 and "|" in stripped:
            # Parse table row: | Key | Value | ...
            parts = [p.strip() for p in stripped.split("|") if p.strip()]
            if len(parts) >= 2 and parts[0] != "---" and not parts[0].startswith("-"):
                key = parts[0].upper().replace(" ", "_").replace("-", "_")
                val = parts[1]
                # Map common brief keys to our template vars
                key_map = {
                    "TOKEN_NAME": "TOKEN_NAME",
                    "TICKER": "TICKER",
                    "SYMBOL": "TICKER",
                    "TOTAL_SUPPLY": "TOTAL_SUPPLY",
                    "SUPPLY": "TOTAL_SUPPLY",
                    "DECIMALS": "DECIMALS",
                    "CHAIN": "NETWORK",
                    "PRIMARY_CHAIN": "NETWORK",
                }
                mapped = key_map.get(key, key)
                if mapped in DEFAULTS:
                    overrides[mapped] = val

    return overrides


def _substitute(content: str, params: Dict[str, str]) -> str:
    """Replace {{VAR_NAME}} placeholders with actual values."""
    def replacer(match: re.Match) -> str:
        key = match.group(1)
        return params.get(key, match.group(0))  # Keep original if not found
    return RE_TEMPLATE_VAR.sub(replacer, content)


def _copy_tree_with_substitution(
    src_dir: Path, dest_dir: Path, params: Dict[str, str]
) -> List[str]:
    """Copy a directory tree, applying template substitution to text files."""
    written: List[str] = []
    text_extensions = {".tsx", ".ts", ".css", ".json", ".md", ".yml", ".yaml", ".toml", ".rs", ".sh", ".py"}

    for src_file in sorted(src_dir.rglob("*")):
        if src_file.is_dir():
            continue
        if src_file.name.startswith("."):
            continue

        rel = src_file.relative_to(src_dir)
        dest_file = dest_dir / rel
        dest_file.parent.mkdir(parents=True, exist_ok=True)

        if src_file.suffix in text_extensions:
            content = src_file.read_text(encoding="utf-8")
            content = _substitute(content, params)
            dest_file.write_text(content, encoding="utf-8")
        else:
            shutil.copy2(src_file, dest_file)

        written.append(str(rel))

    return written


class Generator:
    """Generate project files from skill templates with brief overrides."""

    def __init__(self, skill_dir: Path, brief_path: Optional[Path] = None):
        self.skill_dir = skill_dir
        self.params = dict(DEFAULTS)
        if brief_path:
            overrides = _load_brief(brief_path)
            self.params.update(overrides)

    def set_param(self, key: str, value: str) -> None:
        """Override a single parameter."""
        self.params[key] = value

    def set_params(self, overrides: Dict[str, str]) -> None:
        """Override multiple parameters."""
        self.params.update(overrides)

    def generate_dashboard(self, output_dir: Path) -> Dict[str, Any]:
        """Write all Aura dashboard template files to output_dir."""
        src = self.skill_dir / "templates" / "aura"
        if not src.exists():
            return {"status": "error", "error": "templates/aura directory not found"}

        dest = output_dir / "frontend"
        written = _copy_tree_with_substitution(src, dest, self.params)

        return {
            "status": "ok",
            "output_dir": str(dest),
            "files_written": len(written),
            "files": written,
        }

    def generate_contracts(self, output_dir: Path) -> Dict[str, Any]:
        """Write all Anchor program files to output_dir."""
        src = self.skill_dir / "scripts" / "anchor_contracts"
        if not src.exists():
            return {"status": "error", "error": "scripts/anchor_contracts directory not found"}

        dest = output_dir / "programs"
        written: List[str] = []

        for rs_file in sorted(src.glob("*.rs")):
            program_name = rs_file.stem
            program_dir = dest / program_name / "src"
            program_dir.mkdir(parents=True, exist_ok=True)
            content = rs_file.read_text(encoding="utf-8")
            content = _substitute(content, self.params)
            out_path = program_dir / "lib.rs"
            out_path.write_text(content, encoding="utf-8")
            written.append(f"{program_name}/src/lib.rs")

        return {
            "status": "ok",
            "output_dir": str(dest),
            "files_written": len(written),
            "files": written,
        }

    def generate_marketing(self, output_dir: Path) -> Dict[str, Any]:
        """Write narrative forge marketing templates."""
        src = self.skill_dir / "templates" / "narrative_forge"
        if not src.exists():
            # Fall back to scripts/marketing if templates don't exist
            src = self.skill_dir / "scripts" / "marketing"
        if not src.exists():
            return {"status": "error", "error": "No marketing templates found"}

        dest = output_dir / "marketing"
        written = _copy_tree_with_substitution(src, dest, self.params)

        return {
            "status": "ok",
            "output_dir": str(dest),
            "files_written": len(written),
            "files": written,
        }

    def generate_scripts(self, output_dir: Path) -> Dict[str, Any]:
        """Write deployment and security scripts."""
        results: Dict[str, Any] = {"status": "ok", "files_written": 0, "files": []}

        for subdir in ("deploy", "security", "dex"):
            src = self.skill_dir / "scripts" / subdir
            if not src.exists():
                continue
            dest = output_dir / "scripts" / subdir
            written = _copy_tree_with_substitution(src, dest, self.params)
            results["files"].extend(written)
            results["files_written"] += len(written)

        results["output_dir"] = str(output_dir / "scripts")
        return results

    def generate_manifest(self, output_dir: Path) -> Dict[str, Any]:
        """Generate the complete repo structure (all components)."""
        output = Path(output_dir)
        output.mkdir(parents=True, exist_ok=True)

        results = {
            "status": "ok",
            "output_dir": str(output),
            "components": {},
            "total_files": 0,
        }

        # Dashboard
        r = self.generate_dashboard(output)
        results["components"]["dashboard"] = r
        results["total_files"] += r.get("files_written", 0)

        # Contracts
        r = self.generate_contracts(output)
        results["components"]["contracts"] = r
        results["total_files"] += r.get("files_written", 0)

        # Marketing
        r = self.generate_marketing(output)
        results["components"]["marketing"] = r
        results["total_files"] += r.get("files_written", 0)

        # Scripts
        r = self.generate_scripts(output)
        results["components"]["scripts"] = r
        results["total_files"] += r.get("files_written", 0)

        return results
