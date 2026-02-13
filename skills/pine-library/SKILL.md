# Pine-Library

Community Pine Script indicator, strategy, and library reference engine with 90%+ token reduction.

## Activation Triggers

Use this skill when the user:
- Asks about popular Pine Script community indicators or strategies
- Wants to find open-source Pine Script code for specific techniques (e.g., "volume profile indicator", "order block detection")
- Needs example Pine Script implementations from top TradingView authors (LuxAlgo, ChartPrime, LazyBear, etc.)
- Wants to browse or filter community scripts by type, tag, or author
- Needs reference implementations for building their own indicators

## MCP Tools (11)

| Tool | Purpose | ~Tokens |
|------|---------|---------|
| `plib_search` | Fuzzy search scripts by keyword/tag/author/type | ~800 |
| `plib_get_script` | Full script data (metadata + description + source) | ~2,000 |
| `plib_get_source` | Pine Script source code only | ~750 |
| `plib_list_scripts` | List with filters (type, tag, author, sort) | ~1,500 |
| `plib_list_tags` | All tags with script counts | ~500 |
| `plib_list_authors` | All authors with script counts | ~500 |
| `plib_code_examples` | Code examples matching a topic | ~1,000 |
| `plib_extract` | Universal byte-offset extraction by ID | ~500 |
| `plib_index_status` | Index statistics | ~200 |
| `plib_usage_report` | Token savings report | ~200 |
| `plib_suggest` | Typo correction for IDs/tags/authors | ~300 |

## CLI Commands

```bash
cd ~/.claude/skills/pine-library

python3 -m engine build-index          # Build index from raw files
python3 -m engine check-index          # Check if index is current
python3 -m engine search "volume"      # Search scripts
python3 -m engine get-script PUB;175   # Get full script data
python3 -m engine get-source PUB;175   # Get source code only
python3 -m engine list-scripts --type strategy --limit 10
python3 -m engine list-tags --min-count 5
python3 -m engine list-authors --min-scripts 3
python3 -m engine extract PUB;175      # Extract by ID
python3 -m engine status               # Engine status
python3 -m engine token-report         # Token savings
python3 -m engine serve                # Start MCP server
```

## Complementary Skills

- **pinecoder** — Pine Script v6 language reference (built-in functions, syntax, types)
- **lightweight-charts** — TradingView chart widget API for rendering
- **candlestick-patterns** — Japanese candlestick pattern recognition

## Architecture

- stdlib-only Python engine (no external dependencies)
- JSON-RPC 2.0 MCP server over stdio
- Byte-offset extraction for 90%+ token reduction
- YAML frontmatter + markdown format for raw data
