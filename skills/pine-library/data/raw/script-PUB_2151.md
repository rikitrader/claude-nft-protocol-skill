---
id: PUB;2151
title: GC Magic(EMA/RMA) V1
author: GcNaif
type: indicator
tags: []
boosts: 595
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2151
---

# Description
GC Magic(EMA/RMA) V1

# Source Code
```pine
//@version=1
//based on Guppy method useing ema or rma
//Written by : Gc Naif
//Written on : 1/09/2015

study("GC Magic(EMA/RMA) V1", overlay = true, scale = scale.right)

//input(title="Offset", type=integer, defval=7, minval=-10, maxval=10)
Eema = input(false, title="Select to use EMA , Uncheck to use RMA: ")
ema55 = input(55,   title="Fast EMA/RMA For Cross",minval=55)
ema149= input(149,  title="Slow EMA/RMA For Cross",minval=149)


ema1= 25 ,ema2= 30 ,ema3= 35
ema4= 40 ,ema5= 45 ,ema6= 50,ema7= 55

ema8= 89 ,ema9= 99 ,ema10= 109
ema11= 119 ,ema12= 129 ,ema13= 139,ema14= 149

emaSignalHTF= input(200, title="Signal EMA/RMA ",minval=100)
resCustom = input("120",title="Time interval for Signal EMA/RMA (W, D, [min 60,120,240])", type=string)

UseSignalEMAForSignal= input(false, title="Do you want to use Signal EMA/RMA for Signals?")
ShowSignalEMAonChart = input(false, title="Show Signal EMA on Chart?")
ShowSlowGuppyonChart = input(true, title="Show Guppy-Slow-Red   On Chart?")
ShowFastGuppyonChart = input(true, title="Show Guppy-Fast-Green On Chart?")

price = close

emav1 = Eema ? ema(price,ema1) : rma(price,ema1)
emav2 = Eema ? ema(price,ema2) : rma(price,ema2)
//Eema ? ema(price,ema) : vwma(price,ema)
emav3 = Eema ? ema(price,ema3) : rma(price,ema3) 
emav4 = Eema ? ema(price,ema4) : rma(price,ema4)
emav5 = Eema ? ema(price,ema5) : rma(price,ema5)
emav6 = Eema ? ema(price,ema6) : rma(price,ema6)
emav7 = Eema ? ema(price,ema7) : rma(price,ema7)
emav8 = Eema ? ema(price,ema8) : rma(price,ema8)
emav9 = Eema ? ema(price,ema9) : rma(price,ema9)
emav10 = Eema ? ema(price,ema10) : rma(price,ema10)
emav11 = Eema ? ema(price,ema11) : rma(price,ema11)
emav12 = Eema ? ema(price,ema12) : rma(price,ema12)
emav13 = Eema ? ema(price,ema13) : rma(price,ema13)
emav14 = Eema ? ema(price,ema14) : rma(price,ema14)

emav55  = Eema ? ema(price,ema55) : rma(price,ema55)
emav149 = Eema ? ema(price,ema149) : rma(price,ema149)

// signal vma/ema
sema = Eema ? ema(price, emaSignalHTF) : rma(price, emaSignalHTF)
emaHTF = security(tickerid, resCustom, sema)


MALongCross1 = crossover(emav55,emav149)  ? 1 : 0 
MAShortCross1 = crossunder(emav55,emav149)  ? 1 : 0 

BuySignal  =  UseSignalEMAForSignal ? MALongCross1 > 0 and open[0] > emaHTF and close[0] > emaHTF : MALongCross1 > 0   and close[1] > emav55 and close > emav55    // buy signal
SellSignal =  UseSignalEMAForSignal ? MAShortCross1 > 0 and open[0] < emaHTF and close[0] < emaHTF : MAShortCross1 > 0  and close[1] < emav55 and close < emav55   // Short Signal

//BuySignal  =  UseSignalEMAForSignal ? MALongCross1 > 0 and open[0] > emaHTF and close[0] > emaHTF : MALongCross1 > 0       // buy signal
//SellSignal =  UseSignalEMAForSignal ? MAShortCross1 > 0 and open[0] < emaHTF and close[0] < emaHTF : MAShortCross1 > 0 // Short Signal

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
plot(ShowSignalEMAonChart ? emaHTF : na , color=#ff00ff, transp=0, linewidth=2)

plotshape(BuyGC, style = shape.circle,location=location.belowbar, color=black, transp=0,size = size.small)
plotshape(SellGC, style = shape.circle,location=location.abovebar, color=#ff00ff , transp=0,size = size.small)


```
