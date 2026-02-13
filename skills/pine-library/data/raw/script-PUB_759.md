---
id: PUB;759
title:  Volatility Stop
author: admin
type: indicator
tags: []
boosts: 2970
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_759
---

# Description
 Volatility Stop

# Source Code
```pine
study("Volatility Stop", shorttitle="VStop", overlay=true)
length = input(20)
mult = input(2)
atr_ = atr(length)
max1 = max(nz(max_[1]), close)
min1 = min(nz(min_[1]), close)
is_uptrend_prev = nz(is_uptrend[1], true)
stop = is_uptrend_prev ? max1 - mult * atr_ : min1 + mult * atr_
vstop_prev = nz(vstop[1])
vstop1 = is_uptrend_prev ? max(vstop_prev, stop) : min(vstop_prev, stop)
is_uptrend = close - vstop1 >= 0
is_trend_changed = is_uptrend != is_uptrend_prev
max_ = is_trend_changed ? close : max1
min_ = is_trend_changed ? close : min1
vstop = is_trend_changed ? is_uptrend ? max_ - mult * atr_ : min_ + mult * atr_ : vstop1
plot(vstop, color = is_uptrend ? green : red, style=cross, linewidth=2)
```
