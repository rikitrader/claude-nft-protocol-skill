---
id: PUB;1704
title: Moving Average ADX
author: CapnOscar
type: indicator
tags: []
boosts: 6441
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1704
---

# Description
Moving Average ADX

# Source Code
```pine
study(title="Moving Average ADX", shorttitle="MA ADX", overlay=true)

lenadx = input(14, minval=1, title="DI Length")
lensig = input(14, title="ADX Smoothing", minval=1, maxval=50)
limadx = input(18, minval=1, title="ADX MA Active")


up = change(high)
down = -change(low)
trur = rma(tr, lenadx)
plus = fixnan(100 * rma(up > down and up > 0 ? up : 0, lenadx) / trur)
minus = fixnan(100 * rma(down > up and down > 0 ? down : 0, lenadx) / trur)
sum = plus + minus 
adx = 100 * rma(abs(plus - minus) / (sum == 0 ? 1 : sum), lensig)

macol = adx > limadx and plus > minus ? lime : adx > limadx and plus < minus ? red :black


len = input(34, minval=1, title="Length")
src = input(close, title="Source")
out = wma(src, len)
plot(out, color=macol, title="MA", linewidth= 3)



```
