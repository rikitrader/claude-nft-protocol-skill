"""Fuzzy search across all candlestick indexed entries (stdlib only)."""
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
        for field_name in searchable_fields:
            val = entry.get(field_name, "")
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
        MIN_RELEVANCE = 0.3
        if best > MIN_RELEVANCE:
            results.append({
                "id": entry_id,
                "type": entry_type,
                "score": round(best, 3),
                "title": entry.get("title", entry.get("name", entry_id)),
                "source_file": entry.get("source_file", ""),
                "summary": entry.get("summary", entry.get("description", ""))[:200],
            })
    return results


class Searcher:
    """Search across all candlestick indexed content."""

    def __init__(self, index_data: Dict[str, Any]):
        self.index = index_data

    def search(
        self,
        query: str,
        category: Optional[str] = None,
        limit: int = 10,
    ) -> List[Dict[str, Any]]:
        """Fuzzy search across all or specific entry types.

        Args:
            query: Search query string.
            category: Restrict to "sections", "patterns", "strategies", "examples",
                      or None for all.
            limit: Maximum results to return.
        """
        all_results: List[Dict[str, Any]] = []

        if category is None or category == "sections":
            all_results.extend(_search_dict(
                self.index.get("sections", {}), query,
                ["title", "summary", "category", "keywords"], "section",
            ))
        if category is None or category == "patterns":
            all_results.extend(_search_dict(
                self.index.get("patterns", {}), query,
                ["name", "japanese_name", "description", "signal",
                 "pattern_type", "category", "see_also"], "pattern",
            ))
        if category is None or category == "strategies":
            all_results.extend(_search_dict(
                self.index.get("strategies", {}), query,
                ["name", "description", "patterns_used", "indicators"], "strategy",
            ))
        if category is None or category == "examples":
            all_results.extend(_search_dict(
                self.index.get("examples", {}), query,
                ["section_id", "description"], "example",
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
                "type": category.rstrip("s"),
                "title": entry.get("title", entry.get("name", entry_id)),
                "source_file": entry.get("source_file", ""),
            })
        results.sort(key=lambda r: r["id"])
        return results

    def list_signals(self) -> List[Dict[str, Any]]:
        """List pattern counts grouped by signal (bullish/bearish/neutral)."""
        patterns = self.index.get("patterns", {})
        signal_counts: Dict[str, int] = {}
        for pat in patterns.values():
            sig = pat.get("signal", "unknown")
            signal_counts[sig] = signal_counts.get(sig, 0) + 1
        return [
            {"signal": sig, "count": count}
            for sig, count in sorted(signal_counts.items())
        ]

    def find_by_signal(self, signal: str) -> List[Dict[str, Any]]:
        """Find all patterns with a specific signal."""
        patterns = self.index.get("patterns", {})
        results = []
        for pat_id, pat in patterns.items():
            if pat.get("signal", "") == signal:
                results.append({
                    "id": pat_id,
                    "name": pat["name"],
                    "pattern_type": pat.get("pattern_type", ""),
                    "candle_count": pat.get("candle_count", 1),
                    "reliability": pat.get("reliability", ""),
                    "description": pat.get("description", "")[:100],
                })
        results.sort(key=lambda r: r["name"])
        return results

    def find_by_pattern_type(self, pattern_type: str) -> List[Dict[str, Any]]:
        """Find all patterns of a specific type (reversal/continuation/indecision)."""
        patterns = self.index.get("patterns", {})
        results = []
        for pat_id, pat in patterns.items():
            if pat.get("pattern_type", "") == pattern_type:
                results.append({
                    "id": pat_id,
                    "name": pat["name"],
                    "signal": pat.get("signal", ""),
                    "candle_count": pat.get("candle_count", 1),
                    "reliability": pat.get("reliability", ""),
                })
        results.sort(key=lambda r: r["name"])
        return results

    def find_by_category(self, category: str) -> List[Dict[str, Any]]:
        """Find all sections in a specific doc category."""
        sections = self.index.get("sections", {})
        results = []
        for sec_id, sec in sections.items():
            if sec.get("category", "") == category:
                results.append({
                    "id": sec_id,
                    "title": sec["title"],
                    "level": sec.get("level", 1),
                    "code_blocks": sec.get("code_blocks", 0),
                })
        results.sort(key=lambda r: r["id"])
        return results

    def suggest(self, query: str, limit: int = 5) -> List[str]:
        """Suggest similar entry IDs for typo correction."""
        all_ids: List[str] = []
        for cat in ("sections", "patterns", "strategies", "examples"):
            all_ids.extend(self.index.get(cat, {}).keys())
        scored = [(eid, _score(query, eid)) for eid in all_ids]
        scored.sort(key=lambda x: x[1], reverse=True)
        return [eid for eid, _ in scored[:limit]]
