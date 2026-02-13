"""MCP stdio JSON-RPC 2.0 server for Pine-Library Engine.

Exposes 11 tools for community Pine Script search and extraction.
Zero external dependencies — stdlib only.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict

TOOLS = [
    {
        "name": "plib_search",
        "description": "Search community Pine Script indicators, strategies, and libraries by keyword, tag, author, or type. Returns ranked results with boosts.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query (e.g. 'volume profile', 'MACD divergence', 'LuxAlgo')"},
                "script_type": {"type": "string", "enum": ["indicator", "strategy", "library"], "description": "Filter by type (optional)"},
                "tag": {"type": "string", "description": "Filter by tag (optional)"},
                "author": {"type": "string", "description": "Filter by author (optional)"},
                "limit": {"type": "integer", "default": 10, "description": "Max results (default 10)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "plib_get_script",
        "description": "Get full script data: metadata, description, and source code for a community Pine Script by ID.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "script_id": {"type": "string", "description": "Script ID (e.g. 'PUB;175', 'PUB;ad25fb10941f48b5bc2a44a6784040c6')"},
            },
            "required": ["script_id"],
        },
    },
    {
        "name": "plib_get_source",
        "description": "Get only the Pine Script source code of a community script. ~750 tokens instead of full file.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "script_id": {"type": "string", "description": "Script ID"},
            },
            "required": ["script_id"],
        },
    },
    {
        "name": "plib_list_scripts",
        "description": "List community Pine scripts with optional filters: type (indicator/strategy/library), tag, author, sort by boosts/title/author.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "script_type": {"type": "string", "enum": ["indicator", "strategy", "library"], "description": "Filter by type"},
                "tag": {"type": "string", "description": "Filter by tag"},
                "author": {"type": "string", "description": "Filter by author"},
                "sort_by": {"type": "string", "enum": ["boosts", "title", "author"], "default": "boosts"},
                "limit": {"type": "integer", "default": 20, "description": "Max results"},
            },
        },
    },
    {
        "name": "plib_list_tags",
        "description": "List all tags across community Pine scripts with script counts.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "min_count": {"type": "integer", "default": 1, "description": "Minimum scripts with this tag"},
            },
        },
    },
    {
        "name": "plib_list_authors",
        "description": "List all authors of community Pine scripts with script counts.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "min_scripts": {"type": "integer", "default": 1, "description": "Minimum scripts by author"},
            },
        },
    },
    {
        "name": "plib_code_examples",
        "description": "Get Pine Script code examples matching a topic across all community scripts.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "topic": {"type": "string", "description": "Topic or keyword to find examples for"},
            },
            "required": ["topic"],
        },
    },
    {
        "name": "plib_extract",
        "description": "Extract any entry by ID (script or example). Auto-detects type from ID prefix.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "entry_id": {"type": "string", "description": "Entry ID (script ID or ex/ID-N)"},
            },
            "required": ["entry_id"],
        },
    },
    {
        "name": "plib_index_status",
        "description": "Check Pine-Library index statistics: total scripts, tags, authors, examples.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "plib_usage_report",
        "description": "Show cumulative token usage and savings from Pine-Library extractions.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "plib_suggest",
        "description": "Suggest similar script IDs, titles, or tags for a misspelled or partial query.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Partial or misspelled query"},
            },
            "required": ["query"],
        },
    },
]


class PineLibraryMCPServer:
    """Minimal MCP server over stdio for Pine-Library."""

    def __init__(self, skill_dir: Path, index_path: Path, log_path: Path):
        self.skill_dir = skill_dir
        self.index_path = index_path
        self.log_path = log_path
        self.index = None
        self.extractor = None
        self.searcher = None
        self.tracker = None

    def _ensure_loaded(self) -> None:
        if self.index is not None:
            return

        if not self.index_path.exists():
            raw_dir = self.skill_dir / "data" / "raw"
            if raw_dir.exists() and list(raw_dir.glob("*.md")):
                from .indexer import build_index
                idx = build_index(raw_dir)
                try:
                    idx.save(self.index_path)
                except (OSError, IOError):
                    pass

        try:
            with open(self.index_path, "r", encoding="utf-8") as f:
                self.index = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError, OSError):
            from .indexer import build_index
            raw_dir = self.skill_dir / "data" / "raw"
            idx = build_index(raw_dir)
            try:
                idx.save(self.index_path)
            except (OSError, IOError):
                pass
            from dataclasses import asdict
            self.index = asdict(idx)

        from .extractor import Extractor
        from .searcher import Searcher
        from .tracker import TokenTracker

        self.extractor = Extractor(self.index, self.skill_dir)
        self.searcher = Searcher(self.index)
        self.tracker = TokenTracker(self.log_path)

    def handle(self, request: Dict[str, Any]) -> Dict[str, Any] | None:
        method = request.get("method", "")
        req_id = request.get("id")
        params = request.get("params", {})

        if method == "initialize":
            return self._response(req_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "pine-library-engine", "version": "1.0.0"},
            })

        if method == "notifications/initialized":
            return None

        if method == "tools/list":
            return self._response(req_id, {"tools": TOOLS})

        if method == "tools/call":
            return self._call_tool(req_id, params)

        return self._error(req_id, -32601, f"Method not found: {method}")

    def _call_tool(self, req_id: Any, params: Dict[str, Any]) -> Dict[str, Any]:
        self._ensure_loaded()
        tool_name = params.get("name", "")
        args = params.get("arguments", {})

        try:
            result = self._dispatch_tool(tool_name, args)
            text = json.dumps(result, indent=2, ensure_ascii=False)

            tokens_used = len(text) // 4
            tokens_saved = max(tokens_used * 3, 0)
            self.tracker.log(tool_name, tokens_used, tokens_saved, {"args": args})

            return self._response(req_id, {
                "content": [{"type": "text", "text": text}],
            })
        except Exception as e:
            return self._tool_error(req_id, f"Error in {tool_name}: {e}")

    def _dispatch_tool(self, tool_name: str, args: Dict[str, Any]) -> Any:
        """Route tool call to appropriate handler."""
        if tool_name == "plib_search":
            return self.searcher.search(
                args.get("query", ""),
                script_type=args.get("script_type"),
                tag=args.get("tag"),
                author=args.get("author"),
                limit=args.get("limit", 10),
            )

        elif tool_name == "plib_get_script":
            result = self.extractor.get_script(args.get("script_id", ""))
            if not result:
                return {"error": f"Script not found: {args.get('script_id', '')}",
                        "suggestions": self.searcher.suggest(args.get("script_id", ""))}
            return result

        elif tool_name == "plib_get_source":
            result = self.extractor.get_source(args.get("script_id", ""))
            if not result:
                return {"error": f"Script not found: {args.get('script_id', '')}",
                        "suggestions": self.searcher.suggest(args.get("script_id", ""))}
            return result

        elif tool_name == "plib_list_scripts":
            return self.extractor.list_scripts(
                script_type=args.get("script_type"),
                tag=args.get("tag"),
                author=args.get("author"),
                sort_by=args.get("sort_by", "boosts"),
                limit=args.get("limit", 20),
            )

        elif tool_name == "plib_list_tags":
            return self.extractor.list_tags(min_count=args.get("min_count", 1))

        elif tool_name == "plib_list_authors":
            return self.extractor.list_authors(min_scripts=args.get("min_scripts", 1))

        elif tool_name == "plib_code_examples":
            return self.extractor.get_examples_for_topic(args.get("topic", ""))

        elif tool_name == "plib_extract":
            result = self.extractor.extract(args.get("entry_id", ""))
            if not result:
                return {"error": f"Entry not found: {args.get('entry_id', '')}",
                        "suggestions": self.searcher.suggest(args.get("entry_id", ""))}
            return result

        elif tool_name == "plib_index_status":
            return {
                "stats": self.index.get("stats", {}),
                "version": self.index.get("version", ""),
                "generated_at": self.index.get("generated_at", ""),
                "source_hash": self.index.get("source_hash", ""),
            }

        elif tool_name == "plib_usage_report":
            return self.tracker.report()

        elif tool_name == "plib_suggest":
            return {"suggestions": self.searcher.suggest(args.get("query", ""))}

        else:
            raise ValueError(f"Unknown tool: {tool_name}")

    def _tool_error(self, req_id: Any, message: str) -> Dict[str, Any]:
        return self._response(req_id, {
            "content": [{"type": "text", "text": message}],
            "isError": True,
        })

    def _response(self, req_id: Any, result: Any) -> Dict[str, Any]:
        return {"jsonrpc": "2.0", "id": req_id, "result": result}

    def _error(self, req_id: Any, code: int, message: str) -> Dict[str, Any]:
        return {"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}}

    def run(self) -> None:
        """Main stdio loop."""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                request = json.loads(line)
                response = self.handle(request)
                if response is not None:
                    sys.stdout.write(json.dumps(response) + "\n")
                    sys.stdout.flush()
            except json.JSONDecodeError:
                err = self._error(None, -32700, "Parse error")
                sys.stdout.write(json.dumps(err) + "\n")
                sys.stdout.flush()
            except Exception as e:
                err = self._error(None, -32603, str(e))
                sys.stdout.write(json.dumps(err) + "\n")
                sys.stdout.flush()


def run_server(skill_dir: Path, index_path: Path, log_path: Path) -> None:
    """Entry point for MCP server."""
    server = PineLibraryMCPServer(skill_dir, index_path, log_path)
    server.run()
