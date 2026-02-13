---
id: PUB;950
title: On Balance Volume EMA-13
author: NeilDonkin
type: indicator
tags: []
boosts: 708
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_950
---

# Description
On Balance Volume EMA-13

# Source Code
```pine
study(title="On Balance Volume EMA-13", shorttitle="OBV EMA")
src = close
obv = cum(change(src) > 0 ? volume : change(src) < 0 ? -volume : 0*volume)
plot(ema(obv, 13), color=blue, title="OBV")
```
