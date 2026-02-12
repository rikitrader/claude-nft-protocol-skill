"""Data types for the Candlestick Patterns Engine index."""
from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class Section:
    """A documentation section extracted from a candlestick knowledge source."""
    id: str
    title: str
    level: int  # heading level (1-6)
    source_file: str  # relative path in data/raw/
    byte_offset: int
    byte_length: int
    category: str = "patterns"  # patterns|strategies|convergence|fundamentals|glossary|history
    summary: str = ""
    parent: Optional[str] = None
    subsections: List[str] = field(default_factory=list)
    code_blocks: int = 0
    keywords: List[str] = field(default_factory=list)


@dataclass
class PatternDoc:
    """A Japanese candlestick pattern reference entry."""
    name: str  # e.g. "Hammer", "Morning Star", "Bullish Engulfing"
    japanese_name: str  # e.g. "Takuri", "Sanpei" (if known)
    description: str
    source_file: str
    byte_offset: int
    byte_length: int
    pattern_type: str = ""  # reversal|continuation|indecision
    signal: str = ""  # bullish|bearish|neutral
    candle_count: int = 1  # 1, 2, 3+
    reliability: str = ""  # high|medium|low
    category: str = ""  # single-reversal|dual-reversal|triple-reversal|continuation|doji
    see_also: List[str] = field(default_factory=list)


@dataclass
class StrategyDoc:
    """A candlestick trading strategy reference."""
    name: str
    description: str
    source_file: str
    byte_offset: int
    byte_length: int
    patterns_used: List[str] = field(default_factory=list)
    indicators: List[str] = field(default_factory=list)
    timeframes: List[str] = field(default_factory=list)


@dataclass
class CodeExample:
    """A code block extracted from docs (Pine Script examples, etc.)."""
    id: str
    source_file: str
    byte_offset: int
    byte_length: int
    section_id: str  # parent section
    language: str = "pine"
    description: str = ""


@dataclass
class Index:
    """Root index containing all indexed entries with byte offsets."""
    version: str = "1.0.0"
    generated_at: str = ""
    source_hash: str = ""
    sections: Dict[str, Any] = field(default_factory=dict)
    patterns: Dict[str, Any] = field(default_factory=dict)
    strategies: Dict[str, Any] = field(default_factory=dict)
    examples: Dict[str, Any] = field(default_factory=dict)
    stats: Dict[str, int] = field(default_factory=dict)

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(asdict(self), f, indent=2, ensure_ascii=False)

    @classmethod
    def load(cls, path: Path) -> "Index":
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError(f"Invalid index: expected dict, got {type(data).__name__}")
        idx = cls()
        _expected_types = {
            "sections": dict, "patterns": dict, "strategies": dict,
            "examples": dict, "stats": dict,
            "version": str, "generated_at": str, "source_hash": str,
        }
        for k, v in data.items():
            if k not in _expected_types:
                continue  # Ignore unknown keys — prevents arbitrary attribute injection
            if not isinstance(v, _expected_types[k]):
                raise ValueError(
                    f"Invalid index field '{k}': expected {_expected_types[k].__name__}, "
                    f"got {type(v).__name__}"
                )
            setattr(idx, k, v)
        return idx
