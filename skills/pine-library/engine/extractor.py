"""Targeted content extraction using byte offsets from the index.

Reads only the exact bytes needed — typically 90%+ reduction vs full file loading.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional


class Extractor:
    """Extract specific Pine Script community script content using byte offsets."""

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
    # Script extraction
    # -------------------------------------------------------------------
    def get_script(self, script_id: str) -> Optional[Dict[str, Any]]:
        """Extract full script data (metadata + description + source)."""
        scripts = self.index.get("scripts", {})
        matched_id = self._match_id(script_id, scripts)
        if not matched_id:
            return None

        s = scripts[matched_id]
        source = s["source_file"]
        content = self._read_bytes(source, s["byte_offset"], s["byte_length"])

        return {
            "id": matched_id,
            "title": s["title"],
            "author": s["author"],
            "script_type": s["script_type"],
            "tags": s.get("tags", []),
            "boosts": s.get("boosts", 0),
            "views": s.get("views", 0),
            "has_source": s.get("has_source", True),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def get_description(self, script_id: str) -> Optional[Dict[str, Any]]:
        """Extract only the description section of a script."""
        scripts = self.index.get("scripts", {})
        matched_id = self._match_id(script_id, scripts)
        if not matched_id:
            return None

        s = scripts[matched_id]
        source = s["source_file"]
        if s["desc_length"] == 0:
            return {"id": matched_id, "content": "", "tokens": {}}
        content = self._read_bytes(source, s["desc_offset"], s["desc_length"])

        return {
            "id": matched_id,
            "title": s["title"],
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def get_source(self, script_id: str) -> Optional[Dict[str, Any]]:
        """Extract only the Pine Script source code of a script."""
        scripts = self.index.get("scripts", {})
        matched_id = self._match_id(script_id, scripts)
        if not matched_id:
            return None

        s = scripts[matched_id]
        source = s["source_file"]
        if s["src_length"] == 0:
            return {"id": matched_id, "content": "(no source code available)",
                    "tokens": {}}
        content = self._read_bytes(source, s["src_offset"], s["src_length"])

        return {
            "id": matched_id,
            "title": s["title"],
            "author": s["author"],
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def list_scripts(
        self,
        script_type: Optional[str] = None,
        tag: Optional[str] = None,
        author: Optional[str] = None,
        sort_by: str = "boosts",
        limit: int = 20,
    ) -> List[Dict[str, Any]]:
        """List scripts with optional filters."""
        scripts = self.index.get("scripts", {})
        results = []

        for sid, s in scripts.items():
            if script_type and s.get("script_type") != script_type:
                continue
            if tag and tag.lower() not in [t.lower() for t in s.get("tags", [])]:
                continue
            if author and s.get("author", "").lower() != author.lower():
                continue

            results.append({
                "id": sid,
                "title": s["title"],
                "author": s["author"],
                "script_type": s["script_type"],
                "tags": s.get("tags", [])[:5],
                "boosts": s.get("boosts", 0),
                "has_source": s.get("has_source", True),
            })

        if sort_by == "boosts":
            results.sort(key=lambda r: r.get("boosts", 0), reverse=True)
        elif sort_by == "title":
            results.sort(key=lambda r: r.get("title", "").lower())
        elif sort_by == "author":
            results.sort(key=lambda r: r.get("author", "").lower())

        return results[:limit]

    def list_tags(self, min_count: int = 1) -> List[Dict[str, Any]]:
        """List all tags with script counts."""
        tags = self.index.get("tags", {})
        results = [
            {"tag": tag, "count": len(script_ids)}
            for tag, script_ids in tags.items()
            if len(script_ids) >= min_count
        ]
        results.sort(key=lambda r: r["count"], reverse=True)
        return results

    def list_authors(self, min_scripts: int = 1) -> List[Dict[str, Any]]:
        """List all authors with script counts."""
        authors = self.index.get("authors", {})
        results = [
            {"author": author, "count": len(script_ids)}
            for author, script_ids in authors.items()
            if len(script_ids) >= min_scripts
        ]
        results.sort(key=lambda r: r["count"], reverse=True)
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
            "script_id": ex.get("script_id", ""),
            "language": ex.get("language", "pine"),
            "description": ex.get("description", ""),
            "content": content,
            "tokens": self._token_stats(content, source),
        }

    def get_examples_for_topic(self, topic: str) -> List[Dict[str, Any]]:
        """Get code examples matching a topic (searches across scripts)."""
        from .searcher import _score
        examples = self.index.get("examples", {})
        results = []
        for ex_id, ex in examples.items():
            desc = ex.get("description", "")
            if _score(topic, desc) > 0.3 or _score(topic, ex_id) > 0.3:
                source = ex["source_file"]
                content = self._read_bytes(
                    source, ex["byte_offset"], ex["byte_length"]
                )
                results.append({
                    "id": ex_id,
                    "description": desc,
                    "content": content,
                })
        return results[:20]

    # -------------------------------------------------------------------
    # Universal extraction
    # -------------------------------------------------------------------
    def extract(self, entry_id: str) -> Optional[Dict[str, Any]]:
        """Extract any entry by ID, auto-detecting category."""
        if entry_id.startswith("ex/"):
            return self.get_example(entry_id)
        # Try script
        result = self.get_script(entry_id)
        if result:
            return result
        return None

    # -------------------------------------------------------------------
    # Helpers
    # -------------------------------------------------------------------
    @staticmethod
    def _match_id(target: str, entries: Dict[str, Any]) -> Optional[str]:
        """Match an entry ID — exact first, then case-insensitive, then partial."""
        if target in entries:
            return target
        # Normalize: space→hyphen for pattern name lookups
        normalized = target.replace(" ", "-")
        if normalized in entries:
            return normalized
        target_lower = target.lower()
        for k in entries:
            if target_lower == k.lower():
                return k
        for k in entries:
            if target_lower in k.lower():
                return k
        return None
