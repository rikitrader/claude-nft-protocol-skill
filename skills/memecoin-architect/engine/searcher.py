"""Fuzzy search across all indexed entries (stdlib only, no external deps)."""
from __future__ import annotations

from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional


def _score(query: str, text: str) -> float:
    """Score how well query matches text (0.0 to 1.0)."""
    q = query.lower()
    t = text.lower()
    # Exact substring match gets highest score
    if q in t:
        return 0.9 + (len(q) / max(len(t), 1)) * 0.1
    # Word-level match
    q_words = set(q.split())
    t_words = set(t.split())
    if q_words and q_words.issubset(t_words):
        return 0.8
    # Partial word matches
    matched = sum(1 for w in q_words if any(w in tw for tw in t_words))
    if matched > 0:
        return 0.5 + (matched / max(len(q_words), 1)) * 0.3
    # Sequence similarity fallback
    return SequenceMatcher(None, q, t).ratio() * 0.5


def _search_dict(
    entries: Dict[str, Any],
    query: str,
    searchable_fields: List[str],
    entry_type: str,
) -> List[Dict[str, Any]]:
    """Search a dictionary of entries by scoring against multiple fields."""
    results = []
    for entry_id, entry in entries.items():
        best = 0.0
        for field in searchable_fields:
            val = entry.get(field, "")
            if isinstance(val, list):
                val = " ".join(str(v) for v in val)
            elif not isinstance(val, str):
                val = str(val)
            s = _score(query, val)
            if s > best:
                best = s
        # Also score against the entry ID itself
        id_score = _score(query, entry_id)
        if id_score > best:
            best = id_score
        MIN_RELEVANCE_SCORE = 0.3
        if best > MIN_RELEVANCE_SCORE:
            results.append({
                "id": entry_id,
                "type": entry_type,
                "score": round(best, 3),
                "title": entry.get("title", entry.get("name", entry_id)),
                "source_file": entry.get("source_file", ""),
                "summary": entry.get("summary", entry.get("description", "")),
            })
    return results


class Searcher:
    """Search across all indexed content types."""

    def __init__(self, index_data: Dict[str, Any]):
        self.index = index_data

    def search(
        self,
        query: str,
        category: Optional[str] = None,
        limit: int = 10,
    ) -> List[Dict[str, Any]]:
        """Fuzzy search across all or specific entry types."""
        all_results: List[Dict[str, Any]] = []

        if category is None or category == "sections":
            all_results.extend(_search_dict(
                self.index.get("sections", {}), query,
                ["title", "summary", "category"], "section",
            ))
        if category is None or category == "templates":
            all_results.extend(_search_dict(
                self.index.get("templates", {}), query,
                ["name", "component_type", "route_group", "exports"], "template",
            ))
        if category is None or category == "contracts":
            all_results.extend(_search_dict(
                self.index.get("contracts", {}), query,
                ["name", "program_name", "instructions", "accounts", "events"], "contract",
            ))
        if category is None or category == "scripts":
            all_results.extend(_search_dict(
                self.index.get("scripts", {}), query,
                ["name", "script_type", "description"], "script",
            ))

        all_results.sort(key=lambda r: r["score"], reverse=True)
        return all_results[:limit]

    def list_category(self, category: str) -> List[Dict[str, Any]]:
        """List all entries in a category."""
        entries = self.index.get(category, {})
        results = []
        for entry_id, entry in entries.items():
            results.append({
                "id": entry_id,
                "type": category.rstrip("s"),  # "templates" -> "template"
                "title": entry.get("title", entry.get("name", entry_id)),
                "source_file": entry.get("source_file", ""),
            })
        results.sort(key=lambda r: r["id"])
        return results

    def find_by_route(self, route_group: str) -> List[Dict[str, Any]]:
        """Find all templates in a specific route group."""
        results = []
        for entry_id, entry in self.index.get("templates", {}).items():
            rg = entry.get("route_group", "")
            if rg and route_group in rg:
                results.append({
                    "id": entry_id,
                    "name": entry.get("name", ""),
                    "component_type": entry.get("component_type", ""),
                    "source_file": entry.get("source_file", ""),
                })
        results.sort(key=lambda r: r["id"])
        return results

    def find_by_tag(self, tag: str) -> List[Dict[str, Any]]:
        """Find entries matching a tag across all categories."""
        return self.search(tag, category=None, limit=20)
