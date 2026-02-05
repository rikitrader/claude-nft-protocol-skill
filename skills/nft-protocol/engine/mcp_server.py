"""MCP stdio JSON-RPC 2.0 server for NFT Protocol Engine."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict

SKILL_DIR = Path(__file__).resolve().parent.parent
MODULES_DIR = SKILL_DIR / "modules"
DATA_DIR = SKILL_DIR / "data"
INDEX_PATH = DATA_DIR / "index.json"
LOG_PATH = DATA_DIR / "token_log.jsonl"

TOOLS = [
    {
        "name": "nft_search",
        "description": "Search NFT protocol contracts, sections, and ERC standards. Returns matched results ranked by relevance.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query (e.g. 'lending', 'soulbound', 'ERC-6551')"},
                "type": {"type": "string", "enum": ["contract", "section", "standard", "all"], "default": "all"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "nft_get_contract",
        "description": "Extract a specific Solidity smart contract by name. Returns the full contract code with metadata. ~750 tokens instead of loading the full module (~18,000 tokens).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "Contract name (e.g. FractionalVault, SoulboundNFT, NFTLending)"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "nft_get_section",
        "description": "Extract a module section by ID. Returns full section content or outline only. ~1,250 tokens instead of full module.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "section_id": {"type": "string", "description": "Section ID (e.g. module-3-fractionalization-vault)"},
                "outline_only": {"type": "boolean", "default": False, "description": "Return headings + declarations only"},
            },
            "required": ["section_id"],
        },
    },
    {
        "name": "nft_list_modules",
        "description": "List all 19 NFT protocol modules with summaries, sizes, contract counts, and ERC standards. ~800 tokens.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "nft_find_by_standard",
        "description": "Find all contracts implementing a specific ERC standard. Returns contract names, modules, and file paths.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "standard": {"type": "string", "description": "ERC standard (e.g. ERC-721, ERC-6551, ERC-4907)"},
            },
            "required": ["standard"],
        },
    },
    {
        "name": "nft_usage_report",
        "description": "Show cumulative token usage statistics and savings vs full-load baseline.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "nft_list_contracts",
        "description": "List all contracts with module, section, file path, and standards.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "nft_list_standards",
        "description": "List all supported ERC/EIP standards with contract counts.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "nft_outline",
        "description": "Get structural outline of a module (section titles, contracts, code block counts). No full code bodies.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "module": {"type": "string", "description": "Module filename (e.g. defi.md, advanced-nfts.md)"},
            },
            "required": ["module"],
        },
    },
    {
        "name": "nft_build_index",
        "description": "Rebuild the search index from all markdown modules. Use after adding or modifying modules.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "nft_check_index",
        "description": "Check if the search index is fresh (modules haven't changed since last build).",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


class NFTProtocolMCPServer:
    """Minimal MCP server over stdio."""

    def __init__(self):
        self.index = None
        self.extractor = None
        self.searcher = None
        self.tracker = None

    def _ensure_loaded(self):
        if self.index is not None:
            return
        if not INDEX_PATH.exists():
            from .indexer import build_index
            idx = build_index(MODULES_DIR)
            try:
                idx.save(INDEX_PATH)
            except (OSError, IOError) as e:
                pass  # Index will be rebuilt next time

        try:
            with open(INDEX_PATH, "r", encoding="utf-8") as f:
                self.index = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError, OSError):
            # Corrupt or missing index — rebuild
            from .indexer import build_index
            idx = build_index(MODULES_DIR)
            try:
                idx.save(INDEX_PATH)
            except (OSError, IOError):
                pass
            from dataclasses import asdict
            self.index = asdict(idx)

        from .extractor import Extractor
        from .searcher import Searcher
        from .tracker import TokenTracker

        self.extractor = Extractor(self.index, MODULES_DIR)
        self.searcher = Searcher(self.index)
        self.tracker = TokenTracker(LOG_PATH)

    def handle(self, request: Dict[str, Any]) -> Dict[str, Any]:
        method = request.get("method", "")
        req_id = request.get("id")
        params = request.get("params", {})

        if method == "initialize":
            return self._response(req_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "nft-protocol-engine", "version": "2.0.0"},
            })

        if method == "notifications/initialized":
            return None  # No response needed for notifications

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
            if tool_name == "nft_search":
                result = self.searcher.search(args.get("query", ""), args.get("type", "all"))
            elif tool_name == "nft_get_contract":
                result = self.extractor.get_contract(args.get("name", ""))
                if not result:
                    result = {"error": f"Contract '{args.get('name', '')}' not found",
                              "suggestions": self.searcher.suggest(args.get("name", ""))}
            elif tool_name == "nft_get_section":
                result = self.extractor.get_section(
                    args.get("section_id", ""), outline_only=args.get("outline_only", False))
                if not result:
                    result = {"error": f"Section '{args.get('section_id', '')}' not found"}
            elif tool_name == "nft_list_modules":
                result = self.searcher.list_modules()
            elif tool_name == "nft_find_by_standard":
                result = self.searcher.find_by_standard(args.get("standard", ""))
            elif tool_name == "nft_usage_report":
                result = self.tracker.report()
            elif tool_name == "nft_list_contracts":
                result = self.searcher.list_contracts()
            elif tool_name == "nft_list_standards":
                result = self.searcher.list_standards()
            elif tool_name == "nft_outline":
                result = self.extractor.get_module_outline(args.get("module", ""))
                if not result:
                    result = {"error": f"Module '{args.get('module', '')}' not found",
                              "available": list(self.index.get("modules", {}).keys())}
            elif tool_name == "nft_build_index":
                from .indexer import build_index
                idx = build_index(MODULES_DIR)
                idx.save(INDEX_PATH)
                self.index = None  # Force reload
                self._ensure_loaded()
                result = {"status": "ok", "stats": self.index.get("stats", {})}
            elif tool_name == "nft_check_index":
                from .indexer import check_index_freshness
                from .schema import Index
                idx = Index.load(INDEX_PATH)
                fresh = check_index_freshness(idx, MODULES_DIR)
                result = {"fresh": fresh, "source_hash": idx.source_hash}
            else:
                return self._error(req_id, -32602, f"Unknown tool: {tool_name}")

            text = json.dumps(result, indent=2, ensure_ascii=False)
            return self._response(req_id, {
                "content": [{"type": "text", "text": text}],
            })
        except Exception as e:
            return self._tool_error(req_id, f"Error: {e}")

    def _tool_error(self, req_id: Any, message: str) -> Dict[str, Any]:
        """Return a tool error response per MCP spec."""
        return self._response(req_id, {
            "content": [{"type": "text", "text": message}],
            "isError": True,
        })

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
            except Exception as e:
                err = self._error(None, -32603, str(e))
                sys.stdout.write(json.dumps(err) + "\n")
                sys.stdout.flush()
