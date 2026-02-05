"""Search and discovery across the NFT Protocol index."""
from __future__ import annotations

import re
from typing import Any, Dict, List


class Searcher:
    """Full-text and fuzzy search over the index."""

    def __init__(self, index_data: Dict[str, Any]):
        self.index = index_data

    def search(self, query: str, search_type: str = "all") -> Dict[str, Any]:
        """Search contracts, sections, and standards."""
        q = query.lower().strip()
        results: Dict[str, Any] = {"query": query, "contracts": [], "sections": [], "standards": []}

        if search_type in ("all", "contract"):
            results["contracts"] = self._search_contracts(q)

        if search_type in ("all", "section"):
            results["sections"] = self._search_sections(q)

        if search_type in ("all", "standard"):
            results["standards"] = self._search_standards(q)

        results["total_results"] = (
            len(results["contracts"])
            + len(results["sections"])
            + len(results["standards"])
        )
        return results

    def _search_contracts(self, query: str) -> List[Dict[str, Any]]:
        matches = []
        # Require minimum 2-char query for substring matching to avoid noise
        min_len = len(query) >= 2
        for name, c in self.index.get("contracts", {}).items():
            score = self._score(query, name, c, min_len)
            if score > 0:
                matches.append({
                    "name": name,
                    "module_file": c["module_file"],
                    "section_id": c["section_id"],
                    "file_path": c.get("file_path"),
                    "standards": c.get("standards", []),
                    "score": score,
                })
        return sorted(matches, key=lambda x: x["score"], reverse=True)[:20]

    def _search_sections(self, query: str) -> List[Dict[str, Any]]:
        matches = []
        min_len = len(query) >= 2
        for sec_id, s in self.index.get("sections", {}).items():
            title_lower = s.get("title", "").lower()
            summary_lower = s.get("summary", "").lower()
            score = 0
            if query == title_lower:
                score += 20  # Exact match bonus
            elif min_len and query in title_lower:
                score += 10
            if min_len and query in summary_lower:
                score += 5
            if min_len and query in sec_id:
                score += 8
            # Fuzzy: check each query word (only words >= 2 chars)
            for word in query.split():
                if len(word) < 2:
                    continue
                if word in title_lower:
                    score += 3
                if word in summary_lower:
                    score += 1
            if score > 0:
                matches.append({
                    "id": sec_id,
                    "title": s["title"],
                    "module_file": s["module_file"],
                    "contracts": s.get("contracts", []),
                    "summary": s.get("summary", ""),
                    "score": score,
                })
        return sorted(matches, key=lambda x: x["score"], reverse=True)[:20]

    def _search_standards(self, query: str) -> List[Dict[str, Any]]:
        matches = []
        # Normalize query for standard matching
        q_upper = query.upper().replace("EIP-", "ERC-").replace("ERC", "ERC-")
        q_upper = re.sub(r"ERC--+", "ERC-", q_upper)

        for std, contract_names in self.index.get("standards", {}).items():
            if query in std.lower() or q_upper in std:
                matches.append({
                    "standard": std,
                    "contracts": contract_names,
                    "count": len(contract_names),
                })
        return sorted(matches, key=lambda x: x["count"], reverse=True)

    def _score(self, query: str, name: str, contract: Dict[str, Any],
               min_len: bool = True) -> int:
        score = 0
        name_lower = name.lower()
        if query == name_lower:
            score += 20  # Exact match always scores
        elif min_len and query in name_lower:
            score += 10
        # Check file path
        fp = (contract.get("file_path") or "").lower()
        if min_len and query in fp:
            score += 5
        # Check standards
        for std in contract.get("standards", []):
            if query in std.lower():
                score += 7
        # Check imports
        for imp in contract.get("imports", []):
            if min_len and query in imp.lower():
                score += 2
        # Fuzzy word match (only words >= 2 chars)
        for word in query.split():
            if len(word) < 2:
                continue
            if word in name_lower:
                score += 3
        return score

    def find_by_standard(self, standard: str) -> Dict[str, Any]:
        """Find all contracts implementing a given ERC standard."""
        # Normalize
        std = standard.upper().replace("EIP-", "ERC-").replace("ERC", "ERC-")
        std = re.sub(r"ERC--+", "ERC-", std)

        contracts = self.index.get("standards", {}).get(std, [])
        details = []
        for name in contracts:
            c = self.index.get("contracts", {}).get(name, {})
            if c:
                details.append({
                    "name": name,
                    "module_file": c["module_file"],
                    "section_id": c["section_id"],
                    "file_path": c.get("file_path"),
                    "all_standards": c.get("standards", []),
                })
        return {
            "standard": std,
            "count": len(details),
            "contracts": details,
        }

    def list_modules(self) -> List[Dict[str, Any]]:
        """List all modules with summaries."""
        result = []
        for name, m in self.index.get("modules", {}).items():
            result.append({
                "file_name": name,
                "title": m["title"],
                "description": m.get("description", ""),
                "size_bytes": m["size_bytes"],
                "line_count": m["line_count"],
                "section_count": len(m.get("sections", [])),
                "contract_count": len(m.get("contracts", [])),
                "standards": m.get("standards", []),
            })
        return sorted(result, key=lambda x: x["size_bytes"], reverse=True)

    def list_contracts(self) -> List[Dict[str, Any]]:
        """List all contracts with metadata."""
        result = []
        for name, c in self.index.get("contracts", {}).items():
            result.append({
                "name": name,
                "module_file": c["module_file"],
                "section_id": c["section_id"],
                "file_path": c.get("file_path"),
                "standards": c.get("standards", []),
            })
        return sorted(result, key=lambda x: x["name"])

    def list_standards(self) -> List[Dict[str, Any]]:
        """List all supported ERC standards."""
        result = []
        for std, contracts in self.index.get("standards", {}).items():
            result.append({
                "standard": std,
                "count": len(contracts),
                "contracts": contracts,
            })
        return sorted(result, key=lambda x: x["standard"])

    def suggest(self, partial: str) -> List[str]:
        """Autocomplete partial input against contract/section names."""
        p = partial.lower()
        suggestions = []
        for name in self.index.get("contracts", {}):
            if p in name.lower():
                suggestions.append(f"contract:{name}")
        for sec_id in self.index.get("sections", {}):
            if p in sec_id.lower():
                suggestions.append(f"section:{sec_id}")
        for std in self.index.get("standards", {}):
            if p in std.lower():
                suggestions.append(f"standard:{std}")
        return suggestions[:15]
