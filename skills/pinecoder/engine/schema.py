"""Data types for the PineCoder Engine index."""
from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class Section:
    """A documentation section extracted from a Pine Script docs page."""
    id: str
    title: str
    level: int  # heading level (1-6)
    source_file: str  # relative path in data/raw/
    byte_offset: int
    byte_length: int
    category: str = "language"  # language|concepts|visuals|primer|writing|faq|reference
    summary: str = ""
    parent: Optional[str] = None
    subsections: List[str] = field(default_factory=list)
    code_blocks: int = 0  # number of pine code blocks
    keywords: List[str] = field(default_factory=list)


@dataclass
class FunctionDoc:
    """A Pine Script built-in function reference entry."""
    name: str  # e.g. "ta.sma", "plot", "strategy.entry"
    signature: str  # full signature
    description: str
    source_file: str
    byte_offset: int
    byte_length: int
    namespace: str = ""  # ta, math, str, array, matrix, map, strategy, etc.
    returns: str = ""
    parameters: List[Dict[str, str]] = field(default_factory=list)
    examples: List[str] = field(default_factory=list)
    see_also: List[str] = field(default_factory=list)


@dataclass
class TypeDoc:
    """A Pine Script type reference entry."""
    name: str  # int, float, bool, string, color, series, simple, etc.
    description: str
    source_file: str
    byte_offset: int
    byte_length: int
    qualifiers: List[str] = field(default_factory=list)  # series, simple, input, const
    methods: List[str] = field(default_factory=list)


@dataclass
class CodeExample:
    """A pine code block extracted from docs."""
    id: str
    source_file: str
    byte_offset: int
    byte_length: int
    section_id: str  # parent section
    language: str = "pine"  # pine or pinescript
    description: str = ""


@dataclass
class Index:
    """Root index containing all indexed entries with byte offsets."""
    version: str = "1.0.0"
    generated_at: str = ""
    source_hash: str = ""
    sections: Dict[str, Any] = field(default_factory=dict)
    functions: Dict[str, Any] = field(default_factory=dict)
    types: Dict[str, Any] = field(default_factory=dict)
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
            "sections": dict, "functions": dict, "types": dict,
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
