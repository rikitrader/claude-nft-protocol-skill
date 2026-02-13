---
id: PUB;2999
title: Average Daily Range
author: SuddenFX
type: indicator
tags: []
boosts: 1298
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2999
---

# Description
Average Daily Range

# Source Code
```pine
study(title="Average Daily Range", shorttitle="ADR", overlay=false)
thishigh = security(tickerid, 'D', high)
thislow  = security(tickerid, 'D', low)
length = 14
adr = sma(thishigh,length)-sma(thislow,length)
plot(adr, color=red)
```
