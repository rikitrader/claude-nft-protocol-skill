---
id: PUB;1904
title: Stochastic In Bands
author: CapnOscar
type: indicator
tags: []
boosts: 389
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1904
---

# Description
Stochastic In Bands

# Source Code
```pine
study(title="Stochastic In Bands", shorttitle="SIB", overlay=true)
ATRlength = input(14, minval=1)
ATRMult = input(2.70, minval=1)
ATRBase = input(3.50, minval=1)
ATR = rma(tr(true), ATRlength)

len = input(21, minval=1, title="Length")
src = input(close, title="Source")
out = ema(src, len)

emaup = out+(ATR*ATRMult)
emadw = out-(ATR*ATRMult)
emabs = out-(ATR*ATRBase)
plot(out, title="EMA", color=orange)
plot(emaup, title="EMAUP", color=silver)
plot(emadw, title="EMADW", color=silver)

Stlength = input(14, minval=1), smoothK = input(5, minval=1), smoothD = input(3, minval=1)
k = sma(stoch(close, high, low, Stlength), smoothK)
d = sma(k, smoothD)

MDiff = emaup-emadw
StM = emabs+((k*MDiff)/80)
StS = emabs+((d*MDiff)/80)
plot(StM, title="Main", color=red)
plot(StS, title="Signal", color=blue)





```
