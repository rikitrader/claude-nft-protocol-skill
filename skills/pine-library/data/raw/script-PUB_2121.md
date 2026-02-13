---
id: PUB;2121
title: Bollinger Bands %RSI
author: kinetix360
type: indicator
tags: []
boosts: 642
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2121
---

# Description
Bollinger Bands %RSI

# Source Code
```pine
study(title = "Bollinger Bands %RSI", shorttitle = "BB %RSI")

source = hlc3
length = input(14, minval=1), mult = input(2.0, minval=0.001, maxval=50)
HighlightBreaches=input(true, title="Highlight Oversold/Overbought?", type=bool)

//Define RSI
rsi_s = rsi(source, length)


// BB of RSI

basis = sma(rsi_s, length)
dev = mult * stdev(rsi_s, length)
upper = basis + dev
lower = basis - dev

bbr = (rsi_s - lower)/(upper - lower)
plot(bbr, color=teal)
band1 = hline(1, color=gray, linestyle=dashed)
band0 = hline(0, color=gray, linestyle=dashed)
fill(band1, band0, color=teal)

//p1 = plot(upper, color=blue)
//p2 = plot(lower, color=blue)
//fill(p1,p2, blue)

b_color = (rsi_s > upper) ? red : (rsi_s < lower) ? green : na
bgcolor(HighlightBreaches ? b_color : na)
```
