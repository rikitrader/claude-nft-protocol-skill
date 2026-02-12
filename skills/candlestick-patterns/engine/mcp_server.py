"""MCP stdio JSON-RPC 2.0 server for Candlestick Patterns Engine.

Exposes 11 tools for Japanese candlestick pattern documentation search and extraction.
Zero external dependencies — stdlib only.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict

TOOLS = [
    {
        "name": "candle_search",
        "description": "Search Japanese candlestick documentation across all sections, patterns, strategies, and examples. Returns ranked results.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query (e.g. 'hammer reversal', 'morning star', 'engulfing strategy')"},
                "category": {"type": "string", "enum": ["sections", "patterns", "strategies", "examples"], "description": "Restrict to a category (optional)"},
                "limit": {"type": "integer", "default": 10, "description": "Max results (default 10)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "candle_get_section",
        "description": "Extract a documentation section by ID. Returns full content or outline only. ~800 tokens instead of full page (~18K).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "section_id": {"type": "string", "description": "Section ID (e.g. 'patterns/hammer', 'convergence/candles-with-rsi')"},
                "outline_only": {"type": "boolean", "default": False, "description": "Return headings only"},
            },
            "required": ["section_id"],
        },
    },
    {
        "name": "candle_get_pattern",
        "description": "Get full documentation for a Japanese candlestick pattern. Returns name, Japanese name, signal, type, reliability, and content.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Pattern name (e.g. 'hammer', 'morning star', 'bearish engulfing', 'doji')"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "candle_list_patterns",
        "description": "List all indexed candlestick patterns. Filter by signal (bullish/bearish/neutral), type (reversal/continuation/indecision), or category.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "signal": {"type": "string", "enum": ["bullish", "bearish", "neutral"], "description": "Filter by signal direction"},
                "pattern_type": {"type": "string", "enum": ["reversal", "continuation", "indecision"], "description": "Filter by pattern type"},
                "category": {"type": "string", "description": "Filter by category (single-reversal, dual-reversal, triple-reversal, doji, continuation)"},
            },
        },
    },
    {
        "name": "candle_get_strategy",
        "description": "Get full documentation for a candlestick trading strategy. Returns patterns used, indicators, timeframes, and content.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Strategy name (e.g. 'pin bar setup', 'engulfing with fibonacci')"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "candle_list_strategies",
        "description": "List all indexed candlestick trading strategies with their patterns and indicators.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "candle_list_signals",
        "description": "List pattern counts grouped by signal direction (bullish/bearish/neutral).",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "candle_code_examples",
        "description": "Get all code examples for a topic or section.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "topic": {"type": "string", "description": "Topic or section ID to get examples for"},
            },
            "required": ["topic"],
        },
    },
    {
        "name": "candle_extract",
        "description": "Extract any entry by ID (section, pattern, strategy, or example). Auto-detects type from ID prefix (pat/, strat/, ex/).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "entry_id": {"type": "string", "description": "Entry ID (e.g. 'pat/hammer', 'strat/pin-bar-setup', 'patterns/morning-star')"},
            },
            "required": ["entry_id"],
        },
    },
    {
        "name": "candle_index_status",
        "description": "Check index statistics: total sections, patterns, strategies, examples, and freshness status.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "candle_suggest",
        "description": "Suggest similar entry IDs for a misspelled or partial query. Useful for typo correction.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Partial or misspelled entry ID"},
            },
            "required": ["query"],
        },
    },
]


class CandlestickMCPServer:
    """Minimal MCP server over stdio for Japanese candlestick pattern docs."""

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
                "serverInfo": {"name": "candlestick-engine", "version": "1.0.0"},
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
        if tool_name == "candle_search":
            return self.searcher.search(
                args.get("query", ""),
                category=args.get("category"),
                limit=args.get("limit", 10),
            )

        elif tool_name == "candle_get_section":
            result = self.extractor.get_section(
                args.get("section_id", ""),
                outline_only=args.get("outline_only", False),
            )
            if not result:
                return {"error": f"Section not found: {args.get('section_id', '')}",
                        "suggestions": self.searcher.suggest(args.get("section_id", ""))}
            return result

        elif tool_name == "candle_get_pattern":
            result = self.extractor.get_pattern(args.get("name", ""))
            if not result:
                return {"error": f"Pattern not found: {args.get('name', '')}",
                        "suggestions": self.searcher.suggest(args.get("name", ""))}
            return result

        elif tool_name == "candle_list_patterns":
            return self.extractor.list_patterns(
                signal=args.get("signal"),
                pattern_type=args.get("pattern_type"),
                category=args.get("category"),
            )

        elif tool_name == "candle_get_strategy":
            result = self.extractor.get_strategy(args.get("name", ""))
            if not result:
                return {"error": f"Strategy not found: {args.get('name', '')}",
                        "suggestions": self.searcher.suggest(args.get("name", ""))}
            return result

        elif tool_name == "candle_list_strategies":
            return self.extractor.list_strategies()

        elif tool_name == "candle_list_signals":
            return self.searcher.list_signals()

        elif tool_name == "candle_code_examples":
            topic = args.get("topic", "")
            return self.extractor.get_examples_for_section(topic)

        elif tool_name == "candle_extract":
            result = self.extractor.extract(args.get("entry_id", ""))
            if not result:
                return {"error": f"Entry not found: {args.get('entry_id', '')}",
                        "suggestions": self.searcher.suggest(args.get("entry_id", ""))}
            return result

        elif tool_name == "candle_index_status":
            return {
                "stats": self.index.get("stats", {}),
                "version": self.index.get("version", ""),
                "generated_at": self.index.get("generated_at", ""),
                "source_hash": self.index.get("source_hash", ""),
            }

        elif tool_name == "candle_suggest":
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
    server = CandlestickMCPServer(skill_dir, index_path, log_path)
    server.run()
