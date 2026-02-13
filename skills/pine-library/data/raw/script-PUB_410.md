---
id: PUB;410
title: 3 new Indicators - PGO / RAVI / TII
author: LazyBear
type: indicator
tags: []
boosts: 1607
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_410
---

# Description
3 new Indicators - PGO / RAVI / TII

# Source Code
```pine
//
// @author LazyBear
// If you use this code in its orignal/modified form, do drop me a note. 
// 
study(title="Pretty Good Oscillator [LazyBear]", shorttitle="PGO_LB")
length=input(89)
pgo = (close - sma(close, length))/ema(tr, length)
hline(0)
hu=hline(3)
hl=hline(-3)
fill(hu,hl,red)
plot(pgo, color=red, linewidth=2)
```
