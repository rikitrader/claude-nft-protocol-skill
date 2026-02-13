"""Parse raw script markdown files into a searchable JSON index.

Extracts script metadata, description, and source code byte offsets
for targeted extraction (90%+ token reduction vs loading full files).
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

from .schema import CodeExample, Index, ScriptDoc

_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_HEADING_RE = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)
_CODE_BLOCK_RE = re.compile(r"```(\w*)\n(.*?)```", re.DOTALL)


def _parse_yaml_frontmatter(text: str) -> Dict[str, Any]:
    """Parse simple YAML frontmatter (stdlib-only, no PyYAML)."""
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return {}
    result: Dict[str, Any] = {}
    for line in m.group(1).split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        # Handle lists: [item1, item2]
        if val.startswith("[") and val.endswith("]"):
            items = [v.strip().strip("'\"") for v in val[1:-1].split(",")]
            result[key] = [i for i in items if i]
        # Handle booleans
        elif val.lower() in ("true", "false"):
            result[key] = val.lower() == "true"
        # Handle integers
        elif val.isdigit():
            result[key] = int(val)
        # Handle quoted strings
        elif (val.startswith('"') and val.endswith('"')) or \
             (val.startswith("'") and val.endswith("'")):
            result[key] = val[1:-1]
        else:
            result[key] = val
    return result


def _extract_keywords(text: str) -> List[str]:
    """Extract searchable keywords from text."""
    stopwords = {
        "the", "and", "for", "that", "this", "with", "from", "are", "was",
        "will", "can", "not", "but", "has", "its", "have", "when", "each",
        "you", "use", "all", "set", "get", "new", "one", "two", "also",
        "may", "any", "see", "how", "what", "which", "their", "than",
    }
    words = set()
    for word in re.findall(r"\b[a-zA-Z_]\w{2,}\b", text):
        w = word.lower()
        if w not in stopwords:
            words.add(w)
    return sorted(words)[:50]


def _find_section_offsets(content: str) -> Dict[str, Tuple[int, int]]:
    """Find byte offsets for Description and Source Code sections."""
    content_bytes = content.encode("utf-8")
    offsets: Dict[str, Tuple[int, int]] = {}

    byte_pos = 0
    headings: List[Tuple[int, int, str]] = []  # (byte_start, level, title)
    for line in content.split("\n"):
        m = _HEADING_RE.match(line)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            headings.append((byte_pos, level, title))
        byte_pos += len(line.encode("utf-8")) + 1

    for i, (byte_start, level, title) in enumerate(headings):
        byte_end = len(content_bytes)
        for j in range(i + 1, len(headings)):
            if headings[j][1] <= level:
                byte_end = headings[j][0]
                break
        offsets[title.lower()] = (byte_start, byte_end - byte_start)

    return offsets


def _index_script(content: str, source_file: str) -> Tuple[
    Dict[str, Any] | None,
    List[Dict[str, Any]],
]:
    """Index a single script file, returning (script_dict, examples_list)."""
    meta = _parse_yaml_frontmatter(content)
    if not meta.get("id"):
        return None, []

    content_bytes = content.encode("utf-8")
    total_len = len(content_bytes)

    # Find frontmatter end
    fm_match = _FRONTMATTER_RE.match(content)
    body_start = len(fm_match.group(0).encode("utf-8")) + 1 if fm_match else 0

    # Find section offsets
    section_offsets = _find_section_offsets(content)

    desc_offset, desc_length = section_offsets.get(
        "description", (body_start, total_len - body_start)
    )
    src_offset, src_length = section_offsets.get(
        "source code", (0, 0)
    )

    # Extract keywords from description
    desc_text = content_bytes[desc_offset:desc_offset + desc_length].decode(
        "utf-8", errors="replace"
    )
    keywords = _extract_keywords(desc_text)

    script = asdict(ScriptDoc(
        id=meta["id"],
        title=meta.get("title", ""),
        author=meta.get("author", ""),
        script_type=meta.get("type", "indicator"),
        source_file=source_file,
        byte_offset=body_start,
        byte_length=total_len - body_start,
        desc_offset=desc_offset,
        desc_length=desc_length,
        src_offset=src_offset,
        src_length=src_length,
        tags=meta.get("tags", []),
        boosts=meta.get("boosts", 0),
        views=meta.get("views", 0),
        has_source=meta.get("has_source", True),
        slug=meta.get("slug", ""),
        keywords=keywords,
    ))

    # Extract code examples
    examples: List[Dict[str, Any]] = []
    for i, m in enumerate(_CODE_BLOCK_RE.finditer(content)):
        lang = m.group(1).lower()
        if lang not in ("pine", "pinescript", ""):
            continue
        byte_start = len(content[:m.start()].encode("utf-8"))
        byte_length = len(m.group(0).encode("utf-8"))
        ex_id = f"ex/{meta['id']}-{i}"
        examples.append(asdict(CodeExample(
            id=ex_id,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_length,
            script_id=meta["id"],
            language=lang or "pine",
            description=meta.get("title", "")[:200],
        )))

    return script, examples


def build_index(raw_dir: Path) -> Index:
    """Build a complete search index from all raw script markdown files."""
    all_scripts: Dict[str, Any] = {}
    all_examples: Dict[str, Any] = {}
    all_tags: Dict[str, List[str]] = {}
    all_authors: Dict[str, List[str]] = {}

    md_files = sorted(raw_dir.glob("*.md"))
    if not md_files:
        raise FileNotFoundError(f"No markdown files found in {raw_dir}")

    for md_file in md_files:
        content = md_file.read_text(encoding="utf-8")
        rel_path = str(md_file.relative_to(raw_dir.parent.parent))

        script, examples = _index_script(content, rel_path)
        if script is None:
            continue

        sid = script["id"]
        all_scripts[sid] = script

        for ex in examples:
            all_examples[ex["id"]] = ex

        # Build tag index
        for tag in script.get("tags", []):
            tag_lower = tag.lower()
            if tag_lower not in all_tags:
                all_tags[tag_lower] = []
            all_tags[tag_lower].append(sid)

        # Build author index
        author = script.get("author", "")
        if author:
            if author not in all_authors:
                all_authors[author] = []
            all_authors[author].append(sid)

    # Compute source hash
    source_hash = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        source_hash.update(md_file.read_bytes())

    stats = {
        "total_scripts": len(all_scripts),
        "total_examples": len(all_examples),
        "total_tags": len(all_tags),
        "total_authors": len(all_authors),
        "total_files": len(md_files),
        "total_bytes": sum(f.stat().st_size for f in md_files),
        "scripts_with_source": sum(
            1 for s in all_scripts.values() if s.get("has_source")
        ),
    }

    return Index(
        version="1.0.0",
        generated_at=datetime.now(timezone.utc).isoformat(),
        source_hash=source_hash.hexdigest()[:16],
        scripts=all_scripts,
        examples=all_examples,
        tags=all_tags,
        authors=all_authors,
        stats=stats,
    )


def check_index_freshness(index: Index, raw_dir: Path) -> bool:
    """Check if the index matches the current source files."""
    current_hash = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        current_hash.update(md_file.read_bytes())
    return index.source_hash == current_hash.hexdigest()[:16]
