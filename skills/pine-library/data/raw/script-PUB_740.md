---
id: PUB;740
title: JOS (John Oligarh Stochastic)
author: orduse
type: indicator
tags: []
boosts: 209
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_740
---

# Description
JOS (John Oligarh Stochastic)

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by JO v1.0 11/11/2014
// John Oligarh Stochastics (JOS). 
////////////////////////////////////////////////////////////
study(title="JOS (John Oligarh Stochastic)", shorttitle="JOS")
PDS = input(10, minval=1)
EMAlen = input(9, minval=1)
TriggerLen = input(5, minval=1)
Overbought = input(79, minval=1)
Overbought2 = input(87, minval=1)
Oversold = input(16, minval=1)
Oversold2 = input(25, minval=1)
hline(Overbought, color=#47A347, linestyle=dotted, linewidth=2)
hline(Overbought2, color=#47A347, linestyle=line, linewidth=1)
hline(Oversold, color=#FF6600, linestyle=line, linewidth=1)
hline(Oversold2, color=#FF8330, linestyle=dotted, linewidth=2)
xPreCalc = ema(stoch(close, high, low, PDS), EMAlen)
xDSS = ema(stoch(xPreCalc, xPreCalc, xPreCalc, PDS), EMAlen)
xTrigger = ema(xDSS, TriggerLen)
plot(xDSS, color=blue, title="JOS")
plot(xTrigger, color=red, title="Trigger")
```
