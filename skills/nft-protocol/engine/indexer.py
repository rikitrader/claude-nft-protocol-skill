"""Parse markdown modules and build the JSON search index."""
from __future__ import annotations

import hashlib
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .schema import CodeBlock, Contract, Index, ModuleInfo, Section

# Solidity keywords/types that the regex captures but are NOT contract names
SOLIDITY_KEYWORDS = frozenset({
    "event", "if", "for", "not", "with", "support", "supporting", "address",
    "interface", "first", "vm", "wallet", "exploits", "paymentToken", "ID",
    "is", "has", "the", "or", "and", "new", "this", "self", "type", "using",
    "return", "returns", "public", "private", "internal", "external", "view",
    "pure", "payable", "memory", "storage", "calldata", "override", "virtual",
    "abstract", "function", "modifier", "constructor", "receive", "fallback",
    "emit", "require", "revert", "assert", "mapping", "struct", "enum",
    "uint256", "uint128", "uint64", "uint32", "uint8", "int256", "bool",
    "string", "bytes", "bytes32", "bytes4", "uint", "int",
})

# Patterns
RE_HEADING = re.compile(r"^(#{1,6})\s+(.+)$")
RE_MODULE_NUM = re.compile(r"MODULE\s+(\d+)\s*:", re.IGNORECASE)
RE_CODE_FENCE = re.compile(r"^```([a-zA-Z0-9_-]*)")
RE_CODE_END = re.compile(r"^```\s*$")
RE_CONTRACT = re.compile(r"\bcontract\s+(\w+)")
RE_INTERFACE = re.compile(r"\binterface\s+(\w+)")
RE_LIBRARY = re.compile(r"\blibrary\s+(\w+)")
RE_STANDARD = re.compile(r"\b(ERC-?\d{3,5}|EIP-?\d{3,5})\b", re.IGNORECASE)
RE_IMPORT = re.compile(r'import\s+.*?["\'](.+?)["\']')
RE_FILE_PATH = re.compile(r"^File:\s*`(.+?)`", re.IGNORECASE)


def _slugify(text: str) -> str:
    """Convert heading text to a URL-safe slug."""
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
        offset += len(line.encode("utf-8")) + 1  # +1 for newline
    return offset


def _byte_length_of_range(content: str, start: int, end: int) -> int:
    """Get byte length from start_line to end_line (0-indexed, inclusive)."""
    lines = content.split("\n")
    selected = "\n".join(lines[start : end + 1])
    return len(selected.encode("utf-8"))


def _extract_first_paragraph(lines: List[str], start: int) -> str:
    """Extract first non-empty paragraph after a heading."""
    result = []
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


def _find_sections(content: str, file_name: str) -> List[Dict[str, Any]]:
    """Find all sections (headings) in a markdown file."""
    lines = content.split("\n")
    sections = []
    for i, line in enumerate(lines):
        m = RE_HEADING.match(line)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            # Skip empty headings or decorative separators
            if not title or title.startswith("===") or title.startswith("---"):
                continue
            # Build section ID
            mod_match = RE_MODULE_NUM.search(title)
            if mod_match:
                slug = f"module-{mod_match.group(1)}-{_slugify(title)}"
            else:
                slug = _slugify(title)
            if not slug:
                continue  # Skip sections that produce empty slugs
            sections.append({
                "id": slug,
                "title": title,
                "level": level,
                "start_line": i,
                "line": line,
            })
    # Compute end lines (each section ends just before the next heading)
    for j, sec in enumerate(sections):
        if j + 1 < len(sections):
            sec["end_line"] = sections[j + 1]["start_line"] - 1
        else:
            sec["end_line"] = len(lines) - 1
    return sections


def _find_code_blocks(content: str) -> List[Dict[str, Any]]:
    """Find all fenced code blocks in the content."""
    lines = content.split("\n")
    blocks = []
    in_block = False
    block_start = 0
    block_lang = ""
    for i, line in enumerate(lines):
        if not in_block:
            m = RE_CODE_FENCE.match(line.strip())
            if m and m.group(1):
                in_block = True
                block_start = i
                block_lang = m.group(1).lower()
        else:
            if RE_CODE_END.match(line.strip()):
                block_lines = lines[block_start + 1 : i]
                block_content = "\n".join(block_lines)
                blocks.append({
                    "language": block_lang,
                    "content": block_content,
                    "start_line": block_start,
                    "end_line": i,
                })
                in_block = False
    return blocks


def _is_valid_contract_name(name: str) -> bool:
    """Filter out Solidity keywords and invalid names captured by regex."""
    if len(name) < 2:
        return False
    if name.lower() in SOLIDITY_KEYWORDS:
        return False
    if not name[0].isupper():
        return False  # Solidity contracts are PascalCase
    return True


def _extract_contracts_from_code(code: str) -> List[str]:
    """Find contract/interface/library names in Solidity code."""
    names = []
    for pat in (RE_CONTRACT, RE_INTERFACE, RE_LIBRARY):
        names.extend(n for n in pat.findall(code) if _is_valid_contract_name(n))
    return names


def _extract_imports(code: str) -> List[str]:
    """Extract import paths from Solidity code."""
    return RE_IMPORT.findall(code)


def _extract_standards(text: str) -> List[str]:
    """Find all ERC/EIP standard references."""
    raw = RE_STANDARD.findall(text)
    normalized = set()
    for s in raw:
        s = s.upper().replace("EIP-", "ERC-").replace("ERC", "ERC-")
        s = re.sub(r"ERC--+", "ERC-", s)
        normalized.add(s)
    return sorted(normalized)


def _find_file_path_annotation(lines: List[str], code_start: int) -> Optional[str]:
    """Look for 'File: `path`' annotation above a code block."""
    for i in range(max(0, code_start - 3), code_start):
        m = RE_FILE_PATH.match(lines[i].strip())
        if m:
            return m.group(1)
    return None


def build_index(modules_dir: Path) -> Index:
    """Build the complete index from all markdown modules."""
    index = Index(
        version="1.0.0",
        generated_at=datetime.now(timezone.utc).isoformat(),
    )

    all_hashes = []
    total_sections = 0
    total_contracts = 0
    total_code_blocks = 0
    total_bytes = 0
    total_lines = 0

    md_files = sorted(modules_dir.glob("*.md"))

    for md_file in md_files:
        content = md_file.read_text(encoding="utf-8")
        lines_list = content.split("\n")
        file_name = md_file.name

        # Hash for cache invalidation
        file_hash = hashlib.sha256(content.encode("utf-8")).hexdigest()
        all_hashes.append(file_hash)

        # Module info
        file_bytes = len(content.encode("utf-8"))
        file_lines = len(lines_list)
        total_bytes += file_bytes
        total_lines += file_lines

        # Extract module title from first heading
        title = file_name.replace(".md", "").replace("-", " ").title()
        description = ""
        for line in lines_list[:20]:
            hm = RE_HEADING.match(line)
            if hm:
                title = hm.group(2).strip()
                break

        # Find sections
        raw_sections = _find_sections(content, file_name)
        section_ids = []
        module_contracts = []
        module_standards = set()

        # Find code blocks
        code_blocks = _find_code_blocks(content)
        total_code_blocks += len(code_blocks)

        for sec_data in raw_sections:
            sec_id = sec_data["id"]
            # Avoid duplicate IDs
            if sec_id in index.sections:
                sec_id = f"{sec_id}-{file_name.replace('.md', '')}"
            if sec_id in index.sections:
                sec_id = f"{sec_id}-{sec_data['start_line']}"

            sec_start = sec_data["start_line"]
            sec_end = sec_data["end_line"]

            byte_off = _byte_offset_of_line(content, sec_start)
            byte_len = _byte_length_of_range(content, sec_start, sec_end)

            summary = _extract_first_paragraph(
                lines_list, sec_start + 1
            )

            # Find contracts in this section's code blocks
            sec_contracts = []
            sec_code_count = 0
            for cb in code_blocks:
                if cb["start_line"] >= sec_start and cb["end_line"] <= sec_end:
                    sec_code_count += 1
                    if cb["language"] in ("solidity", "sol"):
                        names = _extract_contracts_from_code(cb["content"])
                        for name in names:
                            if name not in index.contracts:
                                cb_off = _byte_offset_of_line(
                                    content, cb["start_line"]
                                )
                                cb_len = _byte_length_of_range(
                                    content, cb["start_line"], cb["end_line"]
                                )
                                fp = _find_file_path_annotation(
                                    lines_list, cb["start_line"]
                                )
                                stds = _extract_standards(cb["content"])
                                imps = _extract_imports(cb["content"])
                                module_standards.update(stds)

                                index.contracts[name] = {
                                    "name": name,
                                    "module_file": file_name,
                                    "section_id": sec_id,
                                    "language": cb["language"],
                                    "start_line": cb["start_line"],
                                    "end_line": cb["end_line"],
                                    "byte_offset": cb_off,
                                    "byte_length": cb_len,
                                    "file_path": fp,
                                    "standards": stds,
                                    "imports": imps,
                                }
                                sec_contracts.append(name)
                                module_contracts.append(name)
                                total_contracts += 1

                                # Update standards reverse index
                                for std in stds:
                                    if std not in index.standards:
                                        index.standards[std] = []
                                    if name not in index.standards[std]:
                                        index.standards[std].append(name)

            # Also find standards in the section text (not just code)
            sec_text = "\n".join(
                lines_list[sec_start : sec_end + 1]
            )
            text_stds = _extract_standards(sec_text)
            module_standards.update(text_stds)

            index.sections[sec_id] = {
                "id": sec_id,
                "title": sec_data["title"],
                "level": sec_data["level"],
                "module_file": file_name,
                "start_line": sec_start,
                "end_line": sec_end,
                "byte_offset": byte_off,
                "byte_length": byte_len,
                "summary": summary,
                "contracts": sec_contracts,
                "code_block_count": sec_code_count,
            }
            section_ids.append(sec_id)
            total_sections += 1

        # First meaningful paragraph as description
        description = _extract_first_paragraph(lines_list, 0)

        index.modules[file_name] = {
            "file_name": file_name,
            "title": title,
            "description": description,
            "size_bytes": file_bytes,
            "line_count": file_lines,
            "sections": section_ids,
            "contracts": module_contracts,
            "standards": sorted(module_standards),
        }

    # Compute combined source hash
    combined = "".join(all_hashes)
    index.source_hash = hashlib.sha256(combined.encode()).hexdigest()

    index.stats = {
        "total_modules": len(index.modules),
        "total_sections": total_sections,
        "total_contracts": total_contracts,
        "total_code_blocks": total_code_blocks,
        "total_source_bytes": total_bytes,
        "total_source_lines": total_lines,
    }

    return index


def check_index_freshness(index: Index, modules_dir: Path) -> bool:
    """Check if the index is still valid (modules haven't changed)."""
    all_hashes = []
    for md_file in sorted(modules_dir.glob("*.md")):
        content = md_file.read_text(encoding="utf-8")
        all_hashes.append(
            hashlib.sha256(content.encode("utf-8")).hexdigest()
        )
    current_hash = hashlib.sha256("".join(all_hashes).encode()).hexdigest()
    return current_hash == index.source_hash
