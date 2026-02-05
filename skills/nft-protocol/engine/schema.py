"""Data types for the NFT Protocol Engine index."""
from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class CodeBlock:
    language: str
    content: str
    start_line: int
    end_line: int
    byte_offset: int
    byte_length: int
    file_path: Optional[str] = None  # e.g. "contracts/FractionalVault.sol"


@dataclass
class Contract:
    name: str
    module_file: str
    section_id: str
    language: str
    start_line: int
    end_line: int
    byte_offset: int
    byte_length: int
    file_path: Optional[str] = None
    standards: List[str] = field(default_factory=list)
    imports: List[str] = field(default_factory=list)


@dataclass
class Section:
    id: str
    title: str
    level: int
    module_file: str
    start_line: int
    end_line: int
    byte_offset: int
    byte_length: int
    summary: str = ""
    parent: Optional[str] = None
    subsections: List[str] = field(default_factory=list)
    contracts: List[str] = field(default_factory=list)
    code_block_count: int = 0


@dataclass
class ModuleInfo:
    file_name: str
    title: str
    description: str
    size_bytes: int
    line_count: int
    sections: List[str] = field(default_factory=list)
    contracts: List[str] = field(default_factory=list)
    standards: List[str] = field(default_factory=list)


@dataclass
class Index:
    version: str = "1.0.0"
    generated_at: str = ""
    source_hash: str = ""
    modules: Dict[str, Any] = field(default_factory=dict)
    sections: Dict[str, Any] = field(default_factory=dict)
    contracts: Dict[str, Any] = field(default_factory=dict)
    standards: Dict[str, List[str]] = field(default_factory=dict)
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
            "modules": dict, "sections": dict, "contracts": dict,
            "standards": dict, "stats": dict,
            "version": str, "generated_at": str, "source_hash": str,
        }
        for k, v in data.items():
            if k in _expected_types and not isinstance(v, _expected_types[k]):
                raise ValueError(
                    f"Invalid index field '{k}': expected {_expected_types[k].__name__}, "
                    f"got {type(v).__name__}"
                )
            setattr(idx, k, v)
        return idx
