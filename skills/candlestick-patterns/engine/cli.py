"""CLI command router for the Candlestick Patterns Engine."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

SKILL_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = SKILL_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
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
    """Build search index from cached docs."""
    from .indexer import build_index
    if not RAW_DIR.exists() or not list(RAW_DIR.glob("*.md")):
        _out({"status": "error", "command": "build-index",
              "error": f"No markdown files in {RAW_DIR}. Add .md files to data/raw/ first."})
        sys.exit(2)
    idx = build_index(RAW_DIR)
    idx.save(INDEX_PATH)
    _out({
        "status": "ok",
        "command": "build-index",
        "index_path": str(INDEX_PATH),
        "stats": idx.stats,
    })


def cmd_check_index(args: argparse.Namespace) -> None:
    """Check index freshness."""
    from .indexer import check_index_freshness
    from .schema import Index

    index_data = _load_index("check-index")
    idx = Index.load(INDEX_PATH)
    fresh = check_index_freshness(idx, RAW_DIR)
    _out({
        "status": "ok",
        "command": "check-index",
        "fresh": fresh,
        "generated_at": index_data.get("generated_at", ""),
        "stats": index_data.get("stats", {}),
        "warning": None if fresh else "Index is stale. Run: python3 -m engine build-index",
    })


def cmd_search(args: argparse.Namespace) -> None:
    """Search candlestick docs."""
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
        "results": results,
        "count": len(results),
    })


def cmd_extract(args: argparse.Namespace) -> None:
    """Extract content by entry ID."""
    from .extractor import Extractor
    index_data = _load_index("extract")
    extractor = Extractor(index_data, SKILL_DIR)
    result = extractor.extract(args.entry_id)

    if result is None:
        _out({"status": "error", "command": "extract",
              "error": f"Entry not found: {args.entry_id}"})
        sys.exit(1)

    tracker = _tracker()
    tokens = result.get("tokens", {})
    tracker.log(
        "extract",
        tokens_used=tokens.get("estimated_output", 0),
        tokens_saved=tokens.get("full_file_tokens", 0) - tokens.get("estimated_output", 0),
        details={"entry_id": args.entry_id},
    )

    _out({"status": "ok", "command": "extract", "result": result})


def cmd_get_pattern(args: argparse.Namespace) -> None:
    """Get a specific pattern."""
    from .extractor import Extractor
    index_data = _load_index("get-pattern")
    extractor = Extractor(index_data, SKILL_DIR)
    result = extractor.get_pattern(args.name)

    if result is None:
        _out({"status": "error", "command": "get-pattern",
              "error": f"Pattern not found: {args.name}"})
        sys.exit(1)

    _out({"status": "ok", "command": "get-pattern", "result": result})


def cmd_list_patterns(args: argparse.Namespace) -> None:
    """List all patterns."""
    from .extractor import Extractor
    index_data = _load_index("list-patterns")
    extractor = Extractor(index_data, SKILL_DIR)
    results = extractor.list_patterns(
        signal=args.signal,
        pattern_type=args.type,
        category=args.pat_category,
    )
    _out({
        "status": "ok",
        "command": "list-patterns",
        "results": results,
        "count": len(results),
    })


def cmd_list_strategies(args: argparse.Namespace) -> None:
    """List all strategies."""
    from .extractor import Extractor
    index_data = _load_index("list-strategies")
    extractor = Extractor(index_data, SKILL_DIR)
    results = extractor.list_strategies()
    _out({
        "status": "ok",
        "command": "list-strategies",
        "results": results,
        "count": len(results),
    })


def cmd_list(args: argparse.Namespace) -> None:
    """List entries in a category."""
    from .searcher import Searcher
    index_data = _load_index("list")
    searcher = Searcher(index_data)
    results = searcher.list_category(args.category)
    _out({
        "status": "ok",
        "command": "list",
        "category": args.category,
        "results": results,
        "count": len(results),
    })


def cmd_status(args: argparse.Namespace) -> None:
    """Show engine status."""
    raw_files = list(RAW_DIR.glob("*.md")) if RAW_DIR.exists() else []
    has_index = INDEX_PATH.exists()

    status: Dict[str, Any] = {
        "status": "ok",
        "command": "status",
        "raw_dir": str(RAW_DIR),
        "raw_files": len(raw_files),
        "index_exists": has_index,
    }

    if has_index:
        index_data = _load_index("status")
        status["stats"] = index_data.get("stats", {})
        status["generated_at"] = index_data.get("generated_at", "")

    _out(status)


def cmd_token_report(args: argparse.Namespace) -> None:
    """Show token usage report."""
    tracker = _tracker()
    report = tracker.report()
    _out({"status": "ok", "command": "token-report", **report})


def cmd_serve(args: argparse.Namespace) -> None:
    """Start MCP stdio server."""
    from .mcp_server import run_server
    run_server(SKILL_DIR, INDEX_PATH, LOG_PATH)


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        prog="candlestick-patterns",
        description="Candlestick Patterns Engine — Japanese candlestick MCP server with 90%%+ token reduction",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # build-index
    sub.add_parser("build-index", help="Build search index from cached docs")

    # check-index
    sub.add_parser("check-index", help="Check index freshness")

    # search
    p = sub.add_parser("search", help="Search candlestick documentation")
    p.add_argument("query", help="Search query")
    p.add_argument("--category", choices=["sections", "patterns", "strategies", "examples"],
                   default=None, help="Restrict to category")
    p.add_argument("--limit", type=int, default=10, help="Max results")

    # extract
    p = sub.add_parser("extract", help="Extract content by entry ID")
    p.add_argument("entry_id", help="Entry ID (e.g. pat/hammer, strat/pin-bar, patterns/doji)")

    # get-pattern
    p = sub.add_parser("get-pattern", help="Get a specific candlestick pattern")
    p.add_argument("name", help="Pattern name (e.g. hammer, morning-star, engulfing)")

    # list-patterns
    p = sub.add_parser("list-patterns", help="List all candlestick patterns")
    p.add_argument("--signal", choices=["bullish", "bearish", "neutral"], help="Filter by signal")
    p.add_argument("--type", choices=["reversal", "continuation", "indecision"], help="Filter by type")
    p.add_argument("--pat-category", help="Filter by category (single-reversal, doji, etc.)")

    # list-strategies
    sub.add_parser("list-strategies", help="List all trading strategies")

    # list
    p = sub.add_parser("list", help="List entries in a category")
    p.add_argument("category", choices=["sections", "patterns", "strategies", "examples"],
                   help="Category to list")

    # status
    sub.add_parser("status", help="Show engine status")

    # token-report
    sub.add_parser("token-report", help="Show token usage report")

    # serve
    sub.add_parser("serve", help="Start MCP stdio server")

    args = parser.parse_args()

    commands = {
        "build-index": cmd_build_index,
        "check-index": cmd_check_index,
        "search": cmd_search,
        "extract": cmd_extract,
        "get-pattern": cmd_get_pattern,
        "list-patterns": cmd_list_patterns,
        "list-strategies": cmd_list_strategies,
        "list": cmd_list,
        "status": cmd_status,
        "token-report": cmd_token_report,
        "serve": cmd_serve,
    }

    handler = commands.get(args.command)
    if handler:
        handler(args)
    else:
        parser.print_help()
        sys.exit(1)
