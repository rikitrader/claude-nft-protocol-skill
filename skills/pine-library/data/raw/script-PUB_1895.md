---
id: PUB;1895
title: HullMA Strategy
author: sirolf2009
type: indicator
tags: []
boosts: 3200
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1895
---

# Description
HullMA Strategy

# Source Code
```pine
//@version=2
strategy("HullMA Strategy", overlay=true)

n=input(title="period",type=integer,defval=16)


n2ma=2*wma(close,round(n/2))
nma=wma(close,n)
diff=n2ma-nma
sqn=round(sqrt(n))


n2ma1=2*wma(close[1],round(n/2))
nma1=wma(close[1],n)
diff1=n2ma1-nma1
sqn1=round(sqrt(n))


n1=wma(diff,sqn)
n2=wma(diff1,sqn)
c=n1>n2?green:red
ma=plot(n1,color=c)

longCondition = n1>n2
if (longCondition)
    strategy.entry("Long", strategy.long)

shortCondition = longCondition != true
if (shortCondition)
    strategy.entry("Short", strategy.short)
```
