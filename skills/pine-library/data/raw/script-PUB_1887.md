---
id: PUB;1887
title: Binary option 1 minute
author: Maxim_Chechel
type: indicator
tags: []
boosts: 1728
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1887
---

# Description
Binary option 1 minute

# Source Code
```pine
study(title="Stochastic RSI", shorttitle="Stoch RSI", overlay = true)
Per = input(5, title="Length", minval=1)
smoothK = input(3, minval=1)
smoothD = input(3, minval=1)
lengthRSI = input(14, minval=1)
lengthStoch = input(14, minval=1)
src = input(close, title="RSI Source")

rsi1 = rsi(src, lengthRSI)
K = sma(stoch(rsi1, rsi1, rsi1, lengthStoch), smoothK)
D = sma(K, smoothD)


rvi = sum(swma(close-open), Per)/sum(swma(high-low),Per)
sig = swma(rvi)
//plot(rvi, color=green, title="RVI")
//plot(sig, color=red, title="Signal")

//plot(K,  title="K")
//plot(D,  title="D")
Dn = K <= D  and K > 70 and rvi <= sig  and rvi[1] >= sig[1]
Up= K >= D  and K < 30 and rvi >= sig  and rvi[1] <= sig[1]
ARROW =  Up - Dn
plotarrow(ARROW, title="Down Arrow",  colordown=red, transp=0, maxheight=10, minheight=10)
plotarrow(ARROW, title="Up Arrow", colorup=lime,  transp=0, maxheight=10, minheight=10)





```
