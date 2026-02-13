---
id: PUB;117
title: FREE INDICATOR: VOLUME MOMENTUM
author: TheLark
type: indicator
tags: []
boosts: 2333
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_117
---

# Description
FREE INDICATOR: VOLUME MOMENTUM

# Source Code
```pine
study(title ="TheLark Volume Momentum",overlay=false)

//•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//   
//                                             //
//          VOLUME MOMENTUM BY THELARK         //
//                 ~ 2-18-14 ~                 //
//                                             //
//                     •/•                     //
//                                             //
//    https://www.tradingview.com/u/TheLark    //
//     (please do not remove this heading)     //
//                                             //
//•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//

// 

//inputs
Length = input(14,minval=1)
atype = input(1,minval=1,maxval=3,title="1=sma, 2=ema, 3=wma")
mv = input(false, title="Multiply the volume?")
cc = input(false,title="Change color?")
//calc
avg = atype == 1 ? sma(volume,Length) : atype == 2 ? ema(volume,Length) : wma(volume,Length)
avgm = mv ? (avg - avg[Length]) * volume : (avg - avg[Length])
//plot
col = cc and avgm >= avgm[1] ? #0094FF : #FF006E
plot(avgm,style=histogram,linewidth=5,color=col)
```
