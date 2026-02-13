---
id: PUB;2923
title: DI histo + adx
author: MarcoValente
type: indicator
tags: []
boosts: 728
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2923
---

# Description
DI histo + adx

# Source Code
```pine
study("DI histo + adx",overlay=false,scale=scale.left)
len = input(title="Length", type=integer, defval=14)
th = input(title="threshold", type=integer, defval=25)

TrueRange = max(max(high-low, abs(high-nz(close[1]))), abs(low-nz(close[1])))
DirectionalMovementPlus = high-nz(high[1]) > nz(low[1])-low ? max(high-nz(high[1]), 0): 0
DirectionalMovementMinus = nz(low[1])-low > high-nz(high[1]) ? max(nz(low[1])-low, 0): 0


SmoothedTrueRange = nz(SmoothedTrueRange[1]) - (nz(SmoothedTrueRange[1])/len) + TrueRange
SmoothedDirectionalMovementPlus = nz(SmoothedDirectionalMovementPlus[1]) - (nz(SmoothedDirectionalMovementPlus[1])/len) + DirectionalMovementPlus
SmoothedDirectionalMovementMinus = nz(SmoothedDirectionalMovementMinus[1]) - (nz(SmoothedDirectionalMovementMinus[1])/len) + DirectionalMovementMinus

DIPlus = SmoothedDirectionalMovementPlus / SmoothedTrueRange * 100
DIMinus = SmoothedDirectionalMovementMinus / SmoothedTrueRange * 100
DX = abs(DIPlus-DIMinus) / (DIPlus+DIMinus)*100
ADX = sma(DX, len)
ve=DIPlus>(DIMinus+(DIPlus*10)/100)
ro=DIMinus>(DIPlus+(DIMinus*10)/100) and ADX>11 and ADX<=25
xve= DIPlus>(DIMinus+(DIPlus*10)/100) and ADX>22
xro=DIMinus>(DIPlus+(DIMinus*10)/100) and ADX>22
fl=DIPlus-DIMinus<abs(10) and ADX<15

di=25+(DIPlus-DIMinus)
//vam=sma(1.2*(ADX-ADX[len]),3)+25
//vad=(vam+2*vam[1]+2*vam[2]+vam[3])/6

cy=di>=25?lime:red
//plot(DIPlus, color=lime,linewidth=2, title="DI+")
//plot(DIMinus, color=red, linewidth=2,title="DI-")
plot(ADX, color=orange,linewidth=1,transp=0, title="ADX")
//plot(vam,title="velocita",linewidth=1,transp=50,color=lime)
plot(di,style=histogram,linewidth=4,color=cy,transp=50,histbase=25,title="DI")
hline(th, color=gray)

```
