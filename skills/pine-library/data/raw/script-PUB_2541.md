---
id: PUB;2541
title: EMA bullish/bearish dashboard - MTF
author: squattter
type: indicator
tags: []
boosts: 585
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2541
---

# Description
EMA bullish/bearish dashboard - MTF

# Source Code
```pine
study(title="EMA bullish/bearish dashboard - MTF")
//ema 1
len1 = input(100, minval=1)
src = input(close, title="Source")
ema1 = ema(src, len1)

len2 = input(200, minval=1)
ema2 = ema(src, len2)

useCurrentRes = input(true, title="Use current timeframe?")

resCustom = input(title="Timeframe", type=resolution, defval="5")
res = useCurrentRes ? period : resCustom
ema11 = security(tickerid, res, ema1)
ema22 = security(tickerid, res, ema2)



plot((ema11 > ema22 and close > ema22), title="Buy 2/2", style=columns, color=lime)
plot((ema11 > ema22 and close < ema22), title="Buy 1/2", style=columns, color=green)
plot((ema11 < ema22 and close < ema22), title="Sell 2/2", style=columns, color=maroon)
plot((ema11 < ema22 and close > ema22), title="Sell 1/2", style=columns, color=red)
```
