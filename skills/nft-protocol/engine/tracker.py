"""Token usage tracking and cost reporting."""
from __future__ import annotations

import fcntl
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional


class TokenTracker:
    """Append-only JSONL logger for token savings (thread-safe via flock)."""

    def __init__(self, log_path: Path):
        self.log_path = log_path
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log(self, operation: str, tokens_used: int, tokens_saved: int,
            details: Optional[Dict[str, Any]] = None) -> None:
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "op": operation,
            "used": tokens_used,
            "saved": tokens_saved,
            "details": details or {},
        }
        with open(self.log_path, "a", encoding="utf-8") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            try:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    def report(self) -> Dict[str, Any]:
        """Generate cumulative usage report."""
        if not self.log_path.exists():
            return {"total_operations": 0, "total_tokens_used": 0,
                    "total_tokens_saved": 0, "reduction_pct": 0}

        total_used = 0
        total_saved = 0
        ops: Dict[str, int] = {}

        with open(self.log_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                entry = json.loads(line)
                total_used += entry.get("used", 0)
                total_saved += entry.get("saved", 0)
                op = entry.get("op", "unknown")
                ops[op] = ops.get(op, 0) + 1

        baseline = total_used + total_saved
        pct = round((total_saved / max(baseline, 1)) * 100, 1)

        return {
            "total_operations": sum(ops.values()),
            "operations_by_type": ops,
            "total_tokens_used": total_used,
            "total_tokens_saved": total_saved,
            "baseline_tokens": baseline,
            "reduction_pct": pct,
        }


def estimate_tokens(text: str) -> int:
    """Rough token estimate: ~4 chars per token for English/code."""
    return len(text.encode("utf-8")) // 4
