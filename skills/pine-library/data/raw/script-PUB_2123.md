---
id: PUB;2123
title: BB - MFI/RSI [Modified from LazyBear]
author: kinetix360
type: indicator
tags: []
boosts: 2387
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2123
---

# Description
BB - MFI/RSI [Modified from LazyBear]

# Source Code
```pine
//
// @author LazyBear
// RSI/MFI with Bollinger Bands. Dynamic Oversold/Overbought levels, yayy!
// I add the BB period setting as told by John Bollinger's Book. 
study(title = "BB% of MFI/RSI [Modified from LazyBear]", shorttitle="BB%MFI/RSI[LB]")
source = hlc3
length = input(14, minval=1), mult = input(2.0, minval=0.001, maxval=50), bblength = input(50, minval=1, title="BB Period")
DrawRSI_f=input(true, title="Draw RSI?", type=bool)
DrawMFI_f=input(false, title="Draw MFI?", type=bool)
HighlightBreaches=input(true, title="Highlight Oversold/Overbought?", type=bool)

DrawMFI = (not DrawMFI_f) and (not DrawRSI_f) ? true : DrawMFI_f
DrawRSI = (DrawMFI_f and DrawRSI_f) ? false : DrawRSI_f
// RSI
rsi_s = DrawRSI ? rsi(source, length) : na
plot(DrawRSI ? rsi_s : na, color=maroon, linewidth=2)

// MFI
upper_s = DrawMFI ? sum(volume * (change(source) <= 0 ? 0 : source), length) : na
lower_s = DrawMFI ? sum(volume * (change(source) >= 0 ? 0 : source), length) : na
mf = DrawMFI ? rsi(upper_s, lower_s) : na
plot(DrawMFI ? mf : na, color=green, linewidth=2)


// Draw BB on indices
bb_s = DrawRSI ? rsi_s : DrawMFI ? mf : na
basis = sma(bb_s, length)
dev = mult * stdev(bb_s, bblength)
upper = basis + dev
lower = basis - dev
plot(basis, color=red)
p1 = plot(upper, color=blue)
p2 = plot(lower, color=blue)
fill(p1,p2, blue)

b_color = (bb_s > upper) ? red : (bb_s < lower) ? green : na
bgcolor(HighlightBreaches ? b_color : na)
```
