---
id: PUB;2735
title: Yacine MA Bands Mod
author: TheYangGuizi
type: indicator
tags: []
boosts: 1051
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2735
---

# Description
Yacine MA Bands Mod

# Source Code
```pine
study(title="Yacine Ema Bands Mod", shorttitle="MA Bands", overlay=true)
src = close
len = input(125, minval=1, title = "EMA Length")
atrlen = input(500, minval=1, title = "ATR Length")
mult1 = input(3.2, minval=1, title = "Deviation multiplier 1")
mult2 = input(6.4, minval=1, title = "Deviation multiplier 2")
mult3 = input(9.5, minval=1, title = "Deviation multiplier 3")

range =  tr
//-----------------------------------------------
factorT3 = input(defval=7, title="Tilson T3 Factor - *.10 - so 7 = .7 etc.", minval=0) 
atype = input(1,minval=1,maxval=9,title="1=SMA, 2=EMA, 3=WMA, 4=HullMA, 5=VWMA, 6=RMA, 7=TEMA, 8=ZeroLagEma, 9=Tilson T3")
//hull ma definition
hullma = wma(2*wma(src, len/2)-wma(src, len), round(sqrt(len)))
//TEMA definition
ema1 = ema(src, len)
ema2 = ema(ema1, len)
ema3 = ema(ema2, len)
tema = 3 * (ema1 - ema2) + ema3

//hull ma definition B
hullmab = wma(2*wma(range, atrlen/2)-wma(range, atrlen), round(sqrt(len)))
//TEMA definition B
ema1b = ema(range, atrlen)
ema2b = ema(ema1b, len)
ema3b = ema(ema2b, len)
temab = 3 * (ema1b - ema2b) + ema3b
//Tilson T3
factor = factorT3 *.10
gd(src, len, factor) => ema(src, len) * (1 + factor) - ema(ema(src, len), len) * factor 
t3(src, len, factor) => gd(gd(gd(src, len, factor), len, factor), len, factor) 
tilT3 = t3(src, len, factor) 
 
//Tilson T3 B
factorb = factorT3 *.10
gdb(src, len, factor) => ema(src, len) * (1 + factor) - ema(ema(src, len), len) * factor 
t3b(src, len, factor) => gd(gd(gd(src, len, factor), len, factor), len, factor) 
tilT3b = t3(range, atrlen, factor) 

//ZeroLag by LazyBear
ema1z=ema(src, len)
ema2z=ema(ema1z, len)
d=ema1z-ema2z
zlema=ema1z+d
//ZeroLag by LazyBearB
ema1zB=ema(range, atrlen)
ema2zB=ema(ema1zB, len)
dB=ema1zB-ema2zB
zlemab=ema1zB+dB

avg = atype == 1 ? sma(src,len) : atype == 2 ? ema(src,len) : atype == 3 ? wma(src,len) : atype == 4 ? hullma : atype == 5 ? vwma(src, len) : atype == 6 ? rma(src,len) : atype == 7 ? tema :atype == 8 ? zlema: tilT3

avg2 = atype == 1 ? sma(range, atrlen) : atype == 2 ? ema(range, atrlen) : atype == 3 ? wma(range, atrlen) : atype == 4 ? hullmab : atype == 5 ? vwma(range, atrlen) : atype == 6 ? rma(range, atrlen) : atype == 7 ? temab : atype == 8 ? zlemab: tilT3b

//----------------------------------------------- blah bleh

ma = avg

rangema = avg2

up1 = ma + rangema * mult1
up2 = ma + rangema * mult2
up3 = ma + rangema * mult3

dn1 = ma - rangema * mult1
dn2 = ma - rangema * mult2
dn3 = ma - rangema * mult3

middle = plot(ma, color=black)

color1 = gray
color2 = black
color3 = red

//plot(up1, color = color1)
//plot(up2, color = color1)
//plot(up3, color = color1)
u4 = plot(up1, color = color1)
//plot(up5, color = color2)
//plot(up6, color = color2)
//plot(up7, color = color2)
u8 = plot(up2, color = color2)
//plot(up9, color = color3)
//plot(up10, color = color3)
//plot(up11, color = color3)
u12 = plot(up3, color = color3)

//plot(dn1, color = color1)
//plot(dn2, color = color1)
//plot(dn3, color = color1)
d4 = plot(dn1, color = color1)
//plot(dn5, color = color2)
//plot(dn6, color = color2)
//plot(dn7, color = color2)
d8 = plot(dn2, color = color2)
//plot(dn9, color = color3)
//plot(dn10, color = color3)
//plot(dn11, color = color3)
d12 = plot(dn3, color = color3)

fill(middle, u4, color=gray, transp=90, title="Middle Lower Fill")
fill(middle, d4, color=gray, transp=90, title="Middle Lower Fill")
fill(d4, d8, color=green, transp=90, title="Over Sold Fill")
fill(d8, d12, color=green, transp=90, title="Over Sold Fill Down")
fill(u4, u8, color=red, transp=90, title="Over Bought Fill")
fill(u8, u12, color=red, transp=90, title="Over Bought Fill Up")

```
