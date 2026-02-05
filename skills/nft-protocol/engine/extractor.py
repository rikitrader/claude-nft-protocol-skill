"""Targeted content extraction using byte offsets from the index."""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Optional


class Extractor:
    """Extract specific contracts, sections, or code blocks from modules."""

    def __init__(self, index_data: Dict[str, Any], modules_dir: Path):
        self.index = index_data
        self.modules_dir = modules_dir

    def _safe_path(self, module_file: str) -> Path:
        """Validate module_file to prevent path traversal attacks."""
        # Strip any directory components — only bare filenames allowed
        safe_name = Path(module_file).name
        path = (self.modules_dir / safe_name).resolve()
        # Verify the resolved path is inside modules_dir
        if not str(path).startswith(str(self.modules_dir.resolve())):
            raise ValueError(f"Path traversal blocked: {module_file}")
        return path

    def _read_range(self, module_file: str, byte_offset: int, byte_length: int) -> str:
        path = self._safe_path(module_file)
        with open(path, "rb") as f:
            f.seek(byte_offset)
            raw = f.read(byte_length)
            try:
                return raw.decode("utf-8")
            except UnicodeDecodeError:
                return raw.decode("utf-8", errors="replace")

    def _read_lines(self, module_file: str, start: int, end: int) -> str:
        path = self._safe_path(module_file)
        lines = path.read_text(encoding="utf-8").split("\n")
        return "\n".join(lines[start : end + 1])

    def get_contract(self, name: str) -> Optional[Dict[str, Any]]:
        """Extract a single contract by name."""
        contracts = self.index.get("contracts", {})
        if name not in contracts:
            # Try case-insensitive match
            for k in contracts:
                if k.lower() == name.lower():
                    name = k
                    break
            else:
                return None

        c = contracts[name]
        content = self._read_lines(c["module_file"], c["start_line"], c["end_line"])

        full_module_bytes = 0
        mod = self.index.get("modules", {}).get(c["module_file"], {})
        if mod:
            full_module_bytes = mod.get("size_bytes", 0)

        content_bytes = len(content.encode("utf-8"))
        est_tokens = content_bytes // 4
        full_tokens = full_module_bytes // 4

        return {
            "name": name,
            "module_file": c["module_file"],
            "section_id": c["section_id"],
            "file_path": c.get("file_path"),
            "standards": c.get("standards", []),
            "imports": c.get("imports", []),
            "content": content,
            "tokens": {
                "estimated_output": est_tokens,
                "full_module_tokens": full_tokens,
                "reduction_pct": round(
                    (1 - est_tokens / max(full_tokens, 1)) * 100, 1
                ),
            },
        }

    def get_section(self, section_id: str, outline_only: bool = False) -> Optional[Dict[str, Any]]:
        """Extract a full section or just its outline."""
        sections = self.index.get("sections", {})
        if section_id not in sections:
            # Try partial match
            for k in sections:
                if section_id in k:
                    section_id = k
                    break
            else:
                return None

        s = sections[section_id]

        if outline_only:
            content = self._get_section_outline(s)
        else:
            content = self._read_lines(
                s["module_file"], s["start_line"], s["end_line"]
            )

        full_module_bytes = 0
        mod = self.index.get("modules", {}).get(s["module_file"], {})
        if mod:
            full_module_bytes = mod.get("size_bytes", 0)

        content_bytes = len(content.encode("utf-8"))
        est_tokens = content_bytes // 4
        full_tokens = full_module_bytes // 4

        return {
            "id": section_id,
            "title": s["title"],
            "module_file": s["module_file"],
            "contracts": s.get("contracts", []),
            "code_block_count": s.get("code_block_count", 0),
            "content": content,
            "tokens": {
                "estimated_output": est_tokens,
                "full_module_tokens": full_tokens,
                "reduction_pct": round(
                    (1 - est_tokens / max(full_tokens, 1)) * 100, 1
                ),
            },
        }

    def _get_section_outline(self, section: Dict[str, Any]) -> str:
        """Return headings + contract/interface declarations only."""
        lines = self._read_lines(
            section["module_file"], section["start_line"], section["end_line"]
        ).split("\n")

        outline = []
        in_code = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("```"):
                in_code = not in_code
                continue
            if not in_code:
                if stripped.startswith("#") or stripped.startswith("File:"):
                    outline.append(line)
            else:
                # In code: only keep contract/interface/library declarations
                if any(
                    stripped.startswith(kw)
                    for kw in ("contract ", "interface ", "library ", "abstract contract ")
                ):
                    outline.append(f"  {stripped}")
        return "\n".join(outline)

    def get_module_outline(self, module_file: str) -> Optional[Dict[str, Any]]:
        """Get the structural outline of a module (no code bodies)."""
        modules = self.index.get("modules", {})
        if module_file not in modules:
            # Try without .md
            module_file = module_file if module_file.endswith(".md") else f"{module_file}.md"
            if module_file not in modules:
                return None

        mod = modules[module_file]
        sections_data = []
        for sec_id in mod.get("sections", []):
            sec = self.index.get("sections", {}).get(sec_id, {})
            if sec:
                sections_data.append({
                    "id": sec_id,
                    "title": sec.get("title", ""),
                    "level": sec.get("level", 0),
                    "contracts": sec.get("contracts", []),
                    "code_blocks": sec.get("code_block_count", 0),
                    "summary": sec.get("summary", ""),
                })

        # Compute actual outline size instead of hardcoding
        import json as _json
        outline_str = _json.dumps(sections_data, ensure_ascii=False)
        outline_tokens = len(outline_str.encode("utf-8")) // 4
        full_tokens = mod["size_bytes"] // 4

        return {
            "module": module_file,
            "title": mod["title"],
            "description": mod["description"],
            "size_bytes": mod["size_bytes"],
            "line_count": mod["line_count"],
            "standards": mod.get("standards", []),
            "sections": sections_data,
            "tokens": {
                "estimated_output": outline_tokens,
                "full_module_tokens": full_tokens,
                "reduction_pct": round(
                    (1 - outline_tokens / max(full_tokens, 1)) * 100, 1
                ),
            },
        }
