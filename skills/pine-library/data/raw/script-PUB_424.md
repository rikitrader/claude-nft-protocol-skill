---
id: PUB;424
title: Indicators: KaseCD & Kase Peak Oscillator
author: LazyBear
type: indicator
tags: []
boosts: 654
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_424
---

# Description
Indicators: KaseCD & Kase Peak Oscillator

# Source Code
```pine
//
// @author LazyBear
// If you use this code, in its original or modified form, appreciate if you could
// drop me a note. Thx. 
// 
study(title="Kase Peak Oscillator [LazyBear]", shorttitle="KPO_LB")
length=input(30, title="Length")
rwh=(high-low[length])/(atr(length)*sqrt(length))
rwl=(high[length]-low)/(atr(length)*sqrt(length))
pk=wma((rwh-rwl),3)
mn=sma(pk,length)
sd=stdev(pk,length)
v1=iff(mn+(1.33*sd)>2.08,mn+(1.33*sd),2.08)
v2=iff(mn-(1.33*sd)<-1.92,mn-(1.33*sd),-1.92)
ln=iff(pk[1]>=0 and pk>0,v1,iff(pk[1]<=0 and pk<0,v2,0))
rbars=iff(pk[1]>pk,pk,0)
gbars=iff(pk>pk[1],pk,0)
plot(rbars, style=histogram, color=red)
plot(gbars, style=histogram, color=green)
plot(ln, color=yellow, linewidth=1)
```
