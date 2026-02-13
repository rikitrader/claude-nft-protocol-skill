---
id: PUB;2159
title: [RS]Auto Regression Channel V0
author: RicardoSantos
type: indicator
tags: []
boosts: 531
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2159
---

# Description
[RS]Auto Regression Channel V0

# Source Code
```pine
//@version=2
study(title='[RS]Auto Regression Channel V0', shorttitle='ARC', overlay=true)
length = input(10)
length2 = input(10)
multiplier = input(0.01)
h = ema(na(h[1]) ? high : high >= h[1] ? high : ema(close, length) >= mid[1] ? h[1] + ema(h[1]-close, length)*multiplier : h[1] - ema(h[1]-close, length)*multiplier, length2)
l = ema(na(l[1]) ? low : low <= l[1] ? low : ema(close, length) <= mid[1] ? l[1] - ema(close-l[1], length)*multiplier : l[1] + ema(close-l[1], length)*multiplier, length2)
mid = avg(h, l)
plot(title='H', series=h, color=black, linewidth=2)
plot(title='M', series=mid, color=black, linewidth=2)
plot(title='L', series=l, color=black, linewidth=2)
```
