---
id: PUB;642
title: Multi-Functional Fisher Transform MTF with MACDL TRIGGER
author: QuantitativeExhaustion
type: indicator
tags: []
boosts: 1437
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_642
---

# Description
Multi-Functional Fisher Transform MTF with MACDL TRIGGER

# Source Code
```pine
study(title="Fisher Transform MTF", shorttitle="Fisher MTF")
//Both fisher and macdl MTF
resCustom = input(title="Timeframe", type=resolution, defval="60" )
//--------macdl
src=close
shortLength = input(12, title="Fast Length")
longLength = input(26, title="Slow Length")
sigLength = input(9, title="Signal Length")
ma(s,l) => ema(s,l)
sema = ma( src, shortLength )
lema = ma( src, longLength )
i1 = sema + ma( src - sema, shortLength )
i2 = lema + ma( src - lema, longLength )
macdl = i1 - i2
macdl2 = security(tickerid, resCustom,macdl)
macd=sema-lema
//-------end

//---------fisher
len = input(34, minval=1, title="Fisher")
round_(val) => val > .99 ? .999 : val < -.99 ? -.999 : val
high_ = highest(hl2, len)
low_ = lowest(hl2, len)
value = round_(.66 * ((hl2 - low_) / max(high_ - low_, .001) - .5) + .67 * nz(value[1]))
fish1 = .5 * log((1 + value) / max(1 - value, .001)) + .5 * nz(fish1[1])
fish2 = security(tickerid, resCustom,fish1)
//------------end

sw1=iff(fish2<-6 and macdl2>macdl2[1],1,0)
sw2=iff(fish2>6 and macdl2<macdl2[1],-1,0)
final=sw1+sw2

swap=final==1 or final==-1?fuchsia:green
plot(fish2, color=swap, title="Fisher",style=histogram)
hline(0, color=orange)
```
