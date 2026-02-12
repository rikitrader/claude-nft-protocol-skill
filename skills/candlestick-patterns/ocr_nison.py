#!/usr/bin/env python3
"""Batch OCR Steve Nison's Japanese Candlestick Charting Techniques.

Renders PDF pages as PNG, runs tesseract OCR, outputs markdown by chapter.
Uses home directory for temp files (sandbox restricts /tmp for tesseract).
"""
import os
import subprocess
import sys
from pathlib import Path

PDF_PATH = "/Users/ricardoprieto/Desktop/CandleStick/Steve-Nison-Japanese-Candlestick-Charting-Techniques-Prentice-Hall-Press-2001.pdf"
WORK_DIR = Path.home() / "nison_ocr_work"
OUTPUT_DIR = Path(__file__).parent / "data" / "raw"

# Chapter ranges (PDF page numbers, 1-indexed)
# Note: PDF pages include front matter, so actual book page 1 = PDF ~page 15
CHAPTERS = {
    "ch01-introduction": (15, 28),          # Ch 1: Introduction (p1-14)
    "ch02-historical-background": (29, 34), # Ch 2: Historical Background (p15-20)
    "ch03-constructing-lines": (35, 44),    # Ch 3: Constructing Candlestick Lines (p21-30)
    "ch04-reversal-patterns": (45, 74),     # Ch 4: Reversal Patterns (p31-60)
    "ch05-stars": (75, 94),                 # Ch 5: Stars (p61-80)
    "ch06-more-reversal": (95, 138),        # Ch 6: More Reversal Patterns (p81-124)
    "ch07-continuation": (139, 168),        # Ch 7: Continuation Patterns (p125-154)
    "ch08-doji": (169, 186),                # Ch 8: The Magic Doji (p155-172)
    "ch09-putting-together": (187, 196),    # Ch 9: Putting It All Together (p173-180)
    "ch10-cluster-candles": (197, 206),     # Ch 10: A Cluster of Candles (p181-192)
    "ch11-candles-trendlines": (207, 226),  # Ch 11: Candles with Trend Lines (p193-212)
    "ch12-candles-retracement": (227, 230), # Ch 12: Candles with Retracement (p213-216)
    "ch13-candles-moving-avg": (231, 238),  # Ch 13: Candles with Moving Averages (p217-224)
    "ch14-candles-oscillators": (239, 254), # Ch 14: Candles with Oscillators (p225-240)
    "ch15-candles-volume": (255, 262),      # Ch 15: Candles with Volume (p241-248)
    "ch16-measured-moves": (263, 276),      # Ch 16: Measured Moves (p249-262)
    "ch17-east-west": (277, 282),           # Ch 17: Best of East and West (p263-268)
    "glossary-a-candlestick": (283, 292),   # Glossary A: Candlestick Terms (p269-278)
    "glossary-b-western": (293, 298),       # Glossary B: Western Terms (p279-end)
}


def render_pages(start: int, end: int) -> list[Path]:
    """Render PDF pages as PNG images."""
    WORK_DIR.mkdir(exist_ok=True)
    prefix = WORK_DIR / "page"
    subprocess.run(
        [
            "pdftoppm", "-png", "-r", "300",
            "-f", str(start), "-l", str(end),
            PDF_PATH, str(prefix),
        ],
        check=True,
        env={**os.environ, "PATH": f"/opt/homebrew/bin:{os.environ.get('PATH', '')}"},
    )
    pages = sorted(WORK_DIR.glob("page-*.png"))
    return pages


def ocr_page(png_path: Path) -> str:
    """Run tesseract OCR on a single page image."""
    out_base = png_path.with_suffix("")
    subprocess.run(
        ["tesseract", str(png_path), str(out_base), "--psm", "6"],
        check=True,
        capture_output=True,
    )
    txt_path = out_base.with_suffix(".txt")
    text = txt_path.read_text(encoding="utf-8", errors="replace")
    # Cleanup temp files
    txt_path.unlink(missing_ok=True)
    png_path.unlink(missing_ok=True)
    return text


def clean_ocr_text(text: str) -> str:
    """Fix common OCR errors."""
    # Fix common substitutions
    text = text.replace("\u2019", "'")  # smart quotes
    text = text.replace("\u201c", '"').replace("\u201d", '"')
    text = text.replace("\u2014", "---")
    text = text.replace("\u2013", "--")
    # Remove excessive blank lines
    import re
    text = re.sub(r"\n{4,}", "\n\n\n", text)
    return text.strip()


def process_chapter(name: str, start: int, end: int) -> str:
    """Render and OCR a chapter range, return combined markdown."""
    print(f"  Rendering pages {start}-{end}...")
    pages = render_pages(start, end)
    print(f"  OCR-ing {len(pages)} pages...")

    texts = []
    for p in pages:
        t = ocr_page(p)
        t = clean_ocr_text(t)
        if t:
            texts.append(t)

    return "\n\n---\n\n".join(texts)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    WORK_DIR.mkdir(exist_ok=True)

    total_chapters = len(CHAPTERS)
    for i, (name, (start, end)) in enumerate(CHAPTERS.items(), 1):
        outfile = OUTPUT_DIR / f"nison_{name}.md"
        if outfile.exists() and outfile.stat().st_size > 500:
            print(f"[{i}/{total_chapters}] {name}: already exists, skipping")
            continue

        print(f"[{i}/{total_chapters}] Processing {name} (pages {start}-{end})...")
        content = process_chapter(name, start, end)

        # Write markdown with header
        chapter_title = name.replace("-", " ").replace("ch", "Chapter ").title()
        md = f"<!-- source: Steve Nison - Japanese Candlestick Charting Techniques, 2nd Ed -->\n"
        md += f"<!-- chapter: {name} | pages: {start}-{end} -->\n\n"
        md += f"# {chapter_title}\n\n"
        md += content + "\n"

        outfile.write_text(md, encoding="utf-8")
        size = outfile.stat().st_size
        print(f"  -> {outfile.name} ({size:,} bytes)")

    # Cleanup work directory
    import shutil
    if WORK_DIR.exists():
        shutil.rmtree(WORK_DIR, ignore_errors=True)

    print(f"\nDone! {total_chapters} chapters written to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
