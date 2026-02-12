# Candlestick Patterns — Japanese Candlestick Analysis Expert

> Comprehensive Japanese candlestick pattern recognition, trading strategies, and technical convergence analysis. 60+ patterns with Japanese names, psychology, reliability ratings, and entry/exit rules.

## Activation

This skill activates when the user asks about:

- Japanese candlestick patterns (hammer, engulfing, morning star, doji, harami, etc.)
- Candlestick chart analysis or reading
- Pattern recognition on price charts
- Reversal patterns, continuation patterns, doji patterns
- Candlestick trading strategies (pin bar, inside bar, engulfing setups)
- Convergence analysis (candles + indicators, candles + volume, candles + trendlines)
- Steve Nison's candlestick techniques
- Japanese trading terminology (takuri, sanpei, marubozu, mado, etc.)
- Bullish/bearish signal identification
- Pattern reliability and success rates
- Risk management for candlestick-based trading
- Market structure analysis with candlesticks

## Quick Reference

### Pattern Categories
| Category | Examples | Count |
|----------|----------|-------|
| Single Reversal | Hammer, Hanging Man, Shooting Star, Inverted Hammer, Marubozu | ~10 |
| Doji | Standard, Long-Legged, Dragonfly, Gravestone, Four-Price, Tri-Star | ~6 |
| Dual Reversal | Engulfing, Harami, Tweezers, Piercing, Dark Cloud, Belt-Hold, Kicker | ~14 |
| Triple Reversal | Morning/Evening Star, Three White Soldiers, Three Black Crows, Abandoned Baby | ~12 |
| Continuation | Windows, Tasuki, Rising/Falling Three Methods, Separating Lines, Mat Hold | ~10 |
| Complex | Three-Line Strike, Hikkake, Ladder Bottom, Inside Bar, Pin Bar | ~8 |

### Convergence Topics
- Candles + Trend Lines (springs, upthrusts, polarity)
- Candles + Retracement Levels (Fibonacci, S/R)
- Candles + Moving Averages (SMA, EMA)
- Candles + Oscillators (RSI, Stochastics, MACD)
- Candles + Volume analysis
- Measured Moves (breakouts, swing targets)

### Trading Strategies
- Pin Bar setups (trending, ranging, confluence)
- Engulfing Bar setups (with MA, Fibonacci, trendlines, S&D zones)
- Inside Bar strategies (breakout, false breakout, Fibonacci)
- Money management (position sizing, risk-to-reward, stop loss placement)

## How to Use

### MCP Tools (11 tools, `candle_*` prefix)
The engine exposes 11 MCP tools via stdio JSON-RPC 2.0:

| Tool | Purpose |
|------|---------|
| `candle_search` | Fuzzy search across all patterns, strategies, sections |
| `candle_get_pattern` | Full docs for a specific pattern (name, Japanese name, signal, reliability) |
| `candle_list_patterns` | List all patterns; filter by signal/type/category |
| `candle_get_strategy` | Full docs for a trading strategy |
| `candle_list_strategies` | List all indexed strategies |
| `candle_get_section` | Extract a documentation section by ID |
| `candle_list_signals` | Pattern counts by signal (bullish/bearish/neutral) |
| `candle_code_examples` | Get code examples for a topic |
| `candle_extract` | Universal extraction by ID (auto-detects pat/strat/section/example) |
| `candle_index_status` | Index statistics and freshness |
| `candle_suggest` | Typo correction / ID suggestions |

### CLI Commands
```bash
cd ~/.claude/skills/candlestick-patterns
python3 -m engine search "hammer reversal"
python3 -m engine get-pattern hammer
python3 -m engine list-patterns --signal bullish
python3 -m engine list-strategies
python3 -m engine extract pat/morning-star
python3 -m engine status
python3 -m engine build-index
python3 -m engine serve  # Start MCP server
```

## Architecture

- **stdlib-only Python** — zero external dependencies
- **Byte-offset extraction** — 90%+ token reduction vs loading full files
- **JSON index** with sections, patterns, strategies, and code examples
- **Fuzzy search** using `difflib.SequenceMatcher`
- **Path traversal protection** on all file access
- **Thread-safe JSONL** token usage tracking

## Sources

1. **Steve Nison** — *Japanese Candlestick Charting Techniques*, 2nd Edition (298 pages, OCR'd)
2. **The Candlestick Trading Bible** — KohanFx (167 pages, strategies + money management)
3. **Web sources** — Investopedia, Bulkowski research, comprehensive pattern encyclopedia
