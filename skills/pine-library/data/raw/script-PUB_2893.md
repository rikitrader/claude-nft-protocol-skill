---
id: PUB;2893
title: Stochastic CCI MTF w/ UP/DOWN colours - squattter
author: squattter
type: indicator
tags: []
boosts: 867
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2893
---

# Description
Stochastic CCI MTF w/ UP/DOWN colours - squattter

# Source Code
```pine
study(title="Stochastic CCI MTF w/ UP/DOWN colours - squattter")
smoothK = input(3, minval=1)
smoothD = input(3, minval=1)
lengthRSI = input(14, minval=1, title="CCI Length")
lengthStoch = input(14, minval=1, title="Stoch Length")
src = input(close, title="RSI Source")
useCurrentRes = input(true, title="Use Current Chart's Timeframe?")
resCustom = input(title="Timeframe", type=resolution, defval="480")
res = useCurrentRes ? period : resCustom

rsi1 = cci(src, lengthRSI)
k = security(tickerid, res, sma(stoch(rsi1, rsi1, rsi1, lengthStoch), smoothK))
d = security(tickerid, res, sma(k, smoothD))
cClr = k > d[1] ? aqua : red
plot(k, color=cClr, linewidth=3, transp=0, title="K")
plot(d, color=white, transp=0, title="D")
h0 = hline(80)
h1 = hline(20)
fill(h0, h1, color=purple, transp=90)
h2 = hline(50, linewidth=1, color=red)
```
