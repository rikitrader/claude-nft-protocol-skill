---
id: PUB;2478
title: BUY & SELL PRESSURE by Regression
author: xel_arjona
type: indicator
tags: []
boosts: 241
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2478
---

# Description
BUY & SELL PRESSURE by Regression

# Source Code
```pine
//@version=2
study("BUY & SELL PRESSURE by Regression", shorttitle="BSPbR",overlay=false,precision=2)
so = input(title="Buy&Sell Pressure Oscillator:", defval=true)
p  = input(title="Lookback Window:", defval=9)
tev = input(title="Use External Volume?:", defval=false)
evt = input(title="External Volume Ticker:", type=symbol, defval="TVOL")
// Fixed Variables
volsym = tev ? evt : tickerid
vol = nz(security(volsym,period,volume),security(volsym,period,close))
V = vol == 0 ? 1 : nz(vol,1)
C = close
H = high
L = low
// // Karthik Marar's XeL Rate Of Change MoD (Regressional)
Hi  = max(H,C[1])
Lo  = min(L,C[1])
SP  = ((Hi-C)/C)*100
BP  = ((C-Lo)/Lo)*100
BPs = sum(BP,p)
SPs = sum(SP,p)
BPa = ema(BP,p)
SPa = ema(SP,p)
BPn = (BP/BPa)*10
SPn = (SP/SPa)*10
//BSPd = BPn - SPn
Va = ema(V,p)
Vn = V/Va
BPo = linreg(BPn * Vn,9,0)//linreg(BPn*Vn,9,0)//
SPo = linreg(SPn * Vn,9,0)//linreg(SPn*Vn,9,0)//
BSPh = BPo - SPo
// Plot Directives
HCol = BPo > SPo ? green : red
_1os = SPo > BPo ? SPo : BPo
_2os = BPo > SPo ? BPo : SPo
plot(so?_1os:na,color=HCol,style=columns,transp=81,title="SP")
plot(so?_2os:na,color=HCol,style=columns,transp=81,title="BP")
plot(so?SPo:na,color=red,style=line,transp=0,title="SP",editable=false)
plot(so?BPo:na,color=green,style=line,transp=0,title="BP",editable=false)
plot(so?na:BPs,color=green,style=columns,transp=55,title="BProc")
plot(so?na:-SPs,color=red,style=columns,transp=55,title="SProc")
//plot(so?na:BPs-SPs,color=HCol,style=line,linewidth=3,transp=0,title="Forze")
```
