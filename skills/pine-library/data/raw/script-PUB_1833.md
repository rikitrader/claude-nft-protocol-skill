---
id: PUB;1833
title: Romi Trend and Momentum Oscillator
author: WhiteCollarTrader
type: indicator
tags: []
boosts: 448
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1833
---

# Description
Romi Trend and Momentum Oscillator

# Source Code
```pine
study(title = "Romi Trend and Momentum Oscillator", shorttitle="ROMI")
s2=ema(close, 8) - ema(open, 24)
c_color=s2 <= 0 ? red : lime
plot(s2, color=c_color, style=line, linewidth=2)
```
