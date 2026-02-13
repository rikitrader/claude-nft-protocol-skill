---
id: PUB;2198
title: Aroon Oscillator
author: jcrewolinski
type: indicator
tags: []
boosts: 2031
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2198
---

# Description
Aroon Oscillator

# Source Code
```pine
study(title="Aroon Oscillator", shorttitle="Aroon Oscillator", overlay=false)
length = input(14, minval=1)
upper = 100 * (highestbars(high, length+1) + length)/length
lower = 100 * (lowestbars(low, length+1) + length)/length
midp = 0
oscillator = upper - lower
osc = plot(oscillator, color=red)
mp = plot(midp)
top = plot(80)
bottom = plot(-80)

fill(osc, mp)
fill(top,bottom)
```
