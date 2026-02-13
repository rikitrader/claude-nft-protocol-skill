---
id: PUB;2842
title: Difference % between PRICE and VWAP V2
author: TheYangGuizi
type: indicator
tags: []
boosts: 1797
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2842
---

# Description
Difference % between PRICE and VWAP V2

# Source Code
```pine
//@version=2
study(title="Percent difference between price and vwap")
BarcOn=input(false, title="Color bars/Candles?")
len=input(36)
TimeFrame = input('D')
start = security(tickerid, TimeFrame, time)

newSession = iff(change(start), 1, 0)

vwapsum = iff(newSession, hl2*volume, vwapsum[1]+hl2*volume)
volumesum = iff(newSession, volume, volumesum[1]+volume)
v2sum = iff(newSession, volume*hl2*hl2, v2sum[1]+volume*hl2*hl2)
myvwap = vwapsum/volumesum


src=input(close)
xSMA = myvwap
nRes = abs(src - xSMA) * 100 / src

nRes3 = sma(nRes,len)
plot(nRes3, color=blue, style=areabr,transp=90, histbase=0, title="Average")
level1=input(1.28)
level2=input(2.1)
level3=input(2.5)
level4=input(3.09)
level5=input(4.1)
color2=nRes>level1 and nRes<level2?navy: nRes>level2 and nRes<level3?blue: nRes>level3 and nRes<level4?orange: nRes>level4 and nRes<level5?red: nRes>level5?maroon: na
color=nRes>level1 and nRes<level2?navy: nRes>level2 and nRes<level3?blue: nRes>level3 and nRes<level4?orange: nRes>level4 and nRes<level5?red: nRes>level5?maroon: gray

plot(nRes, style=histogram,color=color)
barcolor(BarcOn?color2:na)
hline(0, title="Base Line", color=aqua, linestyle=solid)
a=hline(level1, title="1", color=aqua, linestyle=dotted)
b=hline(level2, title="2", color=blue, linestyle=dotted)
c=hline(level3, title="3", color=orange, linestyle=dotted)
d=hline(level4, title="4", color=red, linestyle=dotted)
e=hline(level5, title="5", color=maroon, linestyle=dotted)
```
