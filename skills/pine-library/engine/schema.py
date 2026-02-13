"""Data types for the Pine-Library Engine index."""
from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class ScriptDoc:
    """A community Pine Script indicator/strategy/library."""
    id: str  # TradingView script ID (e.g. "BBCODmrc")
    title: str
    author: str
    script_type: str  # indicator, strategy, library
    source_file: str  # relative path in data/raw/
    byte_offset: int  # start of full content
    byte_length: int  # length of full content
    desc_offset: int  # start of description section
    desc_length: int  # length of description section
    src_offset: int  # start of source code section
    src_length: int  # length of source code section
    tags: List[str] = field(default_factory=list)
    boosts: int = 0
    views: int = 0
    has_source: bool = True
    slug: str = ""
    keywords: List[str] = field(default_factory=list)


@dataclass
class CodeExample:
    """A Pine Script code block extracted from a community script."""
    id: str
    source_file: str
    byte_offset: int
    byte_length: int
    script_id: str  # parent script
    language: str = "pine"
    description: str = ""


@dataclass
class Index:
    """Root index containing all indexed entries with byte offsets."""
    version: str = "1.0.0"
    generated_at: str = ""
    source_hash: str = ""
    scripts: Dict[str, Any] = field(default_factory=dict)
    examples: Dict[str, Any] = field(default_factory=dict)
    tags: Dict[str, List[str]] = field(default_factory=dict)  # tag → [script_ids]
    authors: Dict[str, List[str]] = field(default_factory=dict)  # author → [script_ids]
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
            "scripts": dict, "examples": dict, "tags": dict,
            "authors": dict, "stats": dict,
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
