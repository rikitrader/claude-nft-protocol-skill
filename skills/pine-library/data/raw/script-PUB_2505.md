---
id: PUB;2505
title: Simple Moving Average Strategy
author: Dr.Pip
type: indicator
tags: []
boosts: 1431
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2505
---

# Description
Simple Moving Average Strategy

# Source Code
```pine

strategy(title="Mbit Moving Average",overlay=true)

length = input(520)
confirmBars = input(27)
price = close
ma = sma(price, length)

bcond = price > ma

bcount = bcond ? nz(bcount[1]) + 1 : 0

scond = price < ma

scount = scond ? nz(scount[1]) + 1 : 0

long =  scount == confirmBars

short = bcount == confirmBars


//Strategy

strategy.entry("long", strategy.long, when=long)

strategy.entry("short",strategy.short, when=short)

```
