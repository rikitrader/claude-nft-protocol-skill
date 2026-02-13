---
id: PUB;723
title: CM ATR Stops/Bands - Multi-TimeFrame
author: ChrisMoody
type: indicator
tags: []
boosts: 1903
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_723
---

# Description
CM ATR Stops/Bands - Multi-TimeFrame

# Source Code
```pine
//Created By ChrisMoody on 11-20-2014

study(title="CM_MTF_AverageTrueRange_Stops", shorttitle="CM_MTF_ATR_Stops", overlay=true)
length = input(5, minval=1, title="# of Bars to Calculate ATR")
mult = input(15, minval=1, maxval=40, title="Value X .1, 10=1 (No Multiplier), 15=1.5 times ATR Value")
sav = input(true, title="Show ATR Stop Above Price")
sbv = input(true, title="Show ATR Stop Below Price")
useCurrentRes = input(true, title="Use Current Chart Resolution?")
resCustom = input(title="Use Different Timeframe? Uncheck Box Above", type=resolution, defval="D")
//Optional 2nd ATR Bands Inputs
def = input(false, title="Optional 2nd ATR Bands - Inputs Below?")
length2 = input(5, minval=1, title="# of Bars to Calculate ATR - Optional 2nd Bands Plot")
mult2 = input(30, minval=1, maxval=40, title="Value X .1, 10=1 (No Multiplier), 15=1.5 times ATR Value - Optional 2nd ATR Bands Plot")
sav2 = input(false, title="Show ATR Stop Above Price - Optional 2nd ATR Bands Plot")
sbv2 = input(false, title="Show ATR Stop Below Price - Optional 2nd ATR Bands Plot")
useCurrentRes2 = input(true, title="Use Current Chart Resolution - Optional 2nd ATR Bands Plot?")
resCustom2 = input(title="Use Different Timeframe - Optional 2nd Bands Plot? Uncheck Box Above", type=resolution, defval="D")

res = useCurrentRes ? period : resCustom
res2 = useCurrentRes2 ? period : resCustom2

//Multiplier Calculation
Xmult = mult * .1
//Optional 2nd Bands
Xmult2 = mult2 * .1

//ATR Calculation with Multiplier
atrMult = sma(tr, length) * Xmult
outATR = security(tickerid, res, atrMult)
//Optional 2nd Bands
atrMult2 = sma(tr, length2) * Xmult2
outATR2 = security(tickerid, res2, atrMult2)

//Values Above and Below Bars
aboveStop = high + outATR
belowStop = low - outATR
//Optional 2nd Bands
aboveStop2 = high + outATR2
belowStop2 = low - outATR2

///Values Plotting chosen Chart Resolution
aboveFinal = security(tickerid, res, aboveStop)
belowFinal = security(tickerid, res, belowStop)
//Optional 2nd Bands
aboveFinal2 = security(tickerid, res2, aboveStop2)
belowFinal2 = security(tickerid, res2, belowStop2)

//plot Statements
p1=plot(sav and aboveFinal ? aboveFinal : na, title="1st ATR Band Upper Plot1", style=linebr, linewidth=3, color=red)
p2=plot(sbv and belowFinal ? belowFinal : na, title="1st ATR Band Lower Plot1", style=linebr, linewidth=3, color=lime)
plot(sav and aboveFinal ? aboveFinal : na, title="1st ATR Band Upper Plot2", style=circles, linewidth=3, color=red)
plot(sbv and belowFinal ? belowFinal : na, title="1st ATR Band Lower Plot2", style=circles, linewidth=3, color=lime)
//Optional 2nd Bands
p3=plot(sav2 and aboveFinal2 ? aboveFinal2 : na, title="2nd ATR Band Upper Plot1", style=linebr, linewidth=4, color=red)
p4=plot(sbv2 and belowFinal2 ? belowFinal2 : na, title="2nd ATR Band Lower Plot1", style=linebr, linewidth=4, color=lime)
plot(sav2 and aboveFinal2 ? aboveFinal2 : na, title="2nd ATR Band Upper Plot2",  style=circles, linewidth=4, color=red)
plot(sbv2 and belowFinal2 ? belowFinal2 : na, title="2nd ATR Band Lower Plot2", style=circles, linewidth=4, color=lime)
fill(p1, p3, color=red, transp=80)
fill(p2, p4, color=lime, transp=80)
```
