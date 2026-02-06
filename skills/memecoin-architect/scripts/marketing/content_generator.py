#!/usr/bin/env python3
# =============================================================================
# NARRATIVE FORGE — Content Generator
# =============================================================================
# Parses MEMECOIN_BRIEF.md and populates all marketing templates from
# templates/narrative_forge/ into the output directory.
#
# Templates use {VARIABLE} placeholders that map to brief fields.
# Unknown variables are left as-is for manual replacement.
#
# Usage:
#   python content_generator.py --brief MEMECOIN_BRIEF.md --output ./marketing
#   python content_generator.py  # uses defaults
# =============================================================================

import argparse
import os
import re
import sys
from pathlib import Path

# =============================================================================
# BRIEF PARSER
# =============================================================================

# Regex patterns for extracting fields from MEMECOIN_BRIEF.md
FIELD_PATTERNS = {
    "TOKEN_NAME":       r"(?:Name|Token Name):\s*(.*)",
    "TICKER":           r"(?:Ticker|Symbol):\s*(.*)",
    "NARRATIVE":        r"(?:One-liner|Narrative|Tagline):\s*(.*)",
    "SUPPLY":           r"(?:Total Supply|Supply):\s*(.*)",
    "LP_PCT":           r"(?:LP|Liquidity Pool)[^:]*:\s*(\d+%)",
    "BURN_MECHANIC":    r"(?:Burn|Burn Mechanic)[^:]*:\s*(.*)",
    "CHAIN":            r"(?:Chain|Selected Chain|Network):\s*(.*)",
    "TOKEN_STANDARD":   r"(?:Token Standard|Standard):\s*(.*)",
    "DECIMALS":         r"(?:Decimals):\s*(\d+)",
    "MULTISIG_THRESHOLD": r"(?:Threshold|Multisig):\s*(.*)",
    "PRIMARY_COLOR":    r"(?:Primary Color|Primary):\s*(#[0-9a-fA-F]{6})",
    "SECONDARY_COLOR":  r"(?:Secondary Color|Secondary):\s*(#[0-9a-fA-F]{6})",
    "STYLE":            r"(?:Style|Art Style|Visual Style):\s*(.*)",
    "MASCOT":           r"(?:Mascot|Character):\s*(.*)",
    "WEBSITE":          r"(?:Website|URL):\s*(.*)",
    "REPO":             r"(?:Repo|GitHub|Repository):\s*(.*)",
    "CONTACT_EMAIL":    r"(?:Email|Contact):\s*(.*@.*)",
}

# Default values when not found in brief
DEFAULTS = {
    "TOKEN_NAME":       "TOKEN_NAME",
    "TICKER":           "TICKER",
    "NARRATIVE":        "A memecoin built different.",
    "SUPPLY":           "1,000,000,000",
    "LP_PCT":           "70%",
    "BURN_MECHANIC":    "1% per trade",
    "CHAIN":            "Solana",
    "TOKEN_STANDARD":   "Token-2022",
    "DECIMALS":         "9",
    "MULTISIG_THRESHOLD": "3/5",
    "PRIMARY_COLOR":    "#00F0FF",
    "SECONDARY_COLOR":  "#9B59FF",
    "STYLE":            "3D render, vibrant colors",
    "MASCOT":           "mascot character",
    "WEBSITE":          "https://example.com",
    "REPO":             "org/repo",
    "CONTACT_EMAIL":    "team@example.com",
    # Post-deploy placeholders (populated after deployment)
    "EXPLORER_LINK":    "https://solscan.io/token/MINT_ADDRESS",
    "DEX_LINK":         "https://jup.ag/swap/USDC-MINT_ADDRESS",
    "DASHBOARD_URL":    "https://dashboard.example.com",
}


def parse_brief(brief_path: str) -> dict[str, str]:
    """Parse MEMECOIN_BRIEF.md and extract all template variables."""
    params = dict(DEFAULTS)

    if not os.path.exists(brief_path):
        print(f"Warning: Brief not found at {brief_path}, using defaults")
        return params

    with open(brief_path, "r") as f:
        content = f.read()

    for key, pattern in FIELD_PATTERNS.items():
        match = re.search(pattern, content, re.IGNORECASE)
        if match:
            params[key] = match.group(1).strip()

    return params


# =============================================================================
# TEMPLATE ENGINE
# =============================================================================

def populate_template(template_content: str, params: dict[str, str]) -> str:
    """Replace {VARIABLE} placeholders with values from params."""
    result = template_content
    for key, value in params.items():
        result = result.replace(f"{{{key}}}", value)
    return result


def process_templates(template_dir: str, output_dir: str, params: dict[str, str]) -> int:
    """Walk template directory, populate templates, write to output."""
    template_path = Path(template_dir)
    output_path = Path(output_dir)
    generated = 0

    if not template_path.exists():
        print(f"Error: Template directory not found: {template_dir}")
        return 0

    for template_file in template_path.rglob("*.md"):
        relative = template_file.relative_to(template_path)
        output_file = output_path / relative

        # Read template
        with open(template_file, "r") as f:
            content = f.read()

        # Populate
        populated = populate_template(content, params)

        # Write
        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, "w") as f:
            f.write(populated)

        generated += 1
        print(f"  + {relative}")

    return generated


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Narrative Forge — Generate marketing assets from MEMECOIN_BRIEF.md"
    )
    parser.add_argument(
        "--brief",
        default="MEMECOIN_BRIEF.md",
        help="Path to MEMECOIN_BRIEF.md (default: ./MEMECOIN_BRIEF.md)",
    )
    parser.add_argument(
        "--output",
        default="./marketing",
        help="Output directory for generated assets (default: ./marketing)",
    )
    parser.add_argument(
        "--templates",
        default=None,
        help="Template directory (default: auto-detect from skill path)",
    )
    args = parser.parse_args()

    print("=" * 60)
    print("  NARRATIVE FORGE — Content Generator")
    print("=" * 60)

    # Auto-detect template directory
    template_dir = args.templates
    if template_dir is None:
        skill_root = Path(__file__).resolve().parent.parent.parent
        template_dir = str(skill_root / "templates" / "narrative_forge")

    # Parse brief
    print(f"\nBrief: {args.brief}")
    params = parse_brief(args.brief)
    print(f"Token: {params['TOKEN_NAME']} ({params['TICKER']})")
    print(f"Chain: {params['CHAIN']}")

    # Generate from templates
    print(f"\nTemplates: {template_dir}")
    print(f"Output:    {args.output}\n")

    count = process_templates(template_dir, args.output, params)

    if count == 0:
        print("\nNo templates found. Check template directory path.")
        sys.exit(1)

    print(f"\nGenerated {count} marketing asset(s).")

    # Check for remaining placeholders
    remaining = set()
    for f in Path(args.output).rglob("*.md"):
        content = f.read_text()
        remaining.update(re.findall(r"\{[A-Z_]+\}", content))

    if remaining:
        print(f"\nUnresolved placeholders ({len(remaining)}):")
        for var in sorted(remaining):
            print(f"  {var}")
        print("These will need manual replacement or post-deploy population.")

    print("\n" + "=" * 60)
    print("  NARRATIVE FORGE COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()
