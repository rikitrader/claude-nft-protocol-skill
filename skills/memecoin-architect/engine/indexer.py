"""Parse all skill content and build the JSON search index with byte offsets."""
from __future__ import annotations

import hashlib
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from .schema import Index

# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------
RE_HEADING = re.compile(r"^(#{1,6})\s+(.+)$")
RE_CODE_FENCE = re.compile(r"^```([a-zA-Z0-9_-]*)")
RE_CODE_END = re.compile(r"^```\s*$")

# Rust / Anchor
RE_RUST_FN = re.compile(r"^\s*pub\s+fn\s+(\w+)")
RE_RUST_STRUCT = re.compile(r"^\s*(?:#\[.*\]\s*)*pub\s+struct\s+(\w+)")
RE_RUST_ENUM = re.compile(r"^\s*(?:#\[.*\]\s*)*pub\s+enum\s+(\w+)")
RE_RUST_EVENT = re.compile(r"#\[event\]")
RE_RUST_PROGRAM = re.compile(r"#\[program\]")
RE_RUST_ACCOUNTS = re.compile(r"#\[derive\(Accounts\)\]")
RE_RUST_ERROR = re.compile(r"#\[error_code\]")

# TSX / TS exports
RE_EXPORT_FN = re.compile(r"export\s+(?:default\s+)?function\s+(\w+)")
RE_EXPORT_CONST = re.compile(r"export\s+(?:default\s+)?const\s+(\w+)")
RE_EXPORT_DEFAULT = re.compile(r"export\s+default\s+(\w+)")
RE_IMPORT_FROM = re.compile(r'import\s+.*?from\s+["\'](.+?)["\']')

# CSS section comments
RE_CSS_SECTION = re.compile(r"/\*\s*={3,}.*?={3,}\s*\*/", re.DOTALL)
RE_CSS_SECTION_TITLE = re.compile(r"^\s*([A-Z][A-Z &/()-]+)\s*$", re.MULTILINE)


def _slugify(text: str) -> str:
    """Convert text to a URL-safe slug."""
    s = text.lower().strip()
    s = re.sub(r"[^a-z0-9\s-]", "", s)
    s = re.sub(r"[\s-]+", "-", s).strip("-")
    return s[:80]


def _byte_offset_of_line(content: str, line_num: int) -> int:
    """Get byte offset of a 0-indexed line number."""
    offset = 0
    for i, line in enumerate(content.split("\n")):
        if i == line_num:
            return offset
        offset += len(line.encode("utf-8")) + 1
    return offset


def _byte_length_of_range(content: str, start: int, end: int) -> int:
    """Get byte length from start_line to end_line (0-indexed, inclusive)."""
    lines = content.split("\n")
    selected = "\n".join(lines[start: end + 1])
    return len(selected.encode("utf-8"))


def _extract_first_paragraph(lines: List[str], start: int) -> str:
    """Extract first non-empty paragraph after a heading."""
    result: List[str] = []
    for i in range(start, min(start + 10, len(lines))):
        line = lines[i].strip()
        if not line:
            if result:
                break
            continue
        if line.startswith("#") or line.startswith("```"):
            break
        result.append(line)
    return " ".join(result)[:200]


def _detect_route_group(rel_path: str) -> Optional[str]:
    """Detect Next.js route group from file path."""
    if "(dashboard)/admin" in rel_path:
        return "(dashboard)/admin"
    if "(dashboard)" in rel_path:
        return "(dashboard)"
    if "(landing)" in rel_path:
        return "(landing)"
    return None


def _detect_component_type(rel_path: str) -> str:
    """Classify a template file by its role."""
    if "/hooks/" in rel_path:
        return "hook"
    if "/lib/" in rel_path:
        return "lib"
    if rel_path.endswith(".css"):
        return "style"
    if "/app/" in rel_path and rel_path.endswith("page.tsx"):
        return "page"
    if "/app/" in rel_path and rel_path.endswith("layout.tsx"):
        return "layout"
    return "component"


# ---------------------------------------------------------------------------
# Markdown indexer
# ---------------------------------------------------------------------------
def _index_markdown(
    file_path: Path, skill_dir: Path, sections: Dict[str, Any], file_hash: str
) -> Dict[str, Any]:
    """Index a markdown file by heading structure."""
    content = file_path.read_text(encoding="utf-8")
    lines = content.split("\n")
    rel = str(file_path.relative_to(skill_dir))
    file_bytes = len(content.encode("utf-8"))

    # Determine category
    if "references/" in rel:
        category = "reference"
    elif rel == "SKILL.md":
        category = "skill"
    else:
        category = "template-doc"

    # Find headings
    raw_sections: List[Dict[str, Any]] = []
    for i, line in enumerate(lines):
        m = RE_HEADING.match(line)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            if not title or title.startswith("===") or title.startswith("---"):
                continue
            slug = _slugify(title)
            if not slug:
                continue
            raw_sections.append({
                "title": title, "level": level, "start_line": i, "slug": slug,
            })

    # Compute end lines
    for j, sec in enumerate(raw_sections):
        if j + 1 < len(raw_sections):
            sec["end_line"] = raw_sections[j + 1]["start_line"] - 1
        else:
            sec["end_line"] = len(lines) - 1

    section_ids: List[str] = []
    for sec in raw_sections:
        sec_id = f"{category}/{_slugify(Path(rel).stem)}/{sec['slug']}"
        # Deduplicate
        base_id = sec_id
        counter = 2
        while sec_id in sections:
            sec_id = f"{base_id}-{counter}"
            counter += 1

        byte_off = _byte_offset_of_line(content, sec["start_line"])
        byte_len = _byte_length_of_range(content, sec["start_line"], sec["end_line"])
        summary = _extract_first_paragraph(lines, sec["start_line"] + 1)

        sections[sec_id] = {
            "id": sec_id,
            "title": sec["title"],
            "level": sec["level"],
            "source_file": rel,
            "start_line": sec["start_line"],
            "end_line": sec["end_line"],
            "byte_offset": byte_off,
            "byte_length": byte_len,
            "summary": summary,
            "category": category,
        }
        section_ids.append(sec_id)

    return {
        "file": rel,
        "category": category,
        "size_bytes": file_bytes,
        "line_count": len(lines),
        "section_ids": section_ids,
        "hash": file_hash,
    }


# ---------------------------------------------------------------------------
# Rust / Anchor contract indexer
# ---------------------------------------------------------------------------
def _index_rust(
    file_path: Path, skill_dir: Path, contracts: Dict[str, Any], file_hash: str
) -> Dict[str, Any]:
    """Index an Anchor Rust program file."""
    content = file_path.read_text(encoding="utf-8")
    lines = content.split("\n")
    rel = str(file_path.relative_to(skill_dir))
    file_bytes = len(content.encode("utf-8"))
    program_name = file_path.stem  # e.g. "treasury_vault"

    instructions: List[str] = []
    accounts: List[str] = []
    events: List[str] = []
    errors: List[str] = []

    in_program = False
    in_accounts = False
    in_error = False
    next_is_event = False

    for i, line in enumerate(lines):
        if RE_RUST_PROGRAM.search(line):
            in_program = True
            continue
        if RE_RUST_ACCOUNTS.search(line):
            in_accounts = True
            continue
        if RE_RUST_ERROR.search(line):
            in_error = True
            continue
        if RE_RUST_EVENT.search(line):
            next_is_event = True
            continue

        if next_is_event:
            m = RE_RUST_STRUCT.match(line)
            if m:
                events.append(m.group(1))
            next_is_event = False
            continue

        if in_error:
            m = RE_RUST_ENUM.match(line)
            if m:
                errors.append(m.group(1))
                in_error = False
            continue

        if in_accounts:
            m = RE_RUST_STRUCT.match(line)
            if m:
                accounts.append(m.group(1))
                in_accounts = False
            continue

        if in_program:
            m = RE_RUST_FN.match(line)
            if m:
                instructions.append(m.group(1))

    contract_id = f"contracts/{program_name}"
    contracts[contract_id] = {
        "name": program_name,
        "source_file": rel,
        "program_name": program_name,
        "byte_offset": 0,
        "byte_length": file_bytes,
        "instructions": instructions,
        "accounts": accounts,
        "events": events,
        "errors": errors,
    }

    return {
        "file": rel,
        "size_bytes": file_bytes,
        "line_count": len(lines),
        "instructions": instructions,
        "accounts": accounts,
        "hash": file_hash,
    }


# ---------------------------------------------------------------------------
# Template indexer (TSX / TS / CSS)
# ---------------------------------------------------------------------------
def _index_template(
    file_path: Path, skill_dir: Path, templates: Dict[str, Any], file_hash: str
) -> Dict[str, Any]:
    """Index a TSX/TS/CSS template file."""
    content = file_path.read_text(encoding="utf-8")
    rel = str(file_path.relative_to(skill_dir))
    file_bytes = len(content.encode("utf-8"))

    exports: List[str] = []
    imports: List[str] = []

    for m in RE_EXPORT_FN.finditer(content):
        exports.append(m.group(1))
    for m in RE_EXPORT_CONST.finditer(content):
        exports.append(m.group(1))
    for m in RE_IMPORT_FROM.finditer(content):
        imports.append(m.group(1))

    component_type = _detect_component_type(rel)
    route_group = _detect_route_group(rel)
    name = file_path.stem
    if name == "page" or name == "layout":
        # Use parent dir for page/layout disambiguation
        parent = file_path.parent.name
        if parent.startswith("("):
            name = f"{parent}/{name}"
        else:
            name = f"{parent}/{name}" if parent != "app" else name

    template_id = f"templates/{rel.replace('templates/aura/', '')}"
    templates[template_id] = {
        "name": name,
        "source_file": rel,
        "component_type": component_type,
        "route_group": route_group,
        "byte_offset": 0,
        "byte_length": file_bytes,
        "exports": exports,
        "imports": imports,
    }

    return {
        "file": rel,
        "size_bytes": file_bytes,
        "component_type": component_type,
        "route_group": route_group,
        "hash": file_hash,
    }


# ---------------------------------------------------------------------------
# Script indexer (TS / SH / PY)
# ---------------------------------------------------------------------------
def _index_script(
    file_path: Path, skill_dir: Path, scripts_dict: Dict[str, Any], file_hash: str
) -> Dict[str, Any]:
    """Index a script file."""
    content = file_path.read_text(encoding="utf-8")
    rel = str(file_path.relative_to(skill_dir))
    file_bytes = len(content.encode("utf-8"))
    lines = content.split("\n")

    # Determine script type from parent directory
    parent = file_path.parent.name
    type_map = {
        "deploy": "deploy", "security": "security",
        "dex": "dex", "marketing": "marketing",
    }
    script_type = type_map.get(parent, "other")

    # Extract first comment/docstring as description
    description = ""
    for line in lines[:10]:
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("#"):
            description = stripped.lstrip("/#! ").strip()
            break
        if stripped.startswith("/**") or stripped.startswith("\"\"\""):
            description = stripped.strip("/*\" ").strip()
            break

    script_id = f"scripts/{rel.replace('scripts/', '')}"
    scripts_dict[script_id] = {
        "name": file_path.name,
        "source_file": rel,
        "script_type": script_type,
        "byte_offset": 0,
        "byte_length": file_bytes,
        "description": description[:200],
    }

    return {
        "file": rel,
        "size_bytes": file_bytes,
        "script_type": script_type,
        "hash": file_hash,
    }


# ---------------------------------------------------------------------------
# Main index builder
# ---------------------------------------------------------------------------
def build_index(skill_dir: Path) -> Index:
    """Build the complete index from all skill content."""
    index = Index(
        version="1.0.0",
        generated_at=datetime.now(timezone.utc).isoformat(),
    )

    all_hashes: List[str] = []
    total_bytes = 0
    total_files = 0

    # 1. Index markdown files (references + SKILL.md)
    md_files: List[Path] = []
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        md_files.extend(sorted(refs_dir.glob("*.md")))
    skill_md = skill_dir / "SKILL.md"
    if skill_md.exists():
        md_files.append(skill_md)

    for md_file in md_files:
        content = md_file.read_bytes()
        file_hash = hashlib.sha256(content).hexdigest()
        all_hashes.append(file_hash)
        total_bytes += len(content)
        total_files += 1
        _index_markdown(md_file, skill_dir, index.sections, file_hash)

    # 2. Index Anchor Rust contracts
    contracts_dir = skill_dir / "scripts" / "anchor_contracts"
    if contracts_dir.exists():
        for rs_file in sorted(contracts_dir.glob("*.rs")):
            content = rs_file.read_bytes()
            file_hash = hashlib.sha256(content).hexdigest()
            all_hashes.append(file_hash)
            total_bytes += len(content)
            total_files += 1
            _index_rust(rs_file, skill_dir, index.contracts, file_hash)

    # 3. Index Aura templates (TSX / TS / CSS)
    templates_dir = skill_dir / "templates" / "aura"
    if templates_dir.exists():
        for ext in ("**/*.tsx", "**/*.ts", "**/*.css"):
            for tmpl_file in sorted(templates_dir.glob(ext)):
                content = tmpl_file.read_bytes()
                file_hash = hashlib.sha256(content).hexdigest()
                all_hashes.append(file_hash)
                total_bytes += len(content)
                total_files += 1
                _index_template(tmpl_file, skill_dir, index.templates, file_hash)

    # 4. Index scripts (deploy, security, dex, marketing)
    scripts_dir = skill_dir / "scripts"
    if scripts_dir.exists():
        for subdir in ("deploy", "security", "dex", "marketing"):
            sub_path = scripts_dir / subdir
            if not sub_path.exists():
                continue
            for script_file in sorted(sub_path.iterdir()):
                if script_file.is_file() and not script_file.name.startswith("."):
                    content = script_file.read_bytes()
                    file_hash = hashlib.sha256(content).hexdigest()
                    all_hashes.append(file_hash)
                    total_bytes += len(content)
                    total_files += 1
                    _index_script(script_file, skill_dir, index.scripts, file_hash)

    # Compute combined source hash
    combined = "".join(sorted(all_hashes))
    index.source_hash = hashlib.sha256(combined.encode()).hexdigest()

    index.stats = {
        "total_files": total_files,
        "total_sections": len(index.sections),
        "total_templates": len(index.templates),
        "total_contracts": len(index.contracts),
        "total_scripts": len(index.scripts),
        "total_source_bytes": total_bytes,
        "total_index_entries": (
            len(index.sections) + len(index.templates)
            + len(index.contracts) + len(index.scripts)
        ),
    }

    return index


def check_index_freshness(index: Index, skill_dir: Path) -> bool:
    """Check if the index is still valid (source files haven't changed)."""
    all_hashes: List[str] = []

    for search_path, pattern in [
        (skill_dir / "references", "*.md"),
        (skill_dir / "scripts" / "anchor_contracts", "*.rs"),
    ]:
        if search_path.exists():
            for f in sorted(search_path.glob(pattern)):
                all_hashes.append(hashlib.sha256(f.read_bytes()).hexdigest())

    skill_md = skill_dir / "SKILL.md"
    if skill_md.exists():
        all_hashes.append(hashlib.sha256(skill_md.read_bytes()).hexdigest())

    templates_dir = skill_dir / "templates" / "aura"
    if templates_dir.exists():
        for ext in ("**/*.tsx", "**/*.ts", "**/*.css"):
            for f in sorted(templates_dir.glob(ext)):
                all_hashes.append(hashlib.sha256(f.read_bytes()).hexdigest())

    scripts_dir = skill_dir / "scripts"
    if scripts_dir.exists():
        for subdir in ("deploy", "security", "dex", "marketing"):
            sub_path = scripts_dir / subdir
            if sub_path.exists():
                for f in sorted(sub_path.iterdir()):
                    if f.is_file() and not f.name.startswith("."):
                        all_hashes.append(hashlib.sha256(f.read_bytes()).hexdigest())

    combined = "".join(sorted(all_hashes))
    current_hash = hashlib.sha256(combined.encode()).hexdigest()
    return current_hash == index.source_hash
