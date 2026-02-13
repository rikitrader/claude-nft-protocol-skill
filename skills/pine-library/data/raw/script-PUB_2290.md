---
id: PUB;2290
title: Scalper's Channel [LazyBear]
author: lonestar108
type: indicator
tags: []
boosts: 1764
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2290
---

# Description
Scalper's Channel [LazyBear]

# Source Code
```pine
//
// @author LazyBear
// @credits http://freethinkscript.blogspot.com/2009/05/only-scalpers-channel-that-you-will.html
//
study(title = "Scalper's Channel [LazyBear]", shorttitle="Scalper's Channel", overlay=true)
length = input(20)
factor = input(15)
pi = atan(1)*4
Average(x,y) => (sum(x,y) / y)
scalper_line= plot(Average(close, factor) - log(pi * (atr(factor))), color=blue, linewidth=3)
hi = plot (highest(length), color=fuchsia)
lo = plot (lowest(length), color=fuchsia)
```
