"""CLI command router for the Memecoin Architect Engine."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

SKILL_DIR = Path(__file__).resolve().parent.parent
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


def _tracker():
    from .tracker import TokenTracker
    return TokenTracker(LOG_PATH)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_build_index(args: argparse.Namespace) -> None:
    from .indexer import build_index
    idx = build_index(SKILL_DIR)
    idx.save(INDEX_PATH)
    _out({
        "status": "ok",
        "command": "build-index",
        "index_path": str(INDEX_PATH),
        "stats": idx.stats,
    })


def cmd_check_index(args: argparse.Namespace) -> None:
    from .indexer import check_index_freshness
    from .schema import Index

    index_data = _load_index("check-index")
    idx = Index()
    _known = {"version", "generated_at", "source_hash", "sections", "templates", "contracts", "scripts", "stats"}
    for k, v in index_data.items():
        if k in _known:
            setattr(idx, k, v)

    fresh = check_index_freshness(idx, SKILL_DIR)
    _out({
        "status": "ok",
        "command": "check-index",
        "fresh": fresh,
        "generated_at": index_data.get("generated_at", ""),
        "source_hash": index_data.get("source_hash", ""),
        "stats": index_data.get("stats", {}),
        "warning": None if fresh else "Index is stale. Run: python3 -m engine build-index",
    })


def cmd_search(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    index_data = _load_index("search")
    searcher = Searcher(index_data)
    results = searcher.search(args.query, category=args.category, limit=args.limit)
    tracker = _tracker()
    est_saved = sum(len(json.dumps(r)) for r in results)
    tracker.log("search", tokens_used=est_saved // 4, tokens_saved=est_saved)
    _out({
        "status": "ok",
        "command": "search",
        "query": args.query,
        "category": args.category,
        "results": results,
        "count": len(results),
    })


def cmd_list(args: argparse.Namespace) -> None:
    from .searcher import Searcher
    index_data = _load_index("list")
    searcher = Searcher(index_data)

    category = args.category
    # Normalize singular to plural
    category_map = {
        "template": "templates", "contract": "contracts",
        "section": "sections", "script": "scripts",
        "reference": "sections", "references": "sections",
    }
    normalized = category_map.get(category, category)
    results = searcher.list_category(normalized)

    # Filter references if "references" was requested
    if category == "references" or category == "reference":
        results = [r for r in results if "reference/" in r.get("id", "")]

    _out({
        "status": "ok",
        "command": "list",
        "category": normalized,
        "results": results,
        "count": len(results),
    })


def cmd_extract(args: argparse.Namespace) -> None:
    from .extractor import Extractor
    index_data = _load_index("extract")
    extractor = Extractor(index_data, SKILL_DIR)
    result = extractor.extract(args.entry_id)

    if result is None:
        _out({"status": "error", "command": "extract",
              "error": f"Entry not found: {args.entry_id}"})
        sys.exit(1)

    # Track token savings
    tracker = _tracker()
    tokens = result.get("tokens", {})
    tracker.log(
        "extract",
        tokens_used=tokens.get("estimated_output", 0),
        tokens_saved=tokens.get("full_file_tokens", 0) - tokens.get("estimated_output", 0),
        details={"entry_id": args.entry_id},
    )

    _out({"status": "ok", "command": "extract", "result": result})


def cmd_generate_dashboard(args: argparse.Namespace) -> None:
    from .generator import Generator
    brief_path = Path(args.brief) if args.brief else None
    gen = Generator(SKILL_DIR, brief_path)
    result = gen.generate_dashboard(Path(args.output_dir))

    tracker = _tracker()
    files_written = result.get("files_written", 0)
    # Each file averages ~4KB = ~1000 tokens saved vs loading in context
    tracker.log("generate-dashboard", tokens_used=50, tokens_saved=files_written * 1000,
                details={"output_dir": args.output_dir})

    _out({"status": "ok", "command": "generate-dashboard", **result})


def cmd_generate_contracts(args: argparse.Namespace) -> None:
    from .generator import Generator
    brief_path = Path(args.brief) if args.brief else None
    gen = Generator(SKILL_DIR, brief_path)
    result = gen.generate_contracts(Path(args.output_dir))

    tracker = _tracker()
    tracker.log("generate-contracts", tokens_used=30, tokens_saved=5 * 10000,
                details={"output_dir": args.output_dir})

    _out({"status": "ok", "command": "generate-contracts", **result})


def cmd_generate_marketing(args: argparse.Namespace) -> None:
    from .generator import Generator
    brief_path = Path(args.brief) if args.brief else None
    gen = Generator(SKILL_DIR, brief_path)
    result = gen.generate_marketing(Path(args.output_dir))

    tracker = _tracker()
    tracker.log("generate-marketing", tokens_used=20,
                tokens_saved=result.get("files_written", 0) * 500,
                details={"output_dir": args.output_dir})

    _out({"status": "ok", "command": "generate-marketing", **result})


def cmd_generate_manifest(args: argparse.Namespace) -> None:
    from .generator import Generator
    brief_path = Path(args.brief) if args.brief else None
    gen = Generator(SKILL_DIR, brief_path)
    result = gen.generate_manifest(Path(args.output_dir))

    tracker = _tracker()
    total = result.get("total_files", 0)
    tracker.log("generate-manifest", tokens_used=100, tokens_saved=total * 1000,
                details={"output_dir": args.output_dir})

    _out({"status": "ok", "command": "generate-manifest", **result})


def cmd_apply_brief(args: argparse.Namespace) -> None:
    from .generator import _load_brief
    brief_path = Path(args.brief_path)
    if not brief_path.exists():
        _out({"status": "error", "command": "apply-brief",
              "error": f"Brief file not found: {args.brief_path}"})
        sys.exit(1)

    overrides = _load_brief(brief_path)
    _out({
        "status": "ok",
        "command": "apply-brief",
        "brief_path": str(brief_path),
        "overrides_found": len(overrides),
        "overrides": overrides,
    })


def cmd_token_report(args: argparse.Namespace) -> None:
    tracker = _tracker()
    report = tracker.report()
    _out({"status": "ok", "command": "token-report", **report})


def cmd_serve(args: argparse.Namespace) -> None:
    from .mcp_server import run_server
    run_server(SKILL_DIR, INDEX_PATH, LOG_PATH)


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        prog="memecoin-engine",
        description="Memecoin Architect Engine — local execution with 90-99%% token reduction",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # build-index
    sub.add_parser("build-index", help="Parse all skill files and build the JSON index")

    # check-index
    sub.add_parser("check-index", help="Validate index integrity and freshness")

    # search
    p = sub.add_parser("search", help="Fuzzy search across all indexed entries")
    p.add_argument("query", help="Search query")
    p.add_argument("--category", choices=["sections", "templates", "contracts", "scripts"],
                   default=None, help="Restrict to a category")
    p.add_argument("--limit", type=int, default=10, help="Max results (default: 10)")

    # list
    p = sub.add_parser("list", help="List all entries in a category")
    p.add_argument("category", choices=[
        "sections", "templates", "contracts", "scripts",
        "references", "template", "contract", "section", "script", "reference",
    ], help="Category to list")

    # extract
    p = sub.add_parser("extract", help="Extract content by entry ID")
    p.add_argument("entry_id", help="Entry ID (e.g. contracts/treasury_vault)")

    # generate-dashboard
    p = sub.add_parser("generate-dashboard", help="Write all Aura dashboard files")
    p.add_argument("output_dir", help="Output directory")
    p.add_argument("--brief", default=None, help="Path to MEMECOIN_BRIEF.md")

    # generate-contracts
    p = sub.add_parser("generate-contracts", help="Write all Anchor program files")
    p.add_argument("output_dir", help="Output directory")
    p.add_argument("--brief", default=None, help="Path to MEMECOIN_BRIEF.md")

    # generate-marketing
    p = sub.add_parser("generate-marketing", help="Write narrative forge content")
    p.add_argument("output_dir", help="Output directory")
    p.add_argument("--brief", default=None, help="Path to MEMECOIN_BRIEF.md")

    # generate-manifest
    p = sub.add_parser("generate-manifest", help="Write complete repo structure")
    p.add_argument("output_dir", help="Output directory")
    p.add_argument("--brief", default=None, help="Path to MEMECOIN_BRIEF.md")

    # apply-brief
    p = sub.add_parser("apply-brief", help="Load and validate a MEMECOIN_BRIEF.md")
    p.add_argument("brief_path", help="Path to MEMECOIN_BRIEF.md")

    # token-report
    sub.add_parser("token-report", help="Show cumulative token savings report")

    # serve
    sub.add_parser("serve", help="Start MCP stdio server")

    args = parser.parse_args()

    commands = {
        "build-index": cmd_build_index,
        "check-index": cmd_check_index,
        "search": cmd_search,
        "list": cmd_list,
        "extract": cmd_extract,
        "generate-dashboard": cmd_generate_dashboard,
        "generate-contracts": cmd_generate_contracts,
        "generate-marketing": cmd_generate_marketing,
        "generate-manifest": cmd_generate_manifest,
        "apply-brief": cmd_apply_brief,
        "token-report": cmd_token_report,
        "serve": cmd_serve,
    }

    handler = commands.get(args.command)
    if handler:
        handler(args)
    else:
        parser.print_help()
        sys.exit(1)
