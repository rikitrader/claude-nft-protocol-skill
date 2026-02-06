"""Data types for the Memecoin Architect Engine index."""
from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class Section:
    """Markdown section (references, SKILL.md)."""
    id: str
    title: str
    level: int
    source_file: str
    start_line: int
    end_line: int
    byte_offset: int
    byte_length: int
    summary: str = ""
    parent: Optional[str] = None
    subsections: List[str] = field(default_factory=list)
    category: str = "reference"  # "reference" | "skill" | "template-doc"


@dataclass
class Template:
    """TSX/TS/CSS file from the Aura dashboard."""
    name: str
    source_file: str
    component_type: str  # "page" | "component" | "hook" | "lib" | "style"
    route_group: Optional[str] = None  # "(landing)" | "(dashboard)" | "(dashboard)/admin"
    byte_offset: int = 0
    byte_length: int = 0
    exports: List[str] = field(default_factory=list)
    imports: List[str] = field(default_factory=list)


@dataclass
class Contract:
    """Anchor/Rust program from scripts/anchor_contracts/."""
    name: str
    source_file: str
    program_name: str = ""
    byte_offset: int = 0
    byte_length: int = 0
    instructions: List[str] = field(default_factory=list)
    accounts: List[str] = field(default_factory=list)
    events: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)


@dataclass
class ScriptInfo:
    """TS/SH/PY script from scripts/."""
    name: str
    source_file: str
    script_type: str = "deploy"  # "deploy" | "security" | "dex" | "marketing"
    byte_offset: int = 0
    byte_length: int = 0
    description: str = ""


@dataclass
class Index:
    """Root index containing all indexed entries with byte offsets."""
    version: str = "1.0.0"
    generated_at: str = ""
    source_hash: str = ""
    sections: Dict[str, Any] = field(default_factory=dict)
    templates: Dict[str, Any] = field(default_factory=dict)
    contracts: Dict[str, Any] = field(default_factory=dict)
    scripts: Dict[str, Any] = field(default_factory=dict)
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
            "sections": dict, "templates": dict, "contracts": dict,
            "scripts": dict, "stats": dict,
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
