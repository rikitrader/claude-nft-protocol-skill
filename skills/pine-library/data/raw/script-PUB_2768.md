---
id: PUB;2768
title: Absolute Momentum Indicator 
author: Algokid
type: indicator
tags: []
boosts: 1306
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2768
---

# Description
Absolute Momentum Indicator 

# Source Code
```pine
//@version=2
study("Absolute Momentum")

p = input(12,minval=1,title = "LookBack Period")
sym = input(title="Symbol", type=symbol, defval="SHY")
sm = input(1,minval=1,title = "Smooth Period")


rc = roc(close,p)

bil = security(sym,"M",close)
bilr = roc(bil,p)


rcdm = rc-bilr
srcdm = sma(rcdm,sm)

line = 0 

plot(rcdm,color= red,title= "Absolute Momentum" )
plot(srcdm,color = blue,title="Smooth Abs Momentum")
plot(line , color = gray,title="Zero Line")


barcolor(rcdm > 0 ? lime:red)
```
