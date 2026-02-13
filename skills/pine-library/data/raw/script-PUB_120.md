---
id: PUB;120
title: FREE INDICATOR, aPPO: (ADVANCED) PRICE PERCENTAGE OSCILLATOR
author: TheLark
type: indicator
tags: []
boosts: 677
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_120
---

# Description
FREE INDICATOR, aPPO: (ADVANCED) PRICE PERCENTAGE OSCILLATOR

# Source Code
```pine
study(title="Advanced Percentage Price Oscillator", shorttitle="Advanced PPO")

//•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//   
//                                             //
//           ADVANCED PPO BY THELARK           //
//                 ~ 2-10-14 ~                 //
//                                             //
//                     •/•                     //
//                                             //
//    https://www.tradingview.com/u/TheLark    //
//                                             //
//•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//

src = close
shortlen=input(9, minval=1, title="Short Length") 
longlen=input(26, minval=1, title="Long Length")
dosig=input(true,title="Show Signal?")
dohist=input(true,title="Show Histogram?")
smooth=input(9, minval=1, title="Signal Smoothing")

short = ema(src, shortlen)
long = ema(src, longlen)
ppo = ((short - long)/long)*100
sig = ema(ppo,smooth)

plot(ppo, title="PPO", color=#0094FF)
plot(dosig?sig:na, title="signal", color=#FA6901)
plot(dohist?ppo-sig:na,color=#FF006E,style=histogram )
```
