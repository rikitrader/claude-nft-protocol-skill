"""Pass 1: Collect unique script IDs via TradingView suggest API.

Uses multiple search terms across categories to maximize coverage.
Saves manifest.json with unique script entries.
"""
import json
import time
import urllib.request
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent
MANIFEST_PATH = SKILL_DIR / "data" / "scraping" / "manifest.json"
SUGGEST_URL = "https://www.tradingview.com/pubscripts-suggest-json/"
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"}

# Broad search terms to maximize coverage across different indicator types
SEARCH_TERMS = [
    # Technical indicators
    "indicator", "strategy", "library",
    "EMA", "SMA", "MACD", "RSI", "volume", "trend", "momentum",
    "bollinger", "stochastic", "ATR", "ADX", "ichimoku", "fibonacci",
    "support", "resistance", "pivot", "VWAP", "OBV",
    # Patterns & analysis
    "harmonic", "divergence", "breakout", "reversal", "pattern",
    "candle", "candlestick", "supply", "demand", "order block",
    "fair value gap", "liquidity", "market structure",
    # Oscillators & overlays
    "oscillator", "overlay", "moving average", "channel",
    "supertrend", "heikin", "renko", "keltner", "donchian",
    # Authors (top publishers)
    "LuxAlgo", "ChartPrime", "LazyBear", "QuantNomad", "TradingView",
    "Trendoscope", "LonesomeTheBlue", "RicardoSantos", "everget",
    "PineCoders", "HPotter", "ZenAndTheArtOfTrading", "allanster",
    # Risk & money management
    "risk", "stop loss", "take profit", "trailing",
    "position size", "drawdown", "equity",
    # Crypto-specific
    "bitcoin", "crypto", "funding rate", "open interest",
    # Advanced concepts
    "machine learning", "neural", "regression", "correlation",
    "volatility", "standard deviation", "zscore", "heatmap",
    "profile", "footprint", "delta", "cumulative",
    "session", "market hours", "range",
    # Single letters to get alphabetically diverse results
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
]
MAX_OFFSET = 300  # Don't paginate beyond this per term


def fetch_suggest(search: str, offset: int = 0, count: int = 50) -> dict:
    url = f"{SUGGEST_URL}?search={urllib.request.quote(search)}&offset={offset}&count={count}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Load existing manifest for resume support
    all_scripts: dict[str, dict] = {}
    if MANIFEST_PATH.exists():
        with open(MANIFEST_PATH, "r") as f:
            existing = json.load(f)
        for s in existing:
            all_scripts[s["id"]] = s
        print(f"Loaded {len(all_scripts)} existing scripts from manifest")

    for term in SEARCH_TERMS:
        offset = 0
        term_new = 0
        while offset <= MAX_OFFSET:
            try:
                data = fetch_suggest(term, offset=offset, count=50)
            except Exception as e:
                print(f"  ERROR at offset {offset}: {e}")
                break

            results = data.get("results", [])
            if not results:
                break

            for r in results:
                sid = r.get("scriptIdPart", "")
                if not sid or sid in all_scripts:
                    continue
                kind = r.get("extra", {}).get("kind", "study")
                script_type = "strategy" if kind == "strategy" else "indicator"
                if "library" in r.get("scriptName", "").lower():
                    script_type = "library"

                all_scripts[sid] = {
                    "id": sid,
                    "title": r.get("scriptName", ""),
                    "short_title": r.get("shortTitle", ""),
                    "author": r.get("author", {}).get("username", ""),
                    "author_id": r.get("author", {}).get("id", 0),
                    "script_type": script_type,
                    "boosts": r.get("agreeCount", 0),
                    "has_source": bool(r.get("scriptSource")),
                    "source_len": len(r.get("scriptSource", "")),
                    "image_url": r.get("imageUrl", ""),
                }
                term_new += 1

            if not data.get("next"):
                break
            offset += 50
            time.sleep(0.3)

        print(f"'{term}': +{term_new} new, total: {len(all_scripts)}")
        time.sleep(0.5)

        # Save periodically
        if len(all_scripts) % 200 < 50:
            manifest = sorted(all_scripts.values(), key=lambda s: s["id"])
            with open(MANIFEST_PATH, "w") as f:
                json.dump(manifest, f, indent=2)

    # Final save
    manifest = sorted(all_scripts.values(), key=lambda s: s["id"])
    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nFinal: {len(manifest)} unique scripts saved to {MANIFEST_PATH}")

    # Stats
    with_source = sum(1 for s in manifest if s.get("has_source"))
    print(f"With source code: {with_source}")
    print(f"Without source code: {len(manifest) - with_source}")
    types = {}
    for s in manifest:
        t = s.get("script_type", "unknown")
        types[t] = types.get(t, 0) + 1
    for t, c in sorted(types.items()):
        print(f"  {t}: {c}")


if __name__ == "__main__":
    main()
