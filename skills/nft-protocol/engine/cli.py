"""CLI command router for the NFT Protocol Engine."""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict

DEFAULT_MODEL = os.environ.get("NFT_ENGINE_MODEL", "claude-sonnet-4-20250514")

SKILL_DIR = Path(__file__).resolve().parent.parent
MODULES_DIR = SKILL_DIR / "modules"
DATA_DIR = SKILL_DIR / "data"
INDEX_PATH = DATA_DIR / "index.json"
LOG_PATH = DATA_DIR / "token_log.jsonl"


def _out(data: Any) -> None:
    """Print JSON to stdout."""
    print(json.dumps(data, indent=2, ensure_ascii=False))


def _load_index(command: str = "unknown") -> Dict[str, Any]:
    if not INDEX_PATH.exists():
        _out({"status": "error", "command": command,
              "error": "Index not found. Run: python3 -m engine build-index"})
        sys.exit(2)
    try:
        with open(INDEX_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        _out({"status": "error", "command": command,
              "error": f"Corrupt index JSON: {e}. Run: python3 -m engine build-index"})
        sys.exit(3)
    except PermissionError:
        _out({"status": "error", "command": command,
              "error": f"Permission denied reading {INDEX_PATH}"})
        sys.exit(4)


def cmd_build_index(args: argparse.Namespace) -> None:
    from .indexer import build_index
    from .schema import Index

    try:
        idx = build_index(MODULES_DIR)
        idx.save(INDEX_PATH)
    except Exception as e:
        _out({"status": "error", "command": "build-index",
              "error": f"Failed to build index: {e}"})
        sys.exit(1)
    _out({
        "status": "ok",
        "command": "build-index",
        "result": idx.stats,
        "index_path": str(INDEX_PATH),
    })


def cmd_check_index(args: argparse.Namespace) -> None:
    from .indexer import check_index_freshness
    from .schema import Index

    idx = Index.load(INDEX_PATH)
    fresh = check_index_freshness(idx, MODULES_DIR)
    _out({
        "status": "ok",
        "command": "check-index",
        "fresh": fresh,
        "source_hash": idx.source_hash,
    })


def cmd_search(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    from .tracker import TokenTracker

    index = _load_index("search")
    searcher = Searcher(index)
    results = searcher.search(args.query, args.type)

    # Compute actual savings based on total source bytes
    total_bytes = sum(m.get("size_bytes", 0) for m in index.get("modules", {}).values())
    baseline_tokens = total_bytes // 4
    tracker = TokenTracker(LOG_PATH)
    tracker.log("search", tokens_used=500, tokens_saved=max(baseline_tokens - 500, 0),
                details={"query": args.query})

    _out({"status": "ok", "command": "search", "result": results})


def cmd_get_contract(args: argparse.Namespace) -> None:
    from .extractor import Extractor
    from .tracker import TokenTracker

    index = _load_index("get-contract")
    extractor = Extractor(index, MODULES_DIR)
    result = extractor.get_contract(args.name)

    if not result:
        # Try suggest
        from .searcher import Searcher
        searcher = Searcher(index)
        suggestions = searcher.suggest(args.name)
        _out({"status": "error", "command": "get-contract",
              "error": f"Contract '{args.name}' not found",
              "suggestions": suggestions})
        return

    tracker = TokenTracker(LOG_PATH)
    tracker.log("get-contract",
                tokens_used=result["tokens"]["estimated_output"],
                tokens_saved=result["tokens"]["full_module_tokens"] - result["tokens"]["estimated_output"],
                details={"contract": args.name})

    _out({"status": "ok", "command": "get-contract", "result": result})


def cmd_get_section(args: argparse.Namespace) -> None:
    from .extractor import Extractor
    from .tracker import TokenTracker

    index = _load_index("get-section")
    extractor = Extractor(index, MODULES_DIR)
    result = extractor.get_section(args.id, outline_only=args.outline)

    if not result:
        from .searcher import Searcher
        searcher = Searcher(index)
        suggestions = searcher.suggest(args.id)
        _out({"status": "error", "command": "get-section",
              "error": f"Section '{args.id}' not found",
              "suggestions": suggestions})
        return

    tracker = TokenTracker(LOG_PATH)
    tracker.log("get-section",
                tokens_used=result["tokens"]["estimated_output"],
                tokens_saved=result["tokens"]["full_module_tokens"] - result["tokens"]["estimated_output"],
                details={"section": args.id})

    _out({"status": "ok", "command": "get-section", "result": result})


def cmd_list_modules(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    from .tracker import TokenTracker

    index = _load_index("list-modules")
    searcher = Searcher(index)
    result = searcher.list_modules()

    total_bytes = sum(m.get("size_bytes", 0) for m in index.get("modules", {}).values())
    baseline_tokens = total_bytes // 4
    tracker = TokenTracker(LOG_PATH)
    tracker.log("list-modules", tokens_used=800, tokens_saved=max(baseline_tokens - 800, 0))

    _out({"status": "ok", "command": "list-modules", "result": result})


def cmd_list_contracts(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    from .tracker import TokenTracker

    index = _load_index("list-contracts")
    searcher = Searcher(index)
    result = searcher.list_contracts()

    total_bytes = sum(m.get("size_bytes", 0) for m in index.get("modules", {}).values())
    baseline_tokens = total_bytes // 4
    tracker = TokenTracker(LOG_PATH)
    tracker.log("list-contracts", tokens_used=1000, tokens_saved=max(baseline_tokens - 1000, 0))

    _out({"status": "ok", "command": "list-contracts", "result": result})


def cmd_list_standards(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    from .tracker import TokenTracker

    index = _load_index("list-standards")
    searcher = Searcher(index)
    result = searcher.list_standards()

    total_bytes = sum(m.get("size_bytes", 0) for m in index.get("modules", {}).values())
    baseline_tokens = total_bytes // 4
    tracker = TokenTracker(LOG_PATH)
    tracker.log("list-standards", tokens_used=500, tokens_saved=max(baseline_tokens - 500, 0))

    _out({"status": "ok", "command": "list-standards", "result": result})


def cmd_find_standard(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    from .tracker import TokenTracker

    index = _load_index("find-standard")
    searcher = Searcher(index)
    result = searcher.find_by_standard(args.standard)

    total_bytes = sum(m.get("size_bytes", 0) for m in index.get("modules", {}).values())
    baseline_tokens = total_bytes // 4
    tracker = TokenTracker(LOG_PATH)
    tracker.log("find-standard", tokens_used=500, tokens_saved=max(baseline_tokens - 500, 0),
                details={"standard": args.standard})

    _out({"status": "ok", "command": "find-standard", "result": result})


def cmd_outline(args: argparse.Namespace) -> None:
    from .extractor import Extractor
    from .tracker import TokenTracker

    index = _load_index("outline")
    extractor = Extractor(index, MODULES_DIR)
    result = extractor.get_module_outline(args.module)

    if not result:
        _out({"status": "error", "command": "outline",
              "error": f"Module '{args.module}' not found",
              "available": list(index.get("modules", {}).keys())})
        return

    tracker = TokenTracker(LOG_PATH)
    tracker.log("outline",
                tokens_used=result["tokens"]["estimated_output"],
                tokens_saved=result["tokens"]["full_module_tokens"] - result["tokens"]["estimated_output"],
                details={"module": args.module})

    _out({"status": "ok", "command": "outline", "result": result})


def cmd_token_report(args: argparse.Namespace) -> None:
    from .tracker import TokenTracker
    tracker = TokenTracker(LOG_PATH)
    _out({"status": "ok", "command": "token-report", "result": tracker.report()})


def cmd_batch_generate(args: argparse.Namespace) -> None:
    from .extractor import Extractor
    from .tracker import TokenTracker
    from .batch import BatchProcessor

    index = _load_index("batch-generate")
    extractor = Extractor(index, MODULES_DIR)
    tracker = TokenTracker(LOG_PATH)
    processor = BatchProcessor(extractor, tracker, model=args.model)

    specs = json.loads(args.specs)
    if not isinstance(specs, list):
        _out({"status": "error", "command": "batch-generate",
              "error": "specs must be a JSON array"})
        sys.exit(1)
    for i, spec in enumerate(specs):
        if not isinstance(spec, dict) or "base" not in spec or "prompt" not in spec:
            _out({"status": "error", "command": "batch-generate",
                  "error": f"specs[{i}] must have 'base' and 'prompt' keys"})
            sys.exit(1)
    output_dir = Path(args.output_dir) if args.output_dir else None
    results = processor.generate_contracts(specs, max_workers=args.max_workers,
                                           output_dir=output_dir)
    _out({"status": "ok", "command": "batch-generate", "result": results})


def cmd_batch_analyze(args: argparse.Namespace) -> None:
    from .extractor import Extractor
    from .tracker import TokenTracker
    from .batch import BatchProcessor

    index = _load_index("batch-analyze")
    extractor = Extractor(index, MODULES_DIR)
    tracker = TokenTracker(LOG_PATH)
    processor = BatchProcessor(extractor, tracker, model=args.model)

    result = processor.analyze_module(args.module, args.prompt)
    _out({"status": "ok", "command": "batch-analyze", "result": result})


def cmd_serve(args: argparse.Namespace) -> None:
    from .mcp_server import NFTProtocolMCPServer
    server = NFTProtocolMCPServer()
    server.run()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="nft-engine",
        description="NFT Protocol Engine - 90-99% token reduction via targeted extraction",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # build-index
    sub.add_parser("build-index", help="Build the search index from modules")

    # check-index
    sub.add_parser("check-index", help="Check if index is up-to-date")

    # search
    p = sub.add_parser("search", help="Search contracts, sections, standards")
    p.add_argument("query", help="Search query")
    p.add_argument("--type", default="all",
                   choices=["all", "contract", "section", "standard"])

    # get-contract
    p = sub.add_parser("get-contract", help="Extract a specific contract")
    p.add_argument("name", help="Contract name (e.g. FractionalVault)")

    # get-section
    p = sub.add_parser("get-section", help="Extract a module section")
    p.add_argument("id", help="Section ID")
    p.add_argument("--outline", action="store_true",
                   help="Return outline only (headings + declarations)")

    # list-modules
    sub.add_parser("list-modules", help="List all modules with summaries")

    # list-contracts
    sub.add_parser("list-contracts", help="List all contracts")

    # list-standards
    sub.add_parser("list-standards", help="List supported ERC standards")

    # find-standard
    p = sub.add_parser("find-standard", help="Find contracts by ERC standard")
    p.add_argument("standard", help="ERC standard (e.g. ERC-6551)")

    # outline
    p = sub.add_parser("outline", help="Show module section structure")
    p.add_argument("module", help="Module filename (e.g. defi.md)")

    # token-report
    sub.add_parser("token-report", help="Show token usage/savings report")

    # batch-generate
    p = sub.add_parser("batch-generate", help="Generate contracts via API")
    p.add_argument("--specs", required=True,
                   help='JSON array: [{"base":"Name","prompt":"..."}]')
    p.add_argument("--model", default=DEFAULT_MODEL)
    p.add_argument("--max-workers", type=int, default=3)
    p.add_argument("--output-dir", default=None)

    # batch-analyze
    p = sub.add_parser("batch-analyze", help="Analyze a module via API")
    p.add_argument("--module", required=True)
    p.add_argument("--prompt", required=True)
    p.add_argument("--model", default=DEFAULT_MODEL)

    # serve
    sub.add_parser("serve", help="Start MCP stdio server")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    commands = {
        "build-index": cmd_build_index,
        "check-index": cmd_check_index,
        "search": cmd_search,
        "get-contract": cmd_get_contract,
        "get-section": cmd_get_section,
        "list-modules": cmd_list_modules,
        "list-contracts": cmd_list_contracts,
        "list-standards": cmd_list_standards,
        "find-standard": cmd_find_standard,
        "outline": cmd_outline,
        "token-report": cmd_token_report,
        "batch-generate": cmd_batch_generate,
        "batch-analyze": cmd_batch_analyze,
        "serve": cmd_serve,
    }

    handler = commands.get(args.command)
    if handler:
        handler(args)
    else:
        parser.print_help()
