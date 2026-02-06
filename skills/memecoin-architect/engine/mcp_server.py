"""MCP stdio JSON-RPC 2.0 server for Memecoin Architect Engine."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict

TOOLS = [
    {
        "name": "memecoin_search",
        "description": "Search memecoin skill content: contracts, templates, references, scripts. Returns ranked results.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query (e.g. 'treasury', 'burn', 'governance')"},
                "category": {
                    "type": "string",
                    "enum": ["sections", "templates", "contracts", "scripts"],
                    "description": "Restrict to a category (optional)",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "memecoin_list_templates",
        "description": "List all Aura dashboard template files with component types and route groups.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "memecoin_list_contracts",
        "description": "List all Anchor contract programs with instructions, accounts, and events.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "memecoin_list_references",
        "description": "List all reference documentation sections.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "memecoin_extract",
        "description": "Extract content by entry ID. Auto-detects type from ID prefix (contracts/, templates/, scripts/, or section).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "entry_id": {"type": "string", "description": "Entry ID (e.g. contracts/treasury_vault, templates/app/(dashboard)/page.tsx)"},
            },
            "required": ["entry_id"],
        },
    },
    {
        "name": "memecoin_extract_template",
        "description": "Extract a full Aura dashboard template file by ID. Returns component type, exports, and content.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "template_id": {"type": "string", "description": "Template ID (e.g. templates/hooks/useTokenMetrics.ts)"},
            },
            "required": ["template_id"],
        },
    },
    {
        "name": "memecoin_generate_dashboard",
        "description": "Generate all Aura dashboard files to an output directory with optional brief overrides. ~99% token savings.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "output_dir": {"type": "string", "description": "Output directory path"},
                "brief_path": {"type": "string", "description": "Optional path to MEMECOIN_BRIEF.md"},
            },
            "required": ["output_dir"],
        },
    },
    {
        "name": "memecoin_generate_contracts",
        "description": "Generate all Anchor program files to an output directory. ~99% token savings.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "output_dir": {"type": "string", "description": "Output directory path"},
                "brief_path": {"type": "string", "description": "Optional path to MEMECOIN_BRIEF.md"},
            },
            "required": ["output_dir"],
        },
    },
    {
        "name": "memecoin_index_status",
        "description": "Check index stats and freshness. Reports entry counts and whether a rebuild is needed.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


class MemecoinMCPServer:
    """Minimal MCP server over stdio."""

    def __init__(self, skill_dir: Path, index_path: Path, log_path: Path):
        self.skill_dir = skill_dir
        self.index_path = index_path
        self.log_path = log_path
        self.index = None
        self.extractor = None
        self.searcher = None
        self.tracker = None

    def _ensure_loaded(self):
        if self.index is not None:
            return

        if not self.index_path.exists():
            from .indexer import build_index
            idx = build_index(self.skill_dir)
            try:
                idx.save(self.index_path)
            except (OSError, IOError):
                pass

        try:
            with open(self.index_path, "r", encoding="utf-8") as f:
                self.index = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError, OSError):
            from .indexer import build_index
            from dataclasses import asdict
            idx = build_index(self.skill_dir)
            try:
                idx.save(self.index_path)
            except (OSError, IOError):
                pass
            self.index = asdict(idx)

        from .extractor import Extractor
        from .searcher import Searcher
        from .tracker import TokenTracker

        self.extractor = Extractor(self.index, self.skill_dir)
        self.searcher = Searcher(self.index)
        self.tracker = TokenTracker(self.log_path)

    def handle(self, request: Dict[str, Any]) -> Dict[str, Any]:
        method = request.get("method", "")
        req_id = request.get("id")
        params = request.get("params", {})

        if method == "initialize":
            return self._response(req_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "memecoin-architect-engine", "version": "1.0.0"},
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
            result = self._dispatch(tool_name, args)
            text = json.dumps(result, indent=2, ensure_ascii=False)
            return self._response(req_id, {
                "content": [{"type": "text", "text": text}],
            })
        except Exception as e:
            return self._response(req_id, {
                "content": [{"type": "text", "text": f"Error: {e}"}],
                "isError": True,
            })

    def _dispatch(self, tool_name: str, args: Dict[str, Any]) -> Any:
        if tool_name == "memecoin_search":
            return self.searcher.search(
                args.get("query", ""), category=args.get("category"))

        if tool_name == "memecoin_list_templates":
            return self.searcher.list_category("templates")

        if tool_name == "memecoin_list_contracts":
            return self.searcher.list_category("contracts")

        if tool_name == "memecoin_list_references":
            results = self.searcher.list_category("sections")
            return [r for r in results if "reference/" in r.get("id", "")]

        if tool_name == "memecoin_extract":
            result = self.extractor.extract(args.get("entry_id", ""))
            if not result:
                return {"error": f"Entry not found: {args.get('entry_id', '')}"}
            return result

        if tool_name == "memecoin_extract_template":
            result = self.extractor.get_template(args.get("template_id", ""))
            if not result:
                return {"error": f"Template not found: {args.get('template_id', '')}"}
            return result

        if tool_name == "memecoin_generate_dashboard":
            from .generator import Generator
            output = self._validate_output_path(args.get("output_dir", ""))
            brief = Path(args["brief_path"]) if args.get("brief_path") else None
            gen = Generator(self.skill_dir, brief)
            return gen.generate_dashboard(output)

        if tool_name == "memecoin_generate_contracts":
            from .generator import Generator
            output = self._validate_output_path(args.get("output_dir", ""))
            brief = Path(args["brief_path"]) if args.get("brief_path") else None
            gen = Generator(self.skill_dir, brief)
            return gen.generate_contracts(output)

        if tool_name == "memecoin_index_status":
            from .indexer import check_index_freshness
            from .schema import Index
            idx = Index()
            _known = {"version", "generated_at", "source_hash", "sections", "templates", "contracts", "scripts", "stats"}
            for k, v in self.index.items():
                if k in _known:
                    setattr(idx, k, v)
            fresh = check_index_freshness(idx, self.skill_dir)
            return {
                "fresh": fresh,
                "stats": self.index.get("stats", {}),
                "generated_at": self.index.get("generated_at", ""),
            }

        raise ValueError(f"Unknown tool: {tool_name}")

    def _validate_output_path(self, output_dir: str) -> Path:
        """Validate output_dir to prevent writes to sensitive locations."""
        if not output_dir:
            raise ValueError("output_dir is required")
        p = Path(output_dir).resolve()
        ps = str(p)
        # Block writes to system directories (resolve symlinks: macOS /etc -> /private/etc)
        blocked = ("/etc", "/usr", "/bin", "/sbin", "/var", "/System", "/Library",
                   "/private/etc", "/private/var")
        for prefix in blocked:
            if ps == prefix or ps.startswith(prefix + "/"):
                raise ValueError(f"Refusing to write to system path: {p}")
        return p

    def _response(self, req_id: Any, result: Any) -> Dict[str, Any]:
        return {"jsonrpc": "2.0", "id": req_id, "result": result}

    def _error(self, req_id: Any, code: int, message: str) -> Dict[str, Any]:
        return {"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}}

    def run(self):
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
            except (ValueError, KeyError, FileNotFoundError, OSError) as e:
                err = self._error(None, -32603, str(e))
                sys.stdout.write(json.dumps(err) + "\n")
                sys.stdout.flush()
            except Exception:
                err = self._error(None, -32603, "Internal server error")
                sys.stdout.write(json.dumps(err) + "\n")
                sys.stdout.flush()


def run_server(skill_dir: Path, index_path: Path, log_path: Path) -> None:
    """Entry point called by cli.py serve command."""
    server = MemecoinMCPServer(skill_dir, index_path, log_path)
    server.run()
