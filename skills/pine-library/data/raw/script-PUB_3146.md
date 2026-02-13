---
id: PUB;3146
title: MTF Stochastic CCI ALERT
author: squattter
type: indicator
tags: []
boosts: 333
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3146
---

# Description
MTF Stochastic CCI ALERT

# Source Code
```pine
study(title="MTF Stochastic CCI ALERT", shorttitle="Stoch CCI ALERT")
smoothK = input(3, minval=1)
smoothD = input(3, minval=1)
lengthRSI = input(14, minval=1)
lengthStoch = input(14, minval=1)
src = input(close, title="RSI Source")
resCustom = input(title="Timeframe", defval="120")
rsi1 = cci(src, lengthRSI)
k = security(tickerid, resCustom, sma(stoch(rsi1, rsi1, rsi1, lengthStoch), smoothK))
d = security(tickerid, resCustom, sma(k, smoothD))



short = crossunder(k,d)
long = crossover(k,d)
las = crossover(k,d) or crossunder(k,d)

plot(long, "Long", color=white, transp=0, linewidth=2) 
plot(short, "Short", color=red, transp=0, linewidth=2)
plot(las, "Long and Short", transp=100)



```
