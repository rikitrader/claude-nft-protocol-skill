---
id: PUB;1397
title: ATR%, ATR Timer and Range Expansion signal
author: IvanLabrie
type: indicator
tags: []
boosts: 817
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1397
---

# Description
ATR%, ATR Timer and Range Expansion signal

# Source Code
```pine
study(title="ATR%", shorttitle="ATR%", overlay=false)
source = close
length = input(1, minval=1, title = "EMA Length")
atrlen = input(10, minval=1, title = "ATR Length")
ma = ema(source, length)
range =  tr
rangema = ema(range, atrlen)

atrp = (rangema/ma)*100
avg = ema(atrp,30)
plot(atrp, color=black)
plot(avg, color=maroon)
```
