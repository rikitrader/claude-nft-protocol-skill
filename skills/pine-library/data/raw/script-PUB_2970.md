---
id: PUB;2970
title: Bollinger Bands with ATR(Percent)
author: MarcoValente
type: indicator
tags: []
boosts: 389
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2970
---

# Description
Bollinger Bands with ATR(Percent)

# Source Code
```pine
study(shorttitle="BB+ATRP", title="Bollinger Bands with ATR(Percent)", overlay=true)
//@version=2
//study("Average Percentage True Range")
len=input(14,"ATRP")
lh = high - low
pc = close[1]
hc = abs( high - pc )
lc = abs( low - pc )
MM = max( max( lh, hc ), lc ) 
atrs = iff( MM == hc, hc / (  pc + ( hc / 2 ) ), 
       iff( MM == lc, lc / ( low + ( lc / 2 ) ), 
       iff( MM == lh, lh / ( low + ( lh / 2 ) ), 0 ) ) )

APTR = 100*atrs*(2/(len+1))+nz(APTR[1])*(1-(2/(len+1)))
//plot( APTR,title= "APTR"  ,color=red )

length = input(20,"BB", minval=1)
src = input(close, title="Source")
mult = input(2,step=0.1, minval=0.001, maxval=50)
basis = sma(src, length)
dev = mult * APTR
upper = basis + basis*dev/100
lower = basis - basis*dev/100
plot(basis, color=red)
p1 = plot(upper, color=blue)
p2 = plot(lower, color=blue)
fill(p1, p2)
```
