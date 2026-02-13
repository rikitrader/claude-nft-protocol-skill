---
id: PUB;2964
title: CCI Extreme and OBV Divergence
author: CooperHoang
type: indicator
tags: []
boosts: 607
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2964
---

# Description
CCI Extreme and OBV Divergence

# Source Code
```pine
study(title="Commodity Channel Index", shorttitle="CCI & OBV")
length = input(20, minval=1)
src = input(close, title="Source")
ma = sma(src, length)
cci = (src - ma) / (0.015 * dev(src, length))

length1 = input(60, minval=1)
ma1 = sma(src, length1)
cci1 = (src - ma1) / (0.015 * dev(src, length1))

length2 = input(240, minval=1)
ma2 = sma(src, length2)
cci2 = (src - ma2) / (0.015 * dev(src, length2))

bgUp  = (cci < 0 and cci1 < 0) ? red : na
bgDown =(cci > 0 and cci1 > 0) ? green : na

bgUp1  = (cci1 < -200 and cci < -200) ? red : na
bgDown1 = (cci1 > 200 and cci > 200) ? green : na

bgcolor (bgUp, transp=60)
bgcolor (bgDown, transp=60)
bgcolor (bgUp1, transp=0)
bgcolor (bgDown1, transp=0)

src1 = close
obv = cum(change(src1) > 0 ? volume : change(src1) < 0 ? -volume : 0*volume)
plot(obv, color=blue, title="OBV")


```
