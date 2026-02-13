---
id: PUB;1963
title: Squeeze Momentum Alert Script
author: CryptoRox
type: indicator
tags: []
boosts: 1307
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1963
---

# Description
Squeeze Momentum Alert Script

# Source Code
```pine
//original indicator created by LazyBear
//https://www.tradingview.com/script/nqQ1DT5a-Squeeze-Momentum-Indicator-LazyBear/
//
//Automate this strategy using the AutoView Chrome Extension
//https://chrome.google.com/webstore/detail/autoview/okdhadoplaoehmeldlpakhpekjcpljmb?hl=en
study(title="Sqz-Study-BTC", shorttitle = "Alerts", overlay=false)

length = input(27, title="BB Length")
mult = input(2.0,title="BB MultFactor")
lengthKC=input(19, title="KC Length")
multKC = input(1.5, title="KC MultFactor")

useTrueRange = input(true, title="Use TrueRange (KC)", type=bool)

// Calculate BB
source = close
basis = sma(source, length)
dev = multKC * stdev(source, length)
upperBB = basis + dev
lowerBB = basis - dev

// Calculate KC
ma = sma(source, lengthKC)
range = useTrueRange ? tr : (high - low)
rangema = sma(range, lengthKC)
upperKC = ma + rangema * multKC
lowerKC = ma - rangema * multKC

sqzOn  = (lowerBB > lowerKC) and (upperBB < upperKC)
sqzOff = (lowerBB < lowerKC) and (upperBB > upperKC)
noSqz  = (sqzOn == false) and (sqzOff == false)

val = linreg(source  -  avg(avg(highest(high, lengthKC), lowest(low, lengthKC)),sma(close,lengthKC)), 
            lengthKC,0)

goTime = sqzOn[1] == 1 and sqzOff == 1 or noSqz[1] == 1 and sqzOff == 1 ? 1:0

long = goTime == 1 and val > 0 and val > nz(val[1])
short = goTime == 1 and val < 0 and val < nz(val[1])

cl = val < nz(val[1]) and val[1] < nz(val[2]) ? 1:0
cs = val > nz(val[1]) and val[1] > nz(val[2]) ? 1:0

closelong = crossover(cl, 0.9)
closeshort = crossover(cs, 0.9)

plot(long, "Long", color=green)
plot(short, "Short", color=red)
plot(closelong, "CloseLong", color=aqua)
plot(closeshort, "CloseShort", color=orange)
```
