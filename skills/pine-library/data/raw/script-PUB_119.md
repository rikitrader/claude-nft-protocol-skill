---
id: PUB;119
title: FREE INDICATOR: Laguerre Moving Average by TheLark
author: TheLark
type: indicator
tags: []
boosts: 3029
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_119
---

# Description
FREE INDICATOR: Laguerre Moving Average by TheLark

# Source Code
```pine
study(title = "TheLark: Laguerre Moving Average", shorttitle="TheLark LMA", overlay=true)

//•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//   
//                                             //
//            LAGUERRE MA BY THELARK           //
//                 ~ 2-11-14 ~                 //
//                                             //
//                     •/•                     //
//                                             //
//    https://www.tradingview.com/u/TheLark    //
//     (please do not remove this heading)     //
//                                             //
//•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•/•//

// The Laguerre Average was discovered by John Ehlers.
// It's a newer type of averaging that is meant to take out as much of the
// inherent lag that your typical EMA and SMA's give at the start of a major trend change.
// So what you get is an average that turns more quickly at major trend changes,
// and doesn't get tripped up on the noise (as much). 


//setups
h = high
l = low
//inputs
Gamma = input(0.77)
sd = input(true, title="Show dots?")
//calc
lag(g) =>
    p = (h + l)/2
    L0 = (1 - g)*p+g*nz(L0[1])
    L1 = -g*L0+nz(L0[1])+g*nz(L1[1])
    L2 = -g*L1+nz(L1[1])+g*nz(L2[1])
    L3 = -g*L2+nz(L2[1])+g*nz(L3[1])
    f = (L0 + 2*L1 + 2*L2 + L3)/6
    f
//plots
lma = lag(Gamma)
col =  lma > lma[1] ? #0094FF : #FF3571
up = lma > lma[1] ? 1 : 0
down = lma < lma[1] ? 1 : 0
plot(lma,linewidth=2,color=col)
plot(sd and cross(up,down) ? lma : na,style=circles, linewidth=4, color=col )
```
