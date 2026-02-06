"""Targeted content extraction using byte offsets from the index."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


class Extractor:
    """Extract specific content from indexed files using byte offsets."""

    def __init__(self, index_data: Dict[str, Any], skill_dir: Path):
        self.index = index_data
        self.skill_dir = skill_dir

    def _safe_path(self, source_file: str) -> Path:
        """Validate source_file to prevent path traversal attacks."""
        if not source_file:
            raise ValueError("Path traversal blocked: empty path")
        resolved = (self.skill_dir / source_file).resolve()
        skill_resolved = self.skill_dir.resolve()
        try:
            resolved.relative_to(skill_resolved)
        except ValueError:
            raise ValueError(f"Path traversal blocked: {source_file}") from None
        if not resolved.exists():
            raise FileNotFoundError(f"File not found: {source_file}")
        return resolved

    def _read_bytes(self, source_file: str, byte_offset: int, byte_length: int) -> str:
        """Read a byte range from a source file."""
        path = self._safe_path(source_file)
        file_size = path.stat().st_size
        if byte_offset < 0 or byte_offset >= file_size:
            raise ValueError(
                f"byte_offset {byte_offset} out of range for {source_file} ({file_size} bytes)"
            )
        clamped_length = min(byte_length, file_size - byte_offset)
        with open(path, "rb") as f:
            f.seek(byte_offset)
            raw = f.read(clamped_length)
            try:
                return raw.decode("utf-8")
            except UnicodeDecodeError:
                return raw.decode("utf-8", errors="replace")

    def _read_full(self, source_file: str) -> str:
        """Read an entire source file."""
        path = self._safe_path(source_file)
        return path.read_text(encoding="utf-8")

    def _read_lines(self, source_file: str, start: int, end: int) -> str:
        """Read a line range from a source file (0-indexed, inclusive)."""
        path = self._safe_path(source_file)
        lines = path.read_text(encoding="utf-8").split("\n")
        total = len(lines)
        start = max(0, start)
        end = min(end, total - 1)
        if start > end or start >= total:
            raise ValueError(
                f"Line range [{start}:{end}] out of bounds for {source_file} ({total} lines)"
            )
        return "\n".join(lines[start: end + 1])

    def _token_stats(self, content: str, source_file: str) -> Dict[str, int]:
        """Compute token reduction statistics."""
        content_bytes = len(content.encode("utf-8"))
        est_tokens = content_bytes // 4
        # Get full file size for comparison
        path = self._safe_path(source_file)
        full_bytes = path.stat().st_size
        full_tokens = max(full_bytes // 4, 1)
        return {
            "estimated_output": est_tokens,
            "full_file_tokens": full_tokens,
            "reduction_pct": round((1 - est_tokens / full_tokens) * 100, 1),
        }

    # -------------------------------------------------------------------
    # Section extraction (markdown)
    # -------------------------------------------------------------------
    def get_section(self, section_id: str, outline_only: bool = False) -> Optional[Dict[str, Any]]:
        """Extract a markdown section by ID."""
        sections = self.index.get("sections", {})

        # Exact match first, then partial
        matched_id = section_id
        if matched_id not in sections:
            for k in sections:
                if section_id in k:
                    matched_id = k
                    break
            else:
                return None

        s = sections[matched_id]
        source = s["source_file"]

        if outline_only:
            content = self._get_section_outline(s)
        else:
            content = self._read_bytes(source, s["byte_offset"], s["byte_length"])

        return {
            "id": matched_id,
            "title": s["title"],
            "source_file": source,
            "category": s.get("category", "reference"),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def _get_section_outline(self, section: Dict[str, Any]) -> str:
        """Return only headings from a section."""
        content = self._read_lines(
            section["source_file"], section["start_line"], section["end_line"]
        )
        outline = []
        for line in content.split("\n"):
            stripped = line.strip()
            if stripped.startswith("#"):
                outline.append(line)
        return "\n".join(outline)

    # -------------------------------------------------------------------
    # Template extraction (TSX/TS/CSS)
    # -------------------------------------------------------------------
    def get_template(self, template_id: str) -> Optional[Dict[str, Any]]:
        """Extract a template file (full content — templates are whole files)."""
        templates = self.index.get("templates", {})

        matched_id = template_id
        if matched_id not in templates:
            for k in templates:
                if template_id in k:
                    matched_id = k
                    break
            else:
                return None

        t = templates[matched_id]
        source = t["source_file"]
        content = self._read_full(source)

        return {
            "id": matched_id,
            "name": t["name"],
            "source_file": source,
            "component_type": t["component_type"],
            "route_group": t.get("route_group"),
            "exports": t.get("exports", []),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    # -------------------------------------------------------------------
    # Contract extraction (Rust/Anchor)
    # -------------------------------------------------------------------
    def get_contract(self, contract_id: str) -> Optional[Dict[str, Any]]:
        """Extract an Anchor contract (full program file)."""
        contracts = self.index.get("contracts", {})

        matched_id = contract_id
        if matched_id not in contracts:
            for k in contracts:
                if contract_id in k:
                    matched_id = k
                    break
            else:
                return None

        c = contracts[matched_id]
        source = c["source_file"]
        content = self._read_full(source)

        return {
            "id": matched_id,
            "name": c["name"],
            "source_file": source,
            "instructions": c.get("instructions", []),
            "accounts": c.get("accounts", []),
            "events": c.get("events", []),
            "errors": c.get("errors", []),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    # -------------------------------------------------------------------
    # Script extraction
    # -------------------------------------------------------------------
    def get_script(self, script_id: str) -> Optional[Dict[str, Any]]:
        """Extract a script file."""
        scripts = self.index.get("scripts", {})

        matched_id = script_id
        if matched_id not in scripts:
            for k in scripts:
                if script_id in k:
                    matched_id = k
                    break
            else:
                return None

        s = scripts[matched_id]
        source = s["source_file"]
        content = self._read_full(source)

        return {
            "id": matched_id,
            "name": s["name"],
            "source_file": source,
            "script_type": s["script_type"],
            "description": s.get("description", ""),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    # -------------------------------------------------------------------
    # Universal extraction
    # -------------------------------------------------------------------
    def extract(self, entry_id: str) -> Optional[Dict[str, Any]]:
        """Extract any entry by ID, auto-detecting category."""
        if entry_id.startswith("contracts/"):
            return self.get_contract(entry_id)
        if entry_id.startswith("templates/"):
            return self.get_template(entry_id)
        if entry_id.startswith("scripts/"):
            return self.get_script(entry_id)
        # Try sections (reference/, skill/, template-doc/)
        result = self.get_section(entry_id)
        if result:
            return result
        # Fallback: try all categories
        for method in (self.get_contract, self.get_template, self.get_script):
            result = method(entry_id)
            if result:
                return result
        return None

    def batch_extract(self, entry_ids: List[str]) -> List[Dict[str, Any]]:
        """Extract multiple entries."""
        results = []
        for eid in entry_ids:
            result = self.extract(eid)
            if result:
                results.append(result)
            else:
                results.append({"id": eid, "error": "not found"})
        return results
