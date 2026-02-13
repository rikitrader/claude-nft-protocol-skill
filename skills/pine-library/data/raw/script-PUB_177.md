---
id: PUB;177
title: BBImpulse Indicator
author: LazyBear
type: indicator
tags: []
boosts: 1432
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_177
---

# Description
BBImpulse Indicator

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study(title = "Bollinger Bands Impulse [LazyBear]", shorttitle = "BBIMP_LB")
source = close
length = input(20, minval=1)
mult = input(2.0, title="Mult Factor", minval=0.001, maxval=50)
alertLevel=input(0.24)
impulseLevel=input(0.40)
showRange = input(false, type=bool)

// Calc BB
basis = sma(source, length)
dev = mult * stdev(source, length)
upper = basis + dev
lower = basis - dev

// Calc Impulse
bbr = (source - lower)/(upper - lower)
bbi = bbr - nz(bbr[1]) 
bbc = iff(bbi>0, 
        iff(bbi>alertLevel and bbi<impulseLevel, lime, iff(bbi>impulseLevel, orange, aqua)),  
        iff(bbi<-alertLevel and bbi>-impulseLevel, red, iff(bbi<-impulseLevel, orange, aqua))
        )

// Plot Ian Woodward's suggested Reference Levels
plot(0, color=gray, title="MidLine", style=3)
plot( impulseLevel, color=gray, style=line, linewidth=1, title="Impulse+")
plot( alertLevel, color=gray, style=3, linewidth=1, title="Alert+")
plot( -alertLevel, color=gray, style=3, linewidth=1, title="Alert-")
plot( -impulseLevel, color=gray, style=line, linewidth=1, title="Impulse-")

plot(showRange ? bbr : na, color=gray, style=area, title="Range+", linewidth=0, transp=80)
plot(showRange ? -bbr : na, color=gray, style=area, title="Range-", linewidth=0, transp=80)

plot(bbi, color=bbc, style=histogram, linewidth=2)




```
