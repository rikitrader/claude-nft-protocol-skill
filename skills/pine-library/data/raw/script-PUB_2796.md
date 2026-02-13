---
id: PUB;2796
title: Volume Price Spread Analysis
author: eldeivit
type: indicator
tags: []
boosts: 1448
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2796
---

# Description
Volume Price Spread Analysis

# Source Code
```pine
//@version=2
study("Volume Price Spread Analysis 1", shorttitle="VPSA")
//Volume Spread Analysis
//Analisis de propagacion en Volumen
// devicemxl --> TradingView Site

/// Values
volumex=log(volume)//*(close>close[1] ? 1 : -1)
V_CLOSE = V_CLOSE[1] > 1 ? ( (close*volumex) + (high*volumex) + (low*volumex) + V_CLOSE[1] ) *0.25 : ( (close*volumex) + (high*volumex) + (low*volumex) + (((close[1]*volumex[1])+(open*volumex))*0.5) ) *0.25
V_OPEN  = (V_CLOSE[1]+(open*volumex))*0.5
V_HIGH = max(max(high*volumex,V_CLOSE),V_OPEN)
V_LOW   = min(min(low*volumex,V_OPEN),V_CLOSE)
V_HL2   = ( V_HIGH + V_LOW ) / 2
senial=input(defval="HL2",title="Signal",type=string)
ploter = ( senial == "CLOSE" ) ? V_CLOSE : ( senial == "OPEN" ) ? V_OPEN : ( senial == "HL2" ) ? V_HL2 : ( senial == "HIGH" ) ? V_HIGH : ( senial == "LOW" ) ? V_LOW : 0
signal = plot(ploter, color=silver, style=circles)

plotcandle(V_OPEN, V_HIGH, V_LOW, V_CLOSE, title='VSA', color = V_OPEN < V_CLOSE ? silver : red, wickcolor=black)

```
