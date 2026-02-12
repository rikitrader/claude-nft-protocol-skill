"""Targeted content extraction using byte offsets from the index.

Reads only the exact bytes needed — typically 90%+ reduction vs full file loading.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional


class Extractor:
    """Extract specific Pine Script doc content using byte offsets."""

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

    def _token_stats(self, content: str, source_file: str) -> Dict[str, int]:
        """Compute token reduction statistics."""
        content_bytes = len(content.encode("utf-8"))
        est_tokens = content_bytes // 4
        path = self._safe_path(source_file)
        full_bytes = path.stat().st_size
        full_tokens = max(full_bytes // 4, 1)
        return {
            "estimated_output": est_tokens,
            "full_file_tokens": full_tokens,
            "reduction_pct": round((1 - est_tokens / full_tokens) * 100, 1),
        }

    # -------------------------------------------------------------------
    # Section extraction
    # -------------------------------------------------------------------
    def get_section(self, section_id: str, outline_only: bool = False) -> Optional[Dict[str, Any]]:
        """Extract a documentation section by ID."""
        sections = self.index.get("sections", {})

        matched_id = self._match_id(section_id, sections)
        if not matched_id:
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
            "category": s.get("category", ""),
            "source_file": source,
            "content": content,
            "code_blocks": s.get("code_blocks", 0),
            "tokens": self._token_stats(content, source),
        }

    def _get_section_outline(self, section: Dict[str, Any]) -> str:
        """Return only headings and code block markers from a section."""
        content = self._read_bytes(
            section["source_file"], section["byte_offset"], section["byte_length"]
        )
        outline = []
        for line in content.split("\n"):
            stripped = line.strip()
            if stripped.startswith("#"):
                outline.append(line)
            elif stripped.startswith("```"):
                outline.append(line)
        return "\n".join(outline)

    # -------------------------------------------------------------------
    # Function extraction
    # -------------------------------------------------------------------
    def get_function(self, func_name: str) -> Optional[Dict[str, Any]]:
        """Extract documentation for a Pine Script built-in function."""
        functions = self.index.get("functions", {})

        # Try exact match first: fn/ta.sma
        func_id = f"fn/{func_name}"
        matched_id = self._match_id(func_id, functions)
        if not matched_id:
            # Try partial match without fn/ prefix
            matched_id = self._match_id(func_name, functions)
        if not matched_id:
            return None

        f = functions[matched_id]
        source = f["source_file"]
        content = self._read_bytes(source, f["byte_offset"], f["byte_length"])

        return {
            "id": matched_id,
            "name": f["name"],
            "namespace": f.get("namespace", ""),
            "signature": f.get("signature", ""),
            "description": f.get("description", ""),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def list_functions(self, namespace: Optional[str] = None) -> List[Dict[str, Any]]:
        """List all indexed Pine Script functions, optionally filtered by namespace."""
        functions = self.index.get("functions", {})
        results = []
        for func_id, func in functions.items():
            ns = func.get("namespace", "")
            if namespace and ns != namespace:
                continue
            results.append({
                "id": func_id,
                "name": func["name"],
                "namespace": ns,
                "signature": func.get("signature", ""),
                "description": func.get("description", "")[:100],
            })
        results.sort(key=lambda r: r["name"])
        return results

    # -------------------------------------------------------------------
    # Code example extraction
    # -------------------------------------------------------------------
    def get_example(self, example_id: str) -> Optional[Dict[str, Any]]:
        """Extract a specific code example by ID."""
        examples = self.index.get("examples", {})

        matched_id = self._match_id(example_id, examples)
        if not matched_id:
            return None

        ex = examples[matched_id]
        source = ex["source_file"]
        content = self._read_bytes(source, ex["byte_offset"], ex["byte_length"])

        return {
            "id": matched_id,
            "section_id": ex.get("section_id", ""),
            "language": ex.get("language", "pine"),
            "description": ex.get("description", ""),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def get_examples_for_section(self, section_id: str) -> List[Dict[str, Any]]:
        """Get all code examples belonging to a section."""
        examples = self.index.get("examples", {})
        results = []
        for ex_id, ex in examples.items():
            if section_id in ex.get("section_id", ""):
                source = ex["source_file"]
                content = self._read_bytes(source, ex["byte_offset"], ex["byte_length"])
                results.append({
                    "id": ex_id,
                    "description": ex.get("description", ""),
                    "content": content,
                })
        return results

    # -------------------------------------------------------------------
    # Universal extraction
    # -------------------------------------------------------------------
    def extract(self, entry_id: str) -> Optional[Dict[str, Any]]:
        """Extract any entry by ID, auto-detecting category."""
        if entry_id.startswith("fn/"):
            return self.get_function(entry_id[3:])
        if entry_id.startswith("ex/"):
            return self.get_example(entry_id)
        # Try section
        result = self.get_section(entry_id)
        if result:
            return result
        # Try function by name
        result = self.get_function(entry_id)
        if result:
            return result
        return None

    # -------------------------------------------------------------------
    # Helpers
    # -------------------------------------------------------------------
    @staticmethod
    def _match_id(target: str, entries: Dict[str, Any]) -> Optional[str]:
        """Match an entry ID — exact first, then partial substring."""
        if target in entries:
            return target
        target_lower = target.lower()
        for k in entries:
            if target_lower in k.lower():
                return k
        return None
