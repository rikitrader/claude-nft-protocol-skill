---
id: PUB;XrDhfDeV9R0EgXCxFF63QkFePoM4Awo9
title: Donchian Channels Mom
author: CapnOscar
type: indicator
tags: []
boosts: 824
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_XrDhfDeV9R0EgXCxFF63QkFePoM4Awo9
---

# Description
Donchian Channels Mom

# Source Code
```pine
study(title="Donchian Channels Mom", shorttitle="DCMom", overlay=false)

len = input(200, minval=1, title="Length")
src = input(close, title="Source")
momi = src - src[len]
smooth = input(10, minval=0, title="Smooth")
mom=ema(momi, smooth)

length = input(100, minval=1)
lower = lowest(mom,length)
upper = highest(mom,length)
basis = avg(upper, lower)
l = plot(lower, color=red)
u = plot(upper, color=red)
plot(basis, color=red, linewidth=3)
plot(mom, color=blue, linewidth=3)
fill(u, l, color=orange, transp=95)
```
