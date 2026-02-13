---
id: PUB;2956
title: Stochastic RSI - MTF - Up/down colours - 4hr default - squattter
author: squattter
type: indicator
tags: []
boosts: 298
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2956
---

# Description
Stochastic RSI - MTF - Up/down colours - 4hr default - squattter

# Source Code
```pine
study(title="Stochastic RSI", shorttitle="Stoch RSI")
smoothK = input(3, minval=1)
smoothD = input(3, minval=1)
lengthRSI = input(14, minval=1)
lengthStoch = input(14, minval=1)
src = input(close, title="RSI Source")
resCustom = input(title="Timeframe", type=resolution, defval="240")
rsi1 = rsi(src, lengthRSI)
k = security(tickerid, resCustom, sma(stoch(rsi1, rsi1, rsi1, lengthStoch), smoothK))
d = security(tickerid, resCustom, sma(k, smoothD))
cClr = k > d[1] ? yellow : orange
plot(k, color=cClr, transp=0, style=circles, linewidth=3)
//plot(d, color=white, transp=0, linewidth=2)
h0 = hline(80)
h1 = hline(20)
//fill(h0, h1, color=purple, transp=80)
h2 = hline(50)






```
