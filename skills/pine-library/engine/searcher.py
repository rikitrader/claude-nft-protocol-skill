"""Fuzzy search across all Pine Script community scripts (stdlib only)."""
from __future__ import annotations

from difflib import SequenceMatcher
from typing import Any, Dict, List, Optional


def _score(query: str, text: str) -> float:
    """Score how well query matches text (0.0 to 1.0)."""
    q = query.lower()
    t = text.lower()
    if not q or not t:
        return 0.0
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


class Searcher:
    """Search across all indexed Pine Script community scripts."""

    def __init__(self, index_data: Dict[str, Any]):
        self.index = index_data

    def search(
        self,
        query: str,
        script_type: Optional[str] = None,
        tag: Optional[str] = None,
        author: Optional[str] = None,
        limit: int = 10,
    ) -> List[Dict[str, Any]]:
        """Fuzzy search across scripts.

        Args:
            query: Search query string.
            script_type: Filter by "indicator", "strategy", or "library".
            tag: Filter by tag.
            author: Filter by author name.
            limit: Maximum results to return.
        """
        scripts = self.index.get("scripts", {})
        results: List[Dict[str, Any]] = []

        for sid, s in scripts.items():
            # Apply filters
            if script_type and s.get("script_type") != script_type:
                continue
            if tag and tag.lower() not in [t.lower() for t in s.get("tags", [])]:
                continue
            if author and s.get("author", "").lower() != author.lower():
                continue

            # Score against multiple fields
            best = 0.0
            for field in ("title", "author", "script_type"):
                val = s.get(field, "")
                if isinstance(val, str):
                    sc = _score(query, val)
                    if sc > best:
                        best = sc

            # Score against tags
            tags_str = " ".join(s.get("tags", []))
            tag_score = _score(query, tags_str)
            if tag_score > best:
                best = tag_score

            # Score against keywords
            kw_str = " ".join(s.get("keywords", []))
            kw_score = _score(query, kw_str)
            if kw_score > best:
                best = kw_score

            # Score against ID
            id_score = _score(query, sid)
            if id_score > best:
                best = id_score

            MIN_RELEVANCE = 0.3
            if best > MIN_RELEVANCE:
                results.append({
                    "id": sid,
                    "score": round(best, 3),
                    "title": s.get("title", ""),
                    "author": s.get("author", ""),
                    "script_type": s.get("script_type", ""),
                    "tags": s.get("tags", [])[:5],
                    "boosts": s.get("boosts", 0),
                    "has_source": s.get("has_source", True),
                })

        results.sort(key=lambda r: (r["score"], r.get("boosts", 0)), reverse=True)
        return results[:limit]

    def suggest(self, query: str, limit: int = 5) -> List[str]:
        """Suggest similar script IDs/titles for typo correction."""
        scripts = self.index.get("scripts", {})
        candidates: List[tuple[str, float]] = []

        for sid, s in scripts.items():
            best = max(
                _score(query, sid),
                _score(query, s.get("title", "")),
                _score(query, s.get("author", "")),
            )
            candidates.append((sid, best))

        # Also check tags
        tags = self.index.get("tags", {})
        for tag in tags:
            sc = _score(query, tag)
            candidates.append((f"tag:{tag}", sc))

        candidates.sort(key=lambda x: x[1], reverse=True)
        return [c[0] for c in candidates[:limit]]
