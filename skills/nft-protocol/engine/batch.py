"""Batch processing via Anthropic API for bulk operations."""
from __future__ import annotations

import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional

from .extractor import Extractor
from .tracker import TokenTracker, estimate_tokens


DEFAULT_MODEL = os.environ.get("NFT_ENGINE_MODEL", "claude-sonnet-4-20250514")


def _json_error(msg: str) -> None:
    """Print a JSON error to stdout and exit."""
    sys.stdout.write(json.dumps({"status": "error", "command": "batch", "error": msg}) + "\n")
    sys.stdout.flush()
    sys.exit(1)


def _get_client():
    """Lazy import of anthropic SDK."""
    try:
        import anthropic
    except ImportError:
        _json_error("anthropic SDK not installed. Run: pip3 install anthropic")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        _json_error("ANTHROPIC_API_KEY not set. Export it first.")

    return anthropic.Anthropic(api_key=api_key)


class BatchProcessor:
    """Execute bulk operations via the Anthropic API."""

    def __init__(self, extractor: Extractor, tracker: TokenTracker,
                 model: str = DEFAULT_MODEL):
        self.extractor = extractor
        self.tracker = tracker
        self.model = model
        self._client = None

    @property
    def client(self):
        if self._client is None:
            self._client = _get_client()
        return self._client

    def generate_contracts(self, specs: List[Dict[str, str]],
                           max_workers: int = 3,
                           output_dir: Optional[Path] = None) -> List[Dict[str, Any]]:
        """Generate modified contracts in parallel via API."""
        results = []

        def _process_one(spec: Dict[str, str]) -> Dict[str, Any]:
            base_name = spec.get("base", "")
            prompt = spec.get("prompt", "")

            # Extract base contract
            contract = self.extractor.get_contract(base_name)
            if not contract:
                return {"name": base_name, "status": "error",
                        "error": f"Contract '{base_name}' not found"}

            # Build API prompt
            system_msg = (
                "You are an expert Solidity smart contract engineer. "
                "Modify the following contract as requested. "
                "Return ONLY the complete modified Solidity code."
            )
            user_msg = (
                f"Base contract:\n```solidity\n{contract['content']}\n```\n\n"
                f"Modification requested: {prompt}"
            )

            input_tokens = estimate_tokens(system_msg + user_msg)

            response = self.client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=system_msg,
                messages=[{"role": "user", "content": user_msg}],
            )

            if not response.content:
                return {"name": base_name, "status": "error",
                        "error": "Empty API response"}
            output_text = response.content[0].text
            output_tokens = estimate_tokens(output_text)

            # Track savings
            full_module_tokens = contract["tokens"]["full_module_tokens"]
            self.tracker.log(
                "batch-generate",
                tokens_used=input_tokens + output_tokens,
                tokens_saved=full_module_tokens - input_tokens,
                details={"contract": base_name, "model": self.model},
            )

            result = {
                "name": base_name,
                "status": "ok",
                "prompt": prompt,
                "generated_code": output_text,
                "tokens": {
                    "input": input_tokens,
                    "output": output_tokens,
                    "saved_vs_full_load": full_module_tokens - input_tokens,
                },
            }

            # Optionally save to file
            if output_dir:
                # Sanitize filename — strip everything except alnum, dash, underscore
                safe_name = "".join(c for c in base_name if c.isalnum() or c in "-_")
                output_dir.mkdir(parents=True, exist_ok=True)
                out_file = (output_dir / f"{safe_name}_modified.sol").resolve()
                # Verify output stays inside output_dir
                try:
                    out_file.relative_to(output_dir.resolve())
                except ValueError:
                    return {"name": base_name, "status": "error",
                            "error": f"Output path escapes output_dir: {out_file}"}
                out_file.write_text(output_text, encoding="utf-8")
                result["output_file"] = str(out_file)

            return result

        with ThreadPoolExecutor(max_workers=max_workers) as pool:
            futures = {pool.submit(_process_one, spec): spec for spec in specs}
            for future in as_completed(futures):
                try:
                    results.append(future.result())
                except Exception as e:
                    spec = futures[future]
                    results.append({
                        "name": spec.get("base", "unknown"),
                        "status": "error",
                        "error": str(e),
                    })

        return results

    def analyze_module(self, module_file: str, prompt: str) -> Dict[str, Any]:
        """Send a module to the API for analysis."""
        modules = self.extractor.index.get("modules", {})
        if module_file not in modules:
            return {"status": "error", "error": f"Module '{module_file}' not found"}

        # Read full module content (use _safe_path to prevent path traversal)
        path = self.extractor._safe_path(module_file)
        content = path.read_text(encoding="utf-8")

        system_msg = (
            "You are a senior smart contract auditor. "
            "Analyze the following NFT protocol module."
        )
        user_msg = f"Module: {module_file}\n\n{content}\n\nAnalysis request: {prompt}"

        input_tokens = estimate_tokens(system_msg + user_msg)

        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=system_msg,
            messages=[{"role": "user", "content": user_msg}],
        )

        if not response.content:
            return {"status": "error", "error": "Empty API response"}
        output_text = response.content[0].text
        output_tokens = estimate_tokens(output_text)

        self.tracker.log(
            "batch-analyze",
            tokens_used=input_tokens + output_tokens,
            tokens_saved=0,
            details={"module": module_file, "model": self.model},
        )

        return {
            "status": "ok",
            "module": module_file,
            "analysis": output_text,
            "tokens": {"input": input_tokens, "output": output_tokens},
        }
