---
id: PUB;518
title: Relative Momentum Index
author: HPotter
type: indicator
tags: []
boosts: 426
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_518
---

# Description
Relative Momentum Index

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 05/09/2014
// The Relative Momentum Index (RMI) was developed by Roger Altman. Impressed 
// with the Relative Strength Index's sensitivity to the number of look-back 
// periods, yet frustrated with it's inconsistent oscillation between defined 
// overbought and oversold levels, Mr. Altman added a momentum component to the RSI.
// As mentioned, the RMI is a variation of the RSI indicator. Instead of counting 
// up and down days from close to close as the RSI does, the RMI counts up and down 
// days from the close relative to the close x-days ago where x is not necessarily 
// 1 as required by the RSI). So as the name of the indicator reflects, "momentum" is 
// substituted for "strength".    
////////////////////////////////////////////////////////////
study(title="Relative Momentum Index", shorttitle="RMI")
xPrice = close
Length = input(20, minval=1)
BuyZone = input(40, minval=1)
SellZone = input(70, minval=1)
hline(0, color=gray, linestyle=dashed)
hline(SellZone, color=red, linestyle=line)
hline(BuyZone, color=green, linestyle=line)
xMom = xPrice - xPrice[Length]
xMU = iff(xMom >= 0, nz(xMU[1], 1) - (nz(xMU[1],1) / Length) + xMom, nz(xMU[1], 1))
xMD = iff(xMom <= 0, nz(xMD[1], 1) - (nz(xMD[1],1) / Length) + abs(xMom), nz(xMD[1], 0))
RM = xMU / xMD
nRes = 100 * (RM / (1+RM))
plot(nRes, color=blue, title="RMI")

```
