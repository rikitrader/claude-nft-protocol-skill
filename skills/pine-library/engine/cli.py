"""CLI command router for the Pine-Library Engine."""
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
    """Build search index from raw script files."""
    from .indexer import build_index
    if not RAW_DIR.exists() or not list(RAW_DIR.glob("*.md")):
        _out({"status": "error", "command": "build-index",
              "error": f"No markdown files in {RAW_DIR}. Run scraping first."})
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
    """Search Pine Script community scripts."""
    from .searcher import Searcher
    index_data = _load_index("search")
    searcher = Searcher(index_data)
    results = searcher.search(
        args.query,
        script_type=args.type,
        tag=args.tag,
        author=args.author,
        limit=args.limit,
    )

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


def cmd_get_script(args: argparse.Namespace) -> None:
    """Get full script data."""
    from .extractor import Extractor
    index_data = _load_index("get-script")
    extractor = Extractor(index_data, SKILL_DIR)
    result = extractor.get_script(args.script_id)
    if result is None:
        _out({"status": "error", "command": "get-script",
              "error": f"Script not found: {args.script_id}"})
        sys.exit(1)

    tracker = _tracker()
    tokens = result.get("tokens", {})
    tracker.log("get-script", tokens_used=tokens.get("estimated_output", 0),
                tokens_saved=tokens.get("full_file_tokens", 0) - tokens.get("estimated_output", 0))

    _out({"status": "ok", "command": "get-script", "result": result})


def cmd_get_source(args: argparse.Namespace) -> None:
    """Get Pine Script source code only."""
    from .extractor import Extractor
    index_data = _load_index("get-source")
    extractor = Extractor(index_data, SKILL_DIR)
    result = extractor.get_source(args.script_id)
    if result is None:
        _out({"status": "error", "command": "get-source",
              "error": f"Script not found: {args.script_id}"})
        sys.exit(1)

    tracker = _tracker()
    tokens = result.get("tokens", {})
    tracker.log("get-source", tokens_used=tokens.get("estimated_output", 0),
                tokens_saved=tokens.get("full_file_tokens", 0) - tokens.get("estimated_output", 0))

    _out({"status": "ok", "command": "get-source", "result": result})


def cmd_list_scripts(args: argparse.Namespace) -> None:
    """List scripts with filters."""
    from .extractor import Extractor
    index_data = _load_index("list-scripts")
    extractor = Extractor(index_data, SKILL_DIR)
    results = extractor.list_scripts(
        script_type=args.type,
        tag=args.tag,
        author=args.author,
        sort_by=args.sort,
        limit=args.limit,
    )
    _out({
        "status": "ok",
        "command": "list-scripts",
        "results": results,
        "count": len(results),
    })


def cmd_list_tags(args: argparse.Namespace) -> None:
    """List all tags with counts."""
    from .extractor import Extractor
    index_data = _load_index("list-tags")
    extractor = Extractor(index_data, SKILL_DIR)
    results = extractor.list_tags(min_count=args.min_count)
    _out({
        "status": "ok",
        "command": "list-tags",
        "results": results,
        "count": len(results),
    })


def cmd_list_authors(args: argparse.Namespace) -> None:
    """List all authors with script counts."""
    from .extractor import Extractor
    index_data = _load_index("list-authors")
    extractor = Extractor(index_data, SKILL_DIR)
    results = extractor.list_authors(min_scripts=args.min_scripts)
    _out({
        "status": "ok",
        "command": "list-authors",
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
    tracker.log("extract", tokens_used=tokens.get("estimated_output", 0),
                tokens_saved=tokens.get("full_file_tokens", 0) - tokens.get("estimated_output", 0),
                details={"entry_id": args.entry_id})

    _out({"status": "ok", "command": "extract", "result": result})


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
        prog="pine-library",
        description="Pine-Library Engine — Community Pine scripts MCP server with 90%%+ token reduction",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # build-index
    sub.add_parser("build-index", help="Build search index from raw script files")

    # check-index
    sub.add_parser("check-index", help="Check index freshness")

    # search
    p = sub.add_parser("search", help="Search community Pine scripts")
    p.add_argument("query", help="Search query")
    p.add_argument("--type", choices=["indicator", "strategy", "library"],
                   default=None, help="Filter by script type")
    p.add_argument("--tag", default=None, help="Filter by tag")
    p.add_argument("--author", default=None, help="Filter by author")
    p.add_argument("--limit", type=int, default=10, help="Max results")

    # get-script
    p = sub.add_parser("get-script", help="Get full script data")
    p.add_argument("script_id", help="Script ID")

    # get-source
    p = sub.add_parser("get-source", help="Get Pine Script source code only")
    p.add_argument("script_id", help="Script ID")

    # list-scripts
    p = sub.add_parser("list-scripts", help="List scripts with filters")
    p.add_argument("--type", choices=["indicator", "strategy", "library"],
                   default=None, help="Filter by type")
    p.add_argument("--tag", default=None, help="Filter by tag")
    p.add_argument("--author", default=None, help="Filter by author")
    p.add_argument("--sort", choices=["boosts", "title", "author"],
                   default="boosts", help="Sort order")
    p.add_argument("--limit", type=int, default=20, help="Max results")

    # list-tags
    p = sub.add_parser("list-tags", help="List all tags with counts")
    p.add_argument("--min-count", type=int, default=1, help="Minimum script count")

    # list-authors
    p = sub.add_parser("list-authors", help="List all authors with script counts")
    p.add_argument("--min-scripts", type=int, default=1, help="Minimum scripts")

    # extract
    p = sub.add_parser("extract", help="Extract content by entry ID")
    p.add_argument("entry_id", help="Entry ID (script ID or ex/ID-N)")

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
        "get-script": cmd_get_script,
        "get-source": cmd_get_source,
        "list-scripts": cmd_list_scripts,
        "list-tags": cmd_list_tags,
        "list-authors": cmd_list_authors,
        "extract": cmd_extract,
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
