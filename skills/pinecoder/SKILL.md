---
name: pinecoder
description: Pine Script v6 expert coder with full TradingView documentation ingested via MCP. This skill should be used when writing Pine Script code, debugging Pine indicators/strategies, looking up Pine Script functions (ta.sma, plot, strategy.entry, etc.), understanding Pine Script type system (series, simple, int, float, color), designing TradingView indicators, building trading strategies, working with Pine arrays/matrices/maps, creating alerts, handling timeframes, or any TradingView Pine Script development task. Triggers on Pine Script, PineScript, TradingView indicator, TradingView strategy, pine code, ta.sma, ta.ema, ta.rsi, ta.macd, plot(), strategy.entry, strategy.exit, request.security, input., label., line., box., table., array., matrix., map., series float, simple int, barcolor, bgcolor, plotshape, alertcondition, Pine v6, Pine v5, indicator script, strategy script, library script, Pine built-in, Pine function, Pine type, timeframe.period, syminfo, bar_index, close, open, high, low, volume, time, pine migration.
---

# PineCoder — Pine Script v6 Expert

Complete Pine Script v6 documentation engine with MCP-powered search, extraction, and coding assistance.

## Architecture

```
Scraper (60 pages) → Indexer (sections + functions + examples)
                          ↓
                   Index (JSON, byte offsets)
                          ↓
         Extractor ←→ Searcher ←→ MCP Server (11 tools)
```

## Quick Start

```bash
# 1. Scrape Pine Script docs (one-time, ~2 min)
cd ~/.claude/skills/pinecoder && python3 -m engine scrape

# 2. Build search index
python3 -m engine build-index

# 3. Verify
python3 -m engine status
```

## MCP Tools Available (11)

| Tool | Purpose | ~Tokens |
|------|---------|---------|
| `pine_search` | Fuzzy search across all docs | ~500 |
| `pine_get_section` | Extract a doc section by ID | ~800 |
| `pine_get_function` | Get built-in function docs | ~300 |
| `pine_list_functions` | List functions by namespace | ~600 |
| `pine_list_sections` | List sections by category | ~400 |
| `pine_list_namespaces` | List all function namespaces | ~200 |
| `pine_code_examples` | Get code examples for a topic | ~1000 |
| `pine_extract` | Extract any entry by ID | ~500 |
| `pine_index_status` | Check index stats | ~50 |
| `pine_usage_report` | Token savings report | ~50 |
| `pine_suggest` | Suggest similar IDs (typo fix) | ~100 |

## CLI Commands

```bash
python3 -m engine scrape          # Crawl docs from TradingView
python3 -m engine import <dir>    # Import local HTML/MD files
python3 -m engine build-index     # Build search index
python3 -m engine check-index     # Verify index freshness
python3 -m engine search <query>  # Search docs
python3 -m engine extract <id>    # Extract by entry ID
python3 -m engine list <category> # List sections/functions/examples
python3 -m engine status          # Engine status
python3 -m engine token-report    # Usage report
python3 -m engine serve           # Start MCP server
```

## Coding Workflow

When the user asks to write Pine Script code:

1. **Search first**: Use `pine_search` to find relevant docs
2. **Get function docs**: Use `pine_get_function` for any built-in you plan to use
3. **Check examples**: Use `pine_code_examples` for reference implementations
4. **Write code**: Generate Pine Script v6 code following the docs
5. **Validate**: Cross-reference with type system docs if needed

## Pine Script v6 Key Concepts

### Script Types
- **indicator()** — Custom technical indicators
- **strategy()** — Backtestable trading strategies
- **library()** — Reusable code libraries

### Type System (Qualifiers)
- **const** — Compile-time constant
- **input** — Set at script load via input.*
- **simple** — Known at bar 0 (doesn't change per bar)
- **series** — Can change on every bar (most common)

### Core Namespaces
- `ta.*` — Technical analysis (sma, ema, rsi, macd, etc.)
- `math.*` — Mathematical functions
- `str.*` — String operations
- `array.*` — Dynamic arrays
- `matrix.*` — 2D matrices
- `map.*` — Key-value maps
- `strategy.*` — Order execution
- `request.*` — Multi-timeframe/ticker data
- `chart.*` — Chart properties
- `color.*` — Color manipulation
- `input.*` — User inputs
- `label.*`, `line.*`, `box.*`, `table.*` — Drawing objects
- `timeframe.*`, `syminfo.*` — Context info

### Common Patterns

**Moving Average Crossover Strategy:**
```pine
//@version=6
strategy("MA Cross", overlay=true)
fast = ta.sma(close, 10)
slow = ta.sma(close, 50)
if ta.crossover(fast, slow)
    strategy.entry("Long", strategy.long)
if ta.crossunder(fast, slow)
    strategy.close("Long")
plot(fast, color=color.blue)
plot(slow, color=color.red)
```

**RSI with Alert:**
```pine
//@version=6
indicator("RSI Alert", overlay=false)
rsi = ta.rsi(close, 14)
overbought = input.int(70, "Overbought")
oversold = input.int(30, "Oversold")
plot(rsi)
hline(overbought, color=color.red)
hline(oversold, color=color.green)
alertcondition(ta.crossover(rsi, oversold), "RSI Oversold Cross", "RSI crossed above oversold")
```
