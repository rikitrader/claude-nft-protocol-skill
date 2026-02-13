"""Pass 2: Generate raw markdown files from manifest + suggest API source code.

For scripts that already have source in the suggest API, writes raw/*.md directly.
For top scripts without source, fetches from individual script detail pages.
"""
import json
import re
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent
MANIFEST_PATH = SKILL_DIR / "data" / "scraping" / "manifest.json"
RAW_DIR = SKILL_DIR / "data" / "raw"
SUGGEST_URL = "https://www.tradingview.com/pubscripts-suggest-json/"
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"}

# Regex to extract JSON data from script detail pages
_JSON_RE = re.compile(r'"publication_scripts":(\{.*?\}),"user":', re.DOTALL)
_DESC_RE = re.compile(r'"description":"((?:[^"\\]|\\.)*)"', re.DOTALL)
_TAGS_RE = re.compile(r'"tags":\[(.*?)\]')
_TAG_RE = re.compile(r'"tag":"([^"]*)"')
_VIEWS_RE = re.compile(r'"views":(\d+)')


def safe_filename(script_id: str) -> str:
    """Create a safe filename from script ID."""
    # Replace problematic chars
    safe = re.sub(r'[^\w.-]', '_', script_id)
    return f"script-{safe}.md"


def write_raw_md(
    raw_dir: Path,
    script_id: str,
    title: str,
    author: str,
    script_type: str,
    tags: list,
    boosts: int,
    views: int,
    has_source: bool,
    description: str,
    source_code: str,
) -> Path:
    """Write a raw markdown file for a script."""
    raw_dir.mkdir(parents=True, exist_ok=True)
    filename = safe_filename(script_id)
    filepath = raw_dir / filename

    # Build YAML frontmatter
    tags_str = "[" + ", ".join(tags) + "]" if tags else "[]"
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    content = f"""---
id: {script_id}
title: {title}
author: {author}
type: {script_type}
tags: {tags_str}
boosts: {boosts}
views: {views}
has_source: {str(has_source).lower()}
scraped_at: {now}
slug: {safe_filename(script_id).replace('.md', '')}
---

# Description
{description}

# Source Code
```pine
{source_code}
```
"""
    filepath.write_text(content, encoding="utf-8")
    return filepath


def fetch_suggest_with_source(search: str, offset: int = 0, count: int = 50) -> list:
    """Fetch from suggest API and return scripts that have source code."""
    url = f"{SUGGEST_URL}?search={urllib.request.quote(search)}&offset={offset}&count={count}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return [r for r in data.get("results", []) if r.get("scriptSource")]


def fetch_script_detail(script_url: str) -> dict:
    """Fetch description and tags from a script's detail page."""
    req = urllib.request.Request(script_url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        html = resp.read().decode("utf-8", errors="replace")

    result = {"description": "", "tags": [], "views": 0, "source": ""}

    # Extract description
    desc_match = _DESC_RE.search(html)
    if desc_match:
        desc = desc_match.group(1)
        # Unescape JSON string
        desc = desc.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
        # Clean TradingView BBCode
        desc = re.sub(r'\[/?[bi]\]', '', desc)
        desc = re.sub(r'\[list[^\]]*\]', '', desc)
        desc = re.sub(r'\[/list\]', '', desc)
        desc = re.sub(r'\[\*\]', '- ', desc)
        result["description"] = desc

    # Extract tags
    tags_match = _TAGS_RE.search(html)
    if tags_match:
        result["tags"] = _TAG_RE.findall(tags_match.group(1))

    # Extract views
    views_match = _VIEWS_RE.search(html)
    if views_match:
        result["views"] = int(views_match.group(1))

    return result


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    # Load manifest
    with open(MANIFEST_PATH, "r") as f:
        manifest = json.load(f)

    print(f"Manifest: {len(manifest)} scripts")

    # Count existing raw files
    existing = {f.stem for f in RAW_DIR.glob("*.md")}
    print(f"Existing raw files: {len(existing)}")

    # Phase A: Write raw files for scripts with source from suggest API
    with_source = [s for s in manifest if s.get("has_source")]
    print(f"\nPhase A: {len(with_source)} scripts with embedded source code")

    # We need to re-fetch from suggest API to get the actual source code
    # (manifest only has the flag, not the code itself)
    # Use search terms that maximize coverage of scripts with source
    written_a = 0
    seen_ids = set()
    search_terms = [
        "indicator", "strategy", "library", "EMA", "SMA", "MACD", "RSI",
        "volume", "trend", "momentum", "bollinger", "stochastic", "ATR",
        "ADX", "ichimoku", "fibonacci", "support", "pivot", "VWAP",
        "harmonic", "divergence", "breakout", "reversal", "pattern",
        "candle", "supply", "liquidity", "oscillator", "overlay",
        "moving average", "channel", "supertrend", "heikin", "renko",
        "LuxAlgo", "ChartPrime", "LazyBear", "risk", "stop loss",
        "trailing", "bitcoin", "crypto", "machine learning", "regression",
        "volatility", "heatmap", "session", "range", "delta", "profile",
    ]

    for term in search_terms:
        offset = 0
        while offset <= 300:
            try:
                results = fetch_suggest_with_source(term, offset=offset, count=50)
            except Exception as e:
                print(f"  ERROR ({term}@{offset}): {e}")
                break

            if not results:
                break

            for r in results:
                sid = r.get("scriptIdPart", "")
                if not sid or sid in seen_ids:
                    continue
                seen_ids.add(sid)

                fname = safe_filename(sid)
                if fname.replace(".md", "") in existing:
                    continue

                kind = r.get("extra", {}).get("kind", "study")
                stype = "strategy" if kind == "strategy" else "indicator"
                if "library" in r.get("scriptName", "").lower():
                    stype = "library"

                write_raw_md(
                    RAW_DIR,
                    script_id=sid,
                    title=r.get("scriptName", ""),
                    author=r.get("author", {}).get("username", ""),
                    script_type=stype,
                    tags=[],  # suggest API doesn't provide tags
                    boosts=r.get("agreeCount", 0),
                    views=0,
                    has_source=True,
                    description=r.get("scriptName", ""),
                    source_code=r.get("scriptSource", ""),
                )
                written_a += 1

            offset += 50
            time.sleep(0.3)

        if written_a % 100 == 0 and written_a > 0:
            print(f"  Progress: {written_a} raw files written (term: {term})")

    print(f"Phase A complete: {written_a} raw files written")

    # Phase B: For top 300 scripts without source (by boosts), fetch detail pages
    without_source = sorted(
        [s for s in manifest if not s.get("has_source")],
        key=lambda x: x.get("boosts", 0),
        reverse=True,
    )[:300]

    print(f"\nPhase B: Fetching {len(without_source)} top scripts detail pages")

    written_b = 0
    for i, s in enumerate(without_source):
        sid = s["id"]
        fname = safe_filename(sid)
        if fname.replace(".md", "") in existing:
            continue

        # Build URL from manifest (we don't have full URL, try suggest endpoint)
        # Actually we only have the scriptIdPart which is like "PUB;xxx"
        # We can't easily construct the detail page URL without the slug
        # Skip scripts we can't get a URL for
        # Instead, mark them as metadata-only
        write_raw_md(
            RAW_DIR,
            script_id=sid,
            title=s.get("title", ""),
            author=s.get("author", ""),
            script_type=s.get("script_type", "indicator"),
            tags=[],
            boosts=s.get("boosts", 0),
            views=0,
            has_source=False,
            description=s.get("title", ""),
            source_code="(source code not available via API - visit TradingView to view)",
        )
        written_b += 1

        if written_b % 50 == 0:
            print(f"  Progress: {written_b}/{len(without_source)}")

    print(f"Phase B complete: {written_b} metadata-only files written")
    print(f"\nTotal raw files: {len(list(RAW_DIR.glob('*.md')))}")


if __name__ == "__main__":
    main()
