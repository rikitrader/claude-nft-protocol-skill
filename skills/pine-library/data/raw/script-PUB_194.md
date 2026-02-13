---
id: PUB;194
title: [LAVA] UNO Overlay
author: Ni6HTH4wK
type: indicator
tags: []
boosts: 143
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_194
---

# Description
[LAVA] UNO Overlay

# Source Code
```pine
study(title="[LAVA] Ultimate Nonlinear Oscillator", shorttitle="UNO_L", overlay=true)

length7 = input(7, minval=1), length14 = input(14, minval=1), length28 = input(28, minval=1)

average(bp, tr_, length) => sum(bp, length) / sum(tr_, length)

lowers = highest(low, length14)
uppers = lowest(high, length14) 
high_ = max(high, close[1])
low_ = min(low, close[1])
bp = close - low_
tr_ = high_ - low_
tp_ = uppers - lowers
avg7 = average(bp, tr_, length7)
avg14 = average(bp, tr_, length14)
avg28 = average(bp, tr_, length28)

out = 100 * (4*avg7 + 2*avg14 + avg28)/7
upper = uppers-out*(tp_*.015)
lower = lowers+out*(tp_*.018)

p2 = plot(lower, color=#00FF00, title="UNO TOP")
p3 = plot(upper, color=#FF0000, title="UNO BOT")
```
