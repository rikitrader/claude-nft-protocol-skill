"""Crawl TradingView Pine Script v6 docs and cache as local markdown files.

Uses only stdlib (urllib + html.parser). No Selenium/Playwright required.
Falls back gracefully if pages are JS-rendered.
"""
from __future__ import annotations

import gzip
import hashlib
import io
import json
import re
import ssl
import time
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Dict, List, Optional, Tuple

BASE_URL = "https://www.tradingview.com/pine-script-docs"

# Complete sitemap of Pine Script v6 documentation
PAGES: List[str] = [
    # Welcome
    "/welcome",
    # Primer
    "/primer/first-steps",
    "/primer/first-indicator",
    "/primer/next-steps",
    # Language
    "/language/execution-model",
    "/language/type-system",
    "/language/script-structure",
    "/language/identifiers",
    "/language/variable-declarations",
    "/language/operators",
    "/language/conditional-structures",
    "/language/loops",
    "/language/built-ins",
    "/language/user-defined-functions",
    "/language/objects",
    "/language/enums",
    "/language/methods",
    "/language/arrays",
    "/language/matrices",
    "/language/maps",
    # Concepts
    "/concepts/alerts",
    "/concepts/bar-states",
    "/concepts/chart-information",
    "/concepts/inputs",
    "/concepts/libraries",
    "/concepts/non-standard-charts-data",
    "/concepts/other-timeframes-and-data",
    "/concepts/repainting",
    "/concepts/sessions",
    "/concepts/strategies",
    "/concepts/strings",
    "/concepts/time",
    "/concepts/timeframes",
    # Visuals
    "/visuals/overview",
    "/visuals/backgrounds",
    "/visuals/bar-coloring",
    "/visuals/bar-plotting",
    "/visuals/colors",
    "/visuals/fills",
    "/visuals/levels",
    "/visuals/lines-and-boxes",
    "/visuals/plots",
    "/visuals/tables",
    "/visuals/text-and-shapes",
    # Writing scripts
    "/writing-scripts/style-guide",
    "/writing-scripts/debugging",
    "/writing-scripts/profiling-and-optimization",
    "/writing-scripts/publishing-scripts",
    "/writing-scripts/limitations",
    # FAQ
    "/faq/faq",
    # Reference
    "/error-messages",
    "/release-notes",
    "/migration-guides",
]

# Pine Script Reference Manual — built-in functions
REFERENCE_BASE = "https://www.tradingview.com/pine-script-reference/v5"


class _HTMLToMarkdown(HTMLParser):
    """Convert HTML content from Pine Script docs to markdown.

    Extracts the main content area and converts common HTML elements
    to their markdown equivalents. Handles <pre><code> blocks as
    fenced code blocks with ```pine``` language tag.
    """

    def __init__(self) -> None:
        super().__init__()
        self._output: List[str] = []
        self._in_pre = False
        self._in_code = False
        self._in_table = False
        self._in_heading = 0  # 0=none, 1-6=h1-h6
        self._in_li = False
        self._in_a = False
        self._href = ""
        self._link_text = ""
        self._skip = False  # skip nav/footer elements
        self._skip_depth = 0
        self._in_main = False
        self._bold = False
        self._italic = False
        self._current_row: List[str] = []
        self._table_rows: List[List[str]] = []

    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]) -> None:
        attr_dict = dict(attrs)
        classes = attr_dict.get("class", "") or ""

        # Skip navigation, sidebar, footer elements
        if tag in ("nav", "footer", "aside"):
            self._skip = True
            self._skip_depth += 1
            return

        if self._skip:
            self._skip_depth += 1
            return

        # Detect main content area
        if tag in ("main", "article"):
            self._in_main = True

        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            level = int(tag[1])
            self._in_heading = level
            self._output.append("\n" + "#" * level + " ")

        elif tag == "pre":
            self._in_pre = True
            self._output.append("\n```pine\n")

        elif tag == "code":
            if not self._in_pre:
                self._in_code = True
                self._output.append("`")

        elif tag == "p":
            self._output.append("\n\n")

        elif tag == "br":
            self._output.append("\n")

        elif tag == "strong" or tag == "b":
            self._bold = True
            self._output.append("**")

        elif tag == "em" or tag == "i":
            self._italic = True
            self._output.append("*")

        elif tag == "a":
            self._in_a = True
            self._href = attr_dict.get("href", "")
            self._link_text = ""

        elif tag == "ul" or tag == "ol":
            self._output.append("\n")

        elif tag == "li":
            self._in_li = True
            self._output.append("- ")

        elif tag == "table":
            self._in_table = True
            self._table_rows = []

        elif tag == "tr":
            self._current_row = []

        elif tag in ("td", "th"):
            pass  # handled by data

        elif tag == "img":
            alt = attr_dict.get("alt", "image")
            src = attr_dict.get("src", "")
            self._output.append(f"![{alt}]({src})")

        elif tag == "blockquote":
            self._output.append("\n> ")

    def handle_endtag(self, tag: str) -> None:
        if tag in ("nav", "footer", "aside"):
            self._skip_depth -= 1
            if self._skip_depth <= 0:
                self._skip = False
                self._skip_depth = 0
            return

        if self._skip:
            self._skip_depth -= 1
            if self._skip_depth <= 0:
                self._skip = False
                self._skip_depth = 0
            return

        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._in_heading = 0
            self._output.append("\n")

        elif tag == "pre":
            self._in_pre = False
            self._output.append("\n```\n")

        elif tag == "code":
            if not self._in_pre:
                self._in_code = False
                self._output.append("`")

        elif tag == "strong" or tag == "b":
            self._bold = False
            self._output.append("**")

        elif tag == "em" or tag == "i":
            self._italic = False
            self._output.append("*")

        elif tag == "a":
            self._in_a = False
            if self._href and self._link_text:
                self._output.append(f"[{self._link_text}]({self._href})")
            elif self._link_text:
                self._output.append(self._link_text)
            self._href = ""
            self._link_text = ""

        elif tag == "li":
            self._in_li = False
            self._output.append("\n")

        elif tag in ("td", "th"):
            self._current_row.append("")  # placeholder

        elif tag == "tr":
            if self._current_row:
                self._table_rows.append(self._current_row)

        elif tag == "table":
            self._in_table = False
            if self._table_rows:
                self._output.append("\n")
                for i, row in enumerate(self._table_rows):
                    self._output.append("| " + " | ".join(row) + " |\n")
                    if i == 0:
                        self._output.append("| " + " | ".join("---" for _ in row) + " |\n")
                self._output.append("\n")

    def handle_data(self, data: str) -> None:
        if self._skip:
            return

        if self._in_a:
            self._link_text += data
            return

        if self._in_table and self._current_row is not None:
            text = data.strip()
            if text:
                if self._current_row:
                    self._current_row[-1] += text
                else:
                    self._current_row.append(text)
            return

        if self._in_pre:
            self._output.append(data)
        else:
            # Collapse whitespace outside pre blocks
            cleaned = re.sub(r"\s+", " ", data)
            if cleaned.strip():
                self._output.append(cleaned)

    def get_markdown(self) -> str:
        text = "".join(self._output)
        # Clean up excessive blank lines
        text = re.sub(r"\n{3,}", "\n\n", text)
        return text.strip()


def html_to_markdown(html: str) -> str:
    """Convert HTML string to markdown."""
    parser = _HTMLToMarkdown()
    parser.feed(html)
    return parser.get_markdown()


def _fetch_page(url: str, retries: int = 3, delay: float = 1.0) -> str:
    """Fetch a URL with retries and rate limiting."""
    ctx = ssl.create_default_context()
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
                raw = resp.read()
                # Handle gzip-compressed responses (TradingView CDN always gzips)
                encoding = resp.headers.get("Content-Encoding", "")
                if encoding == "gzip" or raw[:2] == b"\x1f\x8b":
                    raw = gzip.decompress(raw)
                # Try UTF-8 first, then fallback
                try:
                    return raw.decode("utf-8")
                except UnicodeDecodeError:
                    return raw.decode("latin-1")
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(delay * (attempt + 1))
            else:
                raise RuntimeError(f"Failed to fetch {url} after {retries} attempts: {e}") from e
    return ""  # unreachable


def scrape_page(page_path: str) -> str:
    """Fetch a single Pine Script docs page and return markdown."""
    url = f"{BASE_URL}{page_path}"
    html = _fetch_page(url)

    if not html or len(html) < 500:
        return f"# {page_path}\n\n*Page could not be fetched (JS-rendered or empty).*\n"

    md = html_to_markdown(html)

    if not md or len(md) < 100:
        return f"# {page_path}\n\n*Content extraction failed — page may be JS-rendered.*\n"

    # Add source metadata header
    header = f"<!-- source: {url} -->\n<!-- scraped: pine-script-docs v6 -->\n\n"
    return header + md


def scrape_all(
    output_dir: Path,
    force: bool = False,
    delay: float = 1.5,
    verbose: bool = True,
) -> Dict[str, str]:
    """Crawl all Pine Script doc pages and save as markdown files.

    Args:
        output_dir: Directory to save .md files.
        force: Re-scrape even if file exists.
        delay: Seconds between requests (rate limiting).
        verbose: Print progress to stderr.

    Returns:
        Dict mapping page path to output file path.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest: Dict[str, str] = {}
    total = len(PAGES)

    for i, page_path in enumerate(PAGES, 1):
        slug = page_path.strip("/").replace("/", "_")
        out_file = output_dir / f"{slug}.md"

        if out_file.exists() and not force:
            manifest[page_path] = str(out_file)
            if verbose:
                import sys
                print(f"  [{i}/{total}] SKIP (cached): {page_path}", file=sys.stderr)
            continue

        if verbose:
            import sys
            print(f"  [{i}/{total}] Fetching: {page_path}", file=sys.stderr)

        try:
            content = scrape_page(page_path)
            out_file.write_text(content, encoding="utf-8")
            manifest[page_path] = str(out_file)
        except Exception as e:
            if verbose:
                import sys
                print(f"    ERROR: {e}", file=sys.stderr)
            # Write error placeholder so we don't retry on next run
            out_file.write_text(
                f"# {page_path}\n\n*Scrape error: {e}*\n", encoding="utf-8"
            )
            manifest[page_path] = str(out_file)

        # Rate limiting
        if i < total:
            time.sleep(delay)

    # Save manifest
    manifest_path = output_dir / "_manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    return manifest


def compute_source_hash(raw_dir: Path) -> str:
    """Compute a SHA256 hash of all markdown files in raw_dir for freshness check."""
    h = hashlib.sha256()
    for md_file in sorted(raw_dir.glob("*.md")):
        h.update(md_file.read_bytes())
    return h.hexdigest()[:16]


def import_local_files(
    source_dir: Path,
    output_dir: Path,
    verbose: bool = True,
) -> Dict[str, str]:
    """Import already-downloaded Pine Script docs from a local directory.

    Use this when docs were downloaded via browser or other means.
    Supports .html and .md files.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest: Dict[str, str] = {}

    for src_file in sorted(source_dir.iterdir()):
        if src_file.suffix == ".html":
            html = src_file.read_text(encoding="utf-8")
            md = html_to_markdown(html)
            out_file = output_dir / f"{src_file.stem}.md"
            out_file.write_text(md, encoding="utf-8")
            manifest[src_file.stem] = str(out_file)
        elif src_file.suffix == ".md":
            out_file = output_dir / src_file.name
            if src_file != out_file:
                out_file.write_text(src_file.read_text(encoding="utf-8"), encoding="utf-8")
            manifest[src_file.stem] = str(out_file)

        if verbose:
            import sys
            print(f"  Imported: {src_file.name}", file=sys.stderr)

    return manifest
