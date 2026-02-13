---
id: PUB;629
title: VIX - Fast 30% gains in volatility - shorting 
author: Pinkfloyd111.
type: indicator
tags: []
boosts: 188
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_629
---

# Description
VIX - Fast 30% gains in volatility - shorting 

# Source Code
```pine
study("My Script")
a=high
ma=ema(close,10)
c=a/ma
plot(c, color=blue)
plot(1, color=red)
plot(1.3, color=green)
```
