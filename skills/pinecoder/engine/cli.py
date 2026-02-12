"""CLI command router for the PineCoder Engine."""
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
              "error": "Index not found. Run: python3 -m engine scrape && python3 -m engine build-index"})
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

def cmd_scrape(args: argparse.Namespace) -> None:
    """Scrape Pine Script docs from TradingView."""
    from .scraper import scrape_all
    manifest = scrape_all(RAW_DIR, force=args.force, delay=args.delay, verbose=True)
    _out({
        "status": "ok",
        "command": "scrape",
        "pages_scraped": len(manifest),
        "output_dir": str(RAW_DIR),
    })


def cmd_import_docs(args: argparse.Namespace) -> None:
    """Import docs from a local directory."""
    from .scraper import import_local_files
    source = Path(args.source_dir)
    if not source.is_dir():
        _out({"status": "error", "command": "import",
              "error": f"Not a directory: {args.source_dir}"})
        sys.exit(1)
    manifest = import_local_files(source, RAW_DIR, verbose=True)
    _out({
        "status": "ok",
        "command": "import",
        "files_imported": len(manifest),
        "output_dir": str(RAW_DIR),
    })


def cmd_build_index(args: argparse.Namespace) -> None:
    """Build search index from cached docs."""
    from .indexer import build_index
    if not RAW_DIR.exists() or not list(RAW_DIR.glob("*.md")):
        _out({"status": "error", "command": "build-index",
              "error": f"No markdown files in {RAW_DIR}. Run: python3 -m engine scrape"})
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
    """Search Pine Script docs."""
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

    status = {
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
        prog="pinecoder",
        description="PineCoder Engine — Pine Script v6 docs MCP server with 90%%+ token reduction",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # scrape
    p = sub.add_parser("scrape", help="Crawl Pine Script docs from TradingView")
    p.add_argument("--force", action="store_true", help="Re-scrape even if cached")
    p.add_argument("--delay", type=float, default=1.5, help="Delay between requests (seconds)")

    # import
    p = sub.add_parser("import", help="Import docs from a local directory")
    p.add_argument("source_dir", help="Directory containing .html or .md files")

    # build-index
    sub.add_parser("build-index", help="Build search index from cached docs")

    # check-index
    sub.add_parser("check-index", help="Check index freshness")

    # search
    p = sub.add_parser("search", help="Search Pine Script documentation")
    p.add_argument("query", help="Search query")
    p.add_argument("--category", choices=["sections", "functions", "examples"],
                   default=None, help="Restrict to category")
    p.add_argument("--limit", type=int, default=10, help="Max results")

    # extract
    p = sub.add_parser("extract", help="Extract content by entry ID")
    p.add_argument("entry_id", help="Entry ID (e.g. fn/ta.sma, language/arrays)")

    # list
    p = sub.add_parser("list", help="List entries in a category")
    p.add_argument("category", choices=["sections", "functions", "examples"],
                   help="Category to list")

    # status
    sub.add_parser("status", help="Show engine status")

    # token-report
    sub.add_parser("token-report", help="Show token usage report")

    # serve
    sub.add_parser("serve", help="Start MCP stdio server")

    args = parser.parse_args()

    commands = {
        "scrape": cmd_scrape,
        "import": cmd_import_docs,
        "build-index": cmd_build_index,
        "check-index": cmd_check_index,
        "search": cmd_search,
        "extract": cmd_extract,
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
