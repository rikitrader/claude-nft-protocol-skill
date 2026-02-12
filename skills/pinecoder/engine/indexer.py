"""Parse cached Pine Script markdown docs into a searchable JSON index.

Extracts sections, functions, types, and code examples with byte offsets
for targeted extraction (90%+ token reduction vs loading full pages).
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .schema import CodeExample, FunctionDoc, Index, Section, TypeDoc


# Regex patterns for Pine Script elements
_HEADING_RE = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)
_CODE_BLOCK_RE = re.compile(r"```(\w*)\n(.*?)```", re.DOTALL)
_FUNC_CALL_RE = re.compile(r"\b([a-z][a-z0-9]*(?:\.[a-z_][a-z0-9_]*))\s*\(", re.IGNORECASE)
_FUNC_SIGNATURE_RE = re.compile(
    r"([a-zA-Z_]\w*(?:\.\w+)*)\s*\(([^)]*)\)\s*(?:→|->|=>)\s*(.+)"
)
_TYPE_RE = re.compile(
    r"\b(int|float|bool|string|color|series|simple|input|const|"
    r"label|line|box|table|linefill|polyline|chart\.point|map|matrix|array)\b"
)
_NAMESPACE_RE = re.compile(r"^([a-z]+)\.")

# Pine Script namespaces for function classification
NAMESPACES = {
    "ta", "math", "str", "array", "matrix", "map", "strategy",
    "chart", "color", "input", "label", "line", "box", "table",
    "linefill", "polyline", "request", "ticker", "timeframe",
    "syminfo", "bar_index", "runtime", "alert", "log", "type",
}


def _slug(text: str) -> str:
    """Convert heading text to a URL-safe slug."""
    s = text.lower().strip()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_]+", "-", s)
    return s.strip("-")


def _category_from_path(file_path: str) -> str:
    """Infer doc category from file path."""
    p = file_path.lower()
    if "primer" in p:
        return "primer"
    if "language" in p:
        return "language"
    if "concepts" in p:
        return "concepts"
    if "visuals" in p:
        return "visuals"
    if "writing" in p:
        return "writing"
    if "faq" in p:
        return "faq"
    if "error" in p or "migration" in p or "release" in p:
        return "reference"
    return "general"


def _extract_keywords(text: str) -> List[str]:
    """Extract searchable keywords from a text block."""
    # Find Pine Script function references
    funcs = set(_FUNC_CALL_RE.findall(text))
    # Find type references
    types = set(_TYPE_RE.findall(text))
    # Find notable terms
    words = set()
    for word in re.findall(r"\b[a-zA-Z_]\w{2,}\b", text):
        w = word.lower()
        if w not in {"the", "and", "for", "that", "this", "with", "from", "are", "was",
                      "will", "can", "not", "but", "has", "its", "have", "when", "each"}:
            words.add(w)
    return sorted(funcs | types | words)[:50]  # Cap at 50 keywords


def _index_sections(
    content: str,
    source_file: str,
    category: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract all heading-based sections with byte offsets."""
    sections: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    headings: List[Tuple[int, int, str, int]] = []  # (byte_start, level, title, line_idx)

    byte_pos = 0
    for line_idx, line in enumerate(content.split("\n")):
        m = _HEADING_RE.match(line)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            headings.append((byte_pos, level, title, line_idx))
        byte_pos += len(line.encode("utf-8")) + 1  # +1 for newline

    for i, (byte_start, level, title, line_idx) in enumerate(headings):
        # Section ends at next heading at same or higher level (lower number), or EOF
        byte_end = len(content_bytes)
        for j in range(i + 1, len(headings)):
            if headings[j][1] <= level:  # same or higher level heading
                byte_end = headings[j][0]
                break

        byte_length = byte_end - byte_start
        section_content = content_bytes[byte_start:byte_end].decode("utf-8", errors="replace")

        # Count pine code blocks in this section
        code_blocks = len(re.findall(r"```(?:pine|pinescript)?", section_content))

        section_id = f"{category}/{_slug(title)}"
        # Handle duplicates by appending index
        if section_id in sections:
            section_id = f"{section_id}-{i}"

        # Build parent chain
        parent = None
        for j in range(i - 1, -1, -1):
            if headings[j][1] < level:
                parent_title = headings[j][2]
                parent = f"{category}/{_slug(parent_title)}"
                break

        keywords = _extract_keywords(section_content)

        sections[section_id] = asdict(Section(
            id=section_id,
            title=title,
            level=level,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_length,
            category=category,
            summary=section_content[:200].replace("\n", " ").strip(),
            parent=parent,
            subsections=[],
            code_blocks=code_blocks,
            keywords=keywords,
        ))

    # Wire subsection relationships
    for sid, sec in sections.items():
        parent_id = sec.get("parent")
        if parent_id and parent_id in sections:
            sections[parent_id]["subsections"].append(sid)

    return sections


def _index_functions(
    content: str,
    source_file: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract Pine Script function references from documentation content."""
    functions: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    # Look for function documentation patterns:
    # - Headings that match function names (e.g. "## ta.sma")
    # - Code blocks with function definitions
    # - Signature patterns

    # Pattern 1: Headings that look like function names
    for m in re.finditer(r"^#{2,4}\s+((?:[a-z]\w*\.)?[a-z_]\w*)\s*(?:\(|$)", content, re.MULTILINE):
        func_name = m.group(1)
        byte_start = len(content[:m.start()].encode("utf-8"))

        # Find the end of this function's section
        next_heading = re.search(r"^#{2,4}\s+", content[m.end():], re.MULTILINE)
        if next_heading:
            byte_end = len(content[:m.end() + next_heading.start()].encode("utf-8"))
        else:
            byte_end = len(content_bytes)

        section = content_bytes[byte_start:byte_end].decode("utf-8", errors="replace")

        # Extract namespace
        ns_match = _NAMESPACE_RE.match(func_name)
        namespace = ns_match.group(1) if ns_match else ""

        # Extract description (first non-heading paragraph)
        desc_lines = []
        for line in section.split("\n")[1:]:
            if line.strip().startswith("#") or line.strip().startswith("```"):
                break
            if line.strip():
                desc_lines.append(line.strip())
        description = " ".join(desc_lines)[:300]

        # Extract signature
        sig_match = _FUNC_SIGNATURE_RE.search(section)
        signature = sig_match.group(0) if sig_match else f"{func_name}()"

        func_id = f"fn/{func_name}"
        functions[func_id] = asdict(FunctionDoc(
            name=func_name,
            signature=signature,
            description=description,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_end - byte_start,
            namespace=namespace,
            returns="",
            parameters=[],
            examples=[],
            see_also=[],
        ))

    # Pattern 2: Inline function references in code blocks
    for code_match in _CODE_BLOCK_RE.finditer(content):
        lang = code_match.group(1).lower()
        if lang not in ("pine", "pinescript", ""):
            continue
        code = code_match.group(2)
        for func_match in _FUNC_CALL_RE.finditer(code):
            func_name = func_match.group(1)
            if "." in func_name:
                ns = func_name.split(".")[0]
                if ns in NAMESPACES:
                    func_id = f"fn/{func_name}"
                    if func_id not in functions:
                        byte_start = len(content[:code_match.start()].encode("utf-8"))
                        functions[func_id] = asdict(FunctionDoc(
                            name=func_name,
                            signature=f"{func_name}()",
                            description=f"Pine Script built-in: {func_name}",
                            source_file=source_file,
                            byte_offset=byte_start,
                            byte_length=len(code_match.group(0).encode("utf-8")),
                            namespace=ns,
                        ))

    return functions


def _index_examples(
    content: str,
    source_file: str,
    category: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract all code examples with byte offsets."""
    examples: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    # Find parent section for each code block
    current_section = "root"
    heading_positions = list(_HEADING_RE.finditer(content))

    for i, m in enumerate(_CODE_BLOCK_RE.finditer(content)):
        lang = m.group(1).lower()
        if lang not in ("pine", "pinescript", ""):
            continue

        byte_start = len(content[:m.start()].encode("utf-8"))
        byte_length = len(m.group(0).encode("utf-8"))

        # Find parent section
        code_pos = m.start()
        for hm in reversed(heading_positions):
            if hm.start() < code_pos:
                current_section = _slug(hm.group(2).strip())
                break

        example_id = f"ex/{category}/{current_section}-{i}"

        # Get 1-2 lines before the code block as description
        pre_text = content[max(0, m.start() - 200):m.start()]
        desc_lines = [l.strip() for l in pre_text.split("\n") if l.strip() and not l.startswith("#")]
        description = desc_lines[-1] if desc_lines else ""

        examples[example_id] = asdict(CodeExample(
            id=example_id,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_length,
            section_id=f"{category}/{current_section}",
            language=lang or "pine",
            description=description[:200],
        ))

    return examples


def build_index(raw_dir: Path) -> Index:
    """Build a complete search index from all cached markdown files.

    Args:
        raw_dir: Directory containing scraped .md files.

    Returns:
        Populated Index object.
    """
    all_sections: Dict[str, Any] = {}
    all_functions: Dict[str, Any] = {}
    all_types: Dict[str, Any] = {}
    all_examples: Dict[str, Any] = {}

    md_files = sorted(raw_dir.glob("*.md"))
    if not md_files:
        raise FileNotFoundError(f"No markdown files found in {raw_dir}")

    for md_file in md_files:
        if md_file.name.startswith("_"):
            continue  # Skip manifest

        content = md_file.read_text(encoding="utf-8")
        rel_path = str(md_file.relative_to(raw_dir.parent.parent))  # relative to skill root
        category = _category_from_path(md_file.name)

        # Index sections
        sections = _index_sections(content, rel_path, category)
        all_sections.update(sections)

        # Index functions
        functions = _index_functions(content, rel_path)
        all_functions.update(functions)

        # Index code examples
        examples = _index_examples(content, rel_path, category)
        all_examples.update(examples)

    # Compute source hash for freshness checks
    source_hash = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        source_hash.update(md_file.read_bytes())

    stats = {
        "total_sections": len(all_sections),
        "total_functions": len(all_functions),
        "total_types": len(all_types),
        "total_examples": len(all_examples),
        "total_files": len(md_files),
        "total_bytes": sum(f.stat().st_size for f in md_files),
    }

    return Index(
        version="1.0.0",
        generated_at=datetime.now(timezone.utc).isoformat(),
        source_hash=source_hash.hexdigest()[:16],
        sections=all_sections,
        functions=all_functions,
        types=all_types,
        examples=all_examples,
        stats=stats,
    )


def check_index_freshness(index: Index, raw_dir: Path) -> bool:
    """Check if the index matches the current source files."""
    current_hash = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        current_hash.update(md_file.read_bytes())
    return index.source_hash == current_hash.hexdigest()[:16]
