---
id: PUB;1422
title: Price above/below EMA
author: repo32
type: indicator
tags: []
boosts: 965
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1422
---

# Description
Price above/below EMA

# Source Code
```pine
//Created by Robert Nance 060915
//This little script simply gives you a quick visual cue of where price is compared to a particular EMA.
// It is defaulted to the 8 EMA
study(title="Price above/below EMA", shorttitle="BuySellEMA", overlay=false)
len = input(8, minval=1, title="Length")
src = input(close, title="Source")
out = ema(src, len)
plot(close >= out, title="Buy", style=columns, color=lime)
plot(close < out, title="Buy", style=columns, color=red)
```
