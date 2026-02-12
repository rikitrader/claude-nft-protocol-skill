"""Parse candlestick markdown docs into a searchable JSON index.

Extracts sections, patterns, strategies, and code examples with byte offsets
for targeted extraction (90%+ token reduction vs loading full pages).
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

from .schema import CodeExample, Index, PatternDoc, Section, StrategyDoc

# Regex patterns
_HEADING_RE = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)
_CODE_BLOCK_RE = re.compile(r"```(\w*)\n(.*?)```", re.DOTALL)

# Category mapping from filename
_CATEGORY_MAP = {
    "fundamentals": "fundamentals",
    "history": "history",
    "single-reversal": "patterns",
    "single-doji": "patterns",
    "dual-reversal": "patterns",
    "triple-reversal": "patterns",
    "continuation": "patterns",
    "convergence-trend": "convergence",
    "convergence-levels": "convergence",
    "convergence-ma": "convergence",
    "convergence-oscillators": "convergence",
    "convergence-volume": "convergence",
    "strategies-pin-bar": "strategies",
    "strategies-engulfing": "strategies",
    "strategies-inside-bar": "strategies",
    "market-structure": "strategies",
    "money-management": "strategies",
    "psychology": "fundamentals",
    "measured-moves": "convergence",
    "glossary": "glossary",
    "pattern-index": "patterns",
    "nison": "patterns",
    "bible": "strategies",
    "web": "patterns",
}

# Pattern signals for classification
_BULLISH_KEYWORDS = {
    "bullish", "hammer", "morning star", "piercing", "white soldiers",
    "dragonfly", "inverted hammer", "engulfing bullish", "belt hold bullish",
    "rising", "three inside up", "three outside up",
}
_BEARISH_KEYWORDS = {
    "bearish", "hanging man", "evening star", "dark cloud", "black crows",
    "gravestone", "shooting star", "engulfing bearish", "belt hold bearish",
    "falling", "three inside down", "three outside down",
}

# Known pattern names for recognition
_KNOWN_PATTERNS = {
    "hammer", "hanging man", "inverted hammer", "shooting star",
    "bullish engulfing", "bearish engulfing", "engulfing",
    "morning star", "evening star",
    "piercing line", "piercing", "dark cloud cover", "dark cloud",
    "doji", "dragonfly doji", "gravestone doji", "long-legged doji",
    "spinning top", "marubozu",
    "harami", "bullish harami", "bearish harami",
    "tweezers", "tweezer top", "tweezer bottom",
    "three white soldiers", "three black crows",
    "three inside up", "three inside down",
    "three outside up", "three outside down",
    "rising three methods", "falling three methods",
    "belt hold", "counterattack",
    "upside gap two crows", "three mountains", "three rivers",
    "dumpling top", "frypan bottom", "tower top", "tower bottom",
    "tri-star", "rickshaw man",
    "separating lines", "tasuki gap", "window",
    "pin bar", "inside bar",
}


def _slug(text: str) -> str:
    """Convert heading text to a URL-safe slug."""
    s = text.lower().strip()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_]+", "-", s)
    return s.strip("-")


def _category_from_path(file_path: str) -> str:
    """Infer doc category from file path."""
    stem = Path(file_path).stem.lower()
    for prefix, cat in _CATEGORY_MAP.items():
        if prefix in stem:
            return cat
    return "general"


def _detect_signal(text: str) -> str:
    """Detect bullish/bearish/neutral signal from text."""
    t = text.lower()
    bull = sum(1 for kw in _BULLISH_KEYWORDS if kw in t)
    bear = sum(1 for kw in _BEARISH_KEYWORDS if kw in t)
    if bull > bear:
        return "bullish"
    if bear > bull:
        return "bearish"
    return "neutral"


def _detect_pattern_type(text: str) -> str:
    """Detect reversal/continuation/indecision from text."""
    t = text.lower()
    if "reversal" in t:
        return "reversal"
    if "continuation" in t:
        return "continuation"
    if "doji" in t or "indecision" in t or "spinning" in t:
        return "indecision"
    return ""


def _detect_candle_count(text: str) -> int:
    """Detect number of candles in a pattern."""
    t = text.lower()
    if any(w in t for w in ("three", "tri-star", "three white", "three black", "three inside",
                             "three outside", "three methods", "three mountains", "three rivers")):
        return 3
    if any(w in t for w in ("engulfing", "harami", "tweezer", "piercing", "dark cloud",
                             "counterattack", "separating", "inside bar")):
        return 2
    return 1


def _extract_keywords(text: str) -> List[str]:
    """Extract searchable keywords from a text block."""
    words = set()
    for word in re.findall(r"\b[a-zA-Z_]\w{2,}\b", text):
        w = word.lower()
        if w not in {"the", "and", "for", "that", "this", "with", "from", "are", "was",
                      "will", "can", "not", "but", "has", "its", "have", "when", "each",
                      "more", "also", "they", "been", "than", "then", "would", "could",
                      "should", "these", "those", "about", "which", "their", "there"}:
            words.add(w)
    # Add known pattern names found in text
    t = text.lower()
    for pname in _KNOWN_PATTERNS:
        if pname in t:
            words.add(pname)
    return sorted(words)[:50]


def _index_sections(
    content: str,
    source_file: str,
    category: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract all heading-based sections with byte offsets."""
    sections: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    headings: List[Tuple[int, int, str, int]] = []

    byte_pos = 0
    for line_idx, line in enumerate(content.split("\n")):
        m = _HEADING_RE.match(line)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            headings.append((byte_pos, level, title, line_idx))
        byte_pos += len(line.encode("utf-8")) + 1

    for i, (byte_start, level, title, line_idx) in enumerate(headings):
        byte_end = len(content_bytes)
        for j in range(i + 1, len(headings)):
            if headings[j][1] <= level:
                byte_end = headings[j][0]
                break

        byte_length = byte_end - byte_start
        section_content = content_bytes[byte_start:byte_end].decode("utf-8", errors="replace")

        code_blocks = len(re.findall(r"```", section_content)) // 2

        section_id = f"{category}/{_slug(title)}"
        if section_id in sections:
            section_id = f"{section_id}-{i}"

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


def _index_patterns(
    content: str,
    source_file: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract candlestick pattern references from documentation content."""
    patterns: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    # Look for pattern headings: ## Hammer, ## Morning Star, etc.
    for m in re.finditer(
        r"^#{2,4}\s+(.+?)(?:\s*\(.*?\))?\s*$", content, re.MULTILINE
    ):
        title = m.group(1).strip()
        title_lower = title.lower()

        # Check if this heading matches a known pattern
        is_pattern = False
        matched_name = title
        for pname in _KNOWN_PATTERNS:
            if pname in title_lower or title_lower in pname:
                is_pattern = True
                matched_name = title
                break

        # Also match headings that explicitly say "pattern"
        if not is_pattern and "pattern" in title_lower:
            is_pattern = True

        if not is_pattern:
            continue

        byte_start = len(content[:m.start()].encode("utf-8"))

        # Find end of pattern section
        next_heading = re.search(r"^#{2,4}\s+", content[m.end():], re.MULTILINE)
        if next_heading:
            byte_end = len(content[:m.end() + next_heading.start()].encode("utf-8"))
        else:
            byte_end = len(content_bytes)

        section = content_bytes[byte_start:byte_end].decode("utf-8", errors="replace")

        # Extract description
        desc_lines = []
        for line in section.split("\n")[1:]:
            if line.strip().startswith("#") or line.strip().startswith("```"):
                break
            if line.strip():
                desc_lines.append(line.strip())
        description = " ".join(desc_lines)[:300]

        # Try to detect Japanese name
        jp_match = re.search(r"[（(]([^)）]+?)[)）]", section[:500])
        japanese_name = jp_match.group(1) if jp_match else ""
        # Also check for explicit mentions
        if not japanese_name:
            jp_match2 = re.search(r"Japanese(?:\s+name)?:\s*(\w+)", section[:500], re.IGNORECASE)
            japanese_name = jp_match2.group(1) if jp_match2 else ""

        signal = _detect_signal(section[:500])
        pattern_type = _detect_pattern_type(section[:500])
        candle_count = _detect_candle_count(title)

        # Detect reliability
        reliability = ""
        sl = section.lower()
        if "high reliability" in sl or "highly reliable" in sl or "strong" in sl:
            reliability = "high"
        elif "moderate" in sl or "medium" in sl:
            reliability = "medium"
        elif "low reliability" in sl or "weak" in sl:
            reliability = "low"

        # Detect category
        category = ""
        if candle_count == 1 and "doji" in title_lower:
            category = "doji"
        elif candle_count == 1 and pattern_type == "reversal":
            category = "single-reversal"
        elif candle_count == 2 and pattern_type == "reversal":
            category = "dual-reversal"
        elif candle_count >= 3 and pattern_type == "reversal":
            category = "triple-reversal"
        elif pattern_type == "continuation":
            category = "continuation"
        elif "doji" in title_lower:
            category = "doji"

        pattern_id = f"pat/{_slug(matched_name)}"
        if pattern_id in patterns:
            pattern_id = f"{pattern_id}-{len(patterns)}"

        patterns[pattern_id] = asdict(PatternDoc(
            name=matched_name,
            japanese_name=japanese_name,
            description=description,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_end - byte_start,
            pattern_type=pattern_type,
            signal=signal,
            candle_count=candle_count,
            reliability=reliability,
            category=category,
            see_also=[],
        ))

    return patterns


def _index_strategies(
    content: str,
    source_file: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract trading strategy references from documentation content."""
    strategies: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    strategy_keywords = {"strategy", "setup", "entry", "exit", "trade", "system", "method"}

    for m in re.finditer(r"^#{2,4}\s+(.+)$", content, re.MULTILINE):
        title = m.group(1).strip()
        title_lower = title.lower()

        is_strategy = any(kw in title_lower for kw in strategy_keywords)
        if not is_strategy:
            continue

        byte_start = len(content[:m.start()].encode("utf-8"))

        next_heading = re.search(r"^#{2,4}\s+", content[m.end():], re.MULTILINE)
        if next_heading:
            byte_end = len(content[:m.end() + next_heading.start()].encode("utf-8"))
        else:
            byte_end = len(content_bytes)

        section = content_bytes[byte_start:byte_end].decode("utf-8", errors="replace")

        desc_lines = []
        for line in section.split("\n")[1:]:
            if line.strip().startswith("#") or line.strip().startswith("```"):
                break
            if line.strip():
                desc_lines.append(line.strip())
        description = " ".join(desc_lines)[:300]

        # Detect which patterns this strategy uses
        patterns_used = []
        sl = section.lower()
        for pname in _KNOWN_PATTERNS:
            if pname in sl:
                patterns_used.append(pname)

        # Detect indicators mentioned
        indicators = []
        indicator_names = {"rsi", "macd", "stochastic", "moving average", "sma", "ema",
                           "bollinger", "fibonacci", "volume", "atr", "adx", "obv"}
        for ind in indicator_names:
            if ind in sl:
                indicators.append(ind)

        # Detect timeframes
        timeframes = []
        tf_patterns = re.findall(r"\b(\d+[hHmMdDwW]|daily|weekly|monthly|hourly|[14]h|1[56]m)\b", section)
        timeframes = list(set(tf_patterns))

        strat_id = f"strat/{_slug(title)}"
        if strat_id in strategies:
            strat_id = f"{strat_id}-{len(strategies)}"

        strategies[strat_id] = asdict(StrategyDoc(
            name=title,
            description=description,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_end - byte_start,
            patterns_used=patterns_used,
            indicators=indicators,
            timeframes=timeframes,
        ))

    return strategies


def _index_examples(
    content: str,
    source_file: str,
    category: str,
) -> Dict[str, Dict[str, Any]]:
    """Extract all code examples with byte offsets."""
    examples: Dict[str, Dict[str, Any]] = {}
    content_bytes = content.encode("utf-8")

    current_section = "root"
    heading_positions = list(_HEADING_RE.finditer(content))

    for i, m in enumerate(_CODE_BLOCK_RE.finditer(content)):
        lang = m.group(1).lower()

        byte_start = len(content[:m.start()].encode("utf-8"))
        byte_length = len(m.group(0).encode("utf-8"))

        code_pos = m.start()
        for hm in reversed(heading_positions):
            if hm.start() < code_pos:
                current_section = _slug(hm.group(2).strip())
                break

        example_id = f"ex/{category}/{current_section}-{i}"

        pre_text = content[max(0, m.start() - 200):m.start()]
        desc_lines = [line.strip() for line in pre_text.split("\n")
                      if line.strip() and not line.startswith("#")]
        description = desc_lines[-1] if desc_lines else ""

        examples[example_id] = asdict(CodeExample(
            id=example_id,
            source_file=source_file,
            byte_offset=byte_start,
            byte_length=byte_length,
            section_id=f"{category}/{current_section}",
            language=lang or "text",
            description=description[:200],
        ))

    return examples


def build_index(raw_dir: Path) -> Index:
    """Build a complete search index from all cached markdown files.

    Args:
        raw_dir: Directory containing structured .md files.

    Returns:
        Populated Index object.
    """
    all_sections: Dict[str, Any] = {}
    all_patterns: Dict[str, Any] = {}
    all_strategies: Dict[str, Any] = {}
    all_examples: Dict[str, Any] = {}

    md_files = sorted(raw_dir.glob("*.md"))
    if not md_files:
        raise FileNotFoundError(f"No markdown files found in {raw_dir}")

    for md_file in md_files:
        if md_file.name.startswith("_"):
            continue

        content = md_file.read_text(encoding="utf-8")
        rel_path = str(md_file.relative_to(raw_dir.parent.parent))
        category = _category_from_path(md_file.name)

        sections = _index_sections(content, rel_path, category)
        all_sections.update(sections)

        patterns = _index_patterns(content, rel_path)
        all_patterns.update(patterns)

        strategies = _index_strategies(content, rel_path)
        all_strategies.update(strategies)

        examples = _index_examples(content, rel_path, category)
        all_examples.update(examples)

    source_hash = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        source_hash.update(md_file.read_bytes())

    stats = {
        "total_sections": len(all_sections),
        "total_patterns": len(all_patterns),
        "total_strategies": len(all_strategies),
        "total_examples": len(all_examples),
        "total_files": len(md_files),
        "total_bytes": sum(f.stat().st_size for f in md_files),
    }

    return Index(
        version="1.0.0",
        generated_at=datetime.now(timezone.utc).isoformat(),
        source_hash=source_hash.hexdigest()[:16],
        sections=all_sections,
        patterns=all_patterns,
        strategies=all_strategies,
        examples=all_examples,
        stats=stats,
    )


def check_index_freshness(index: Index, raw_dir: Path) -> bool:
    """Check if the index matches the current source files."""
    current_hash = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        current_hash.update(md_file.read_bytes())
    return index.source_hash == current_hash.hexdigest()[:16]
