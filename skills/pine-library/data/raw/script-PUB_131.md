---
id: PUB;131
title: RSI Candles
author: glaz
type: indicator
tags: []
boosts: 22437
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_131
---

# Description
RSI Candles

# Source Code
```pine
// With levels candle border must be removed for better view  
// By Glaz
study(title="RSI Chart Bars",overlay = true, shorttitle="RSI Bars")
src = close, len = input(14, minval=1, title="Length")
up = rma(max(change(src), 0), len)
down = rma(-min(change(src), 0), len)
rsi = down == 0 ? 100 : up == 0 ? 0 : 100 - (100 / (1 + up / down))

//coloring method below

src1 = close, len1 = input(70, minval=1, title="UpLevel")
src2 = close, len2 = input(30, minval=1, title="DownLevel")
isup() => rsi > len1
isdown() => rsi < len2
barcolor(isup() ? green : isdown() ? red : na )
```
