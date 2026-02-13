---
id: PUB;1388
title: RSI-Fib
author: CapnOscar
type: indicator
tags: []
boosts: 1048
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1388
---

# Description
RSI-Fib

# Source Code
```pine
//@author CapnOscar 
study(title="RSI-Fib", shorttitle="RSI-Fib")

SWperiod = input(7, minval=1, title="SWperiod")
look = input(0, minval=0, title="Shift")
OverBought = input(80, minval=50)
OverSold = input(20, maxval=50)

bandmx = hline(100)
bandmn = hline(0)

band1 = hline(OverBought)
band0 = hline(OverSold)
//band50 = hline(50, color=black, linewidth=1)
fill(band1, band0, color=purple, transp=98)


src = close, len = input(5, minval=1, title="RSI Length")
up = rma(max(change(src), 0), len)
down = rma(-min(change(src), 0), len)
rsi = down == 0 ? 100 : up == 0 ? 0 : 100 - (100 / (1 + up / down))
newrsi = sma(rsi,len)



highrsi = highest(rsi[look], SWperiod)
lowrsi = lowest(rsi[look], SWperiod)

fib618 = ((highrsi - lowrsi) *0.618)+lowrsi
fib382 = ((highrsi - lowrsi) *0.382)+lowrsi
//fibup1618 = ((highrsi - lowrsi) *1.272)+lowrsi
//fibdo1618 = highrsi-((highrsi - lowrsi) *1.272)

avgrsi = avg(highrsi,lowrsi)
pl618 = plot(fib618, color=silver)
pl382 = plot(fib382, color=silver)

fill(pl618, pl382, color=purple, transp=90)
r5mnts = security(tickerid, "5", rsi)
rpl = plot(r5mnts, color=purple)

colcol = rising(rsi,1) and rsi > fib382 ? blue : falling(rsi,1) and rsi < fib618 ? red : black
//trsi = plot(rsi, color=colcol, linewidth=1)


short = rsi >= OverBought ?  95 : na
plotshape(short, style=shape.triangledown, location=location.absolute, color=red, transp= 0)

long = rsi <= OverSold ?  5 : na
plotshape(long, style=shape.triangleup, location=location.absolute,  color=green, transp= 0)

```
