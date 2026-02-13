---
id: PUB;2126
title: GC Magic Overlay V2
author: GcNaif
type: indicator
tags: []
boosts: 710
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2126
---

# Description
GC Magic Overlay V2

# Source Code
```pine
//@version=1
//based on Guppy method
//Written by : Gc Naif
//Written on : 12/31/2015

study("GC Magic Overlay V2", overlay = true, scale = scale.right)

//input(title="Offset", type=integer, defval=7, minval=-10, maxval=10)

ema55 = input(55,  title="EMA 1",minval=55)
ema149= input(149,  title="EMA 2",minval=149)
emaSignalHTF= input(200, title="Signal EMA ",minval=200)
resCustom = input(title="Time interval for Signal EMA (W, D, [min 60,120,240])", type=string, defval="240")
ShowSlowGuppyonChart = input(true, title="Show Guppy-Slow-Red   On Chart?")
ShowFastGuppyonChart = input(true, title="Show Guppy-Fast-Green On Chart?")


price = close
emav1 = ema(price,25)
emav2 = ema(price,30)
emav3 = ema(price,35)
emav4 = ema(price,40)
emav5 = ema(price,45)
emav6 = ema(price,50)
emav7 = ema(price,55)
emav8 = ema(price,89)
emav9 = ema(price,99)
emav10 = ema(price,109)
emav11 = ema(price,119)
emav12 = ema(price,129)
emav13 = ema(price,139)
emav14 = ema(price,149)

emav55  = ema(price,ema55)
emav149 = ema(price,ema149)


emaHTF = security(tickerid, resCustom, ema(price, emaSignalHTF))


MALongCross1 = crossover(emav55,emav149)  ? 1 : 0 
MAShortCross1 = crossunder(emav55,emav149)  ? 1 : 0 

BuySignal  = MALongCross1 > 0 and open[0] > emaHTF and close[0] > emaHTF      // buy signal
SellSignal = MAShortCross1 > 0 and open[0] < emaHTF and close[0] < emaHTF     // Short Signal

BuyGC  = BuySignal == 1
SellGC = SellSignal == 1

//plot only if guppy is checked
plot(ShowFastGuppyonChart ? emav55 : na , color=green, transp=0, linewidth=1)
plot(ShowSlowGuppyonChart ? emav149 : na, color=red, transp=0, linewidth=1)

//fast
plot(ShowFastGuppyonChart ? emav1 : na , color=green, transp=0, linewidth=1)
plot(ShowFastGuppyonChart ? emav2 : na , color=green, transp=0, linewidth=1)
plot(ShowFastGuppyonChart ? emav3 : na , color=green, transp=0, linewidth=1)
plot(ShowFastGuppyonChart ? emav4 : na , color=green, transp=0, linewidth=1)
plot(ShowFastGuppyonChart ? emav5 : na , color=green, transp=0, linewidth=1)
plot(ShowFastGuppyonChart ? emav6 : na , color=green, transp=0, linewidth=1)
// slow
plot(ShowSlowGuppyonChart ? emav8 : na ,  color=red, transp=0, linewidth=1)
plot(ShowSlowGuppyonChart ? emav9 : na ,  color=red, transp=0, linewidth=1)
plot(ShowSlowGuppyonChart ? emav10 : na , color=red, transp=0, linewidth=1)
plot(ShowSlowGuppyonChart ? emav11 : na , color=red, transp=0, linewidth=1)
plot(ShowSlowGuppyonChart ? emav12 : na , color=red, transp=0, linewidth=1)
plot(ShowSlowGuppyonChart ? emav13 : na , color=red, transp=0, linewidth=1)
plot(emaHTF, color=#ff00ff, transp=0, linewidth=2)

plotshape(BuyGC, style = shape.circle,location=location.belowbar, color=black, transp=0,size = size.small)
plotshape(SellGC, style = shape.circle,location=location.abovebar, color=#ff00ff , transp=0,size = size.small)


```
