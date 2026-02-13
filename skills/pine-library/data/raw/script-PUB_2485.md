---
id: PUB;2485
title: BUY & SELL PRESSURE XeLMod V2
author: xel_arjona
type: indicator
tags: []
boosts: 486
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2485
---

# Description
BUY & SELL PRESSURE XeLMod V2

# Source Code
```pine
//@version=2
study("BUY & SELL PRESSURE by Regression", shorttitle="BSPbR",overlay=false,precision=2)
so = input(title="Buy&Sell Pressure Oscillator:", defval=true)
p  = input(title="Lookback Window:", defval=81)
tev = input(title="Use External Volume?:", defval=false)
evt = input(title="External Volume Ticker:", type=symbol, defval="TVOL")
// Fixed Variables
volsym = tev ? evt : tickerid
vol = nz(security(volsym,period,volume),security(volsym,period,close))
V = vol == 0 ? 1 : nz(vol,1)
C = close
H = high
L = low
Hi  = max(H,C[1])
Lo  = min(L,C[1])
// XeL Rate Of Change MoD (Regressional)
SProc = abs((Hi-C)/Hi)
BProc = abs((C-Lo)/Lo)
SPprc = Hi-C
BPprc = C-Lo
BPs = sum(BProc,p)
SPs = sum(SProc,p)
BPa = sma(BProc,p)
BPap = sma(BPprc,p)
SPa = sma(SProc,p)
SPap = sma(SPprc,p)
BPn = (BProc/BPa)*12
SPn = (SProc/SPa)*12
BPnp = (BPprc/BPap)*12
SPnp = (SPprc/SPap)*12
Va = sma(V,55)
Vn = V/Va
BPo = linreg(BPn * Vn,9,0)
SPo = linreg(SPn * Vn,9,0)
nbf = sma(BPnp * Vn,9)
nsf = sma(SPnp * Vn,9)
regH = (BPo-SPo)
// Plot Directives
OCol = BPo > SPo ? blue : fuchsia
_1hs = BPs > SPs ? BPs : -BPs
_2hs = SPs > BPs ? SPs : -SPs
plot(so?regH:na,color=OCol,style=columns,transp=81,title="RegForce")
plot(so?na:_1hs,color=green,style=columns,transp=72,title="BProc")
plot(so?na:_2hs,color=red,style=columns,transp=72,title="SProc")
plot(so?nbf:na,color=green,style=line,transp=0,title="BPprice")
plot(so?nsf:na,color=red,style=line,transp=0,title="SPprice")
```
