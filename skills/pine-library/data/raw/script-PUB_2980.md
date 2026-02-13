---
id: PUB;2980
title: MACD Zero Lag
author: yassotreyo
type: indicator
tags: []
boosts: 1361
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2980
---

# Description
MACD Zero Lag

# Source Code
```pine
// MACD 0 Lag
// @yassotreyo
study(title="MACD 0 Lag", shorttitle="MACD 0 Lag")
source = close
fastLength = input(12, minval=1)
slowLength=input(26,minval=1)
signalLength=input(9,minval=1)

// FAST LINE
ema1= ema(source, fastLength)
ema2 = ema(ema1,fastLength)
differenceFast = ema1 - ema2
zerolagEMA = ema1 + differenceFast
demaFast = (2 * ema1) - ema2

// SLOW LINE
emas1= ema(source , slowLength)
emas2 = ema(emas1 , slowLength)
differenceSlow = emas1 - emas2
zerolagslowMA = emas1 + differenceSlow
demaSlow = (2 * emas1) - emas2

//MACD LINE
ZeroLagMACD = demaFast - demaSlow

//SIGNAL LINE
emasig1 = ema(ZeroLagMACD, signalLength)
emasig2 = ema(emasig1, signalLength)
signal = (2 * emasig1) - emasig2

hist = ZeroLagMACD -signal
cHist = hist > 0 ? lime : red
plot(hist, title="histogram", style=histogram, color = cHist, linewidth = 10)
signalLine=plot(signal, title="signal", color=red ,linewidth = 1)
zlLine = plot(ZeroLagMACD, title="MACD 0 Lag", color=blue)
cDif = hist > 0 ? blue : red
fill(zlLine, signalLine, color=cDif)



```
