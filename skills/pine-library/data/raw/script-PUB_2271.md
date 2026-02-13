---
id: PUB;2271
title: Stefan Krecher: Jeddingen Divergence
author: TradingClue
type: indicator
tags: []
boosts: 428
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2271
---

# Description
Stefan Krecher: Jeddingen Divergence

# Source Code
```pine
//@version=2
study(title="Stefan Krecher: Jeddingen Divergence", shorttitle="Jeddingen Divergence", overlay=true)
candles = input(title="Number of candles that need to diverge", type=integer, defval=5, minval=3, maxval=10)
linregPrice = input(title="price related linear regression length", type=integer, defval=20, minval=5, maxval=50)
momLength = input(title="momentum length", type=integer, defval=10, minval=2, maxval=50)

jeddingen(series) => ((falling(series, candles)) and (rising(mom(series, momLength),candles))) or ((rising(series, candles)) and (falling(mom(series, momLength),candles)))

srcDiv = close
lrDiv = linreg(srcDiv, linregPrice, 0)

lrDivColor =if(jeddingen(lrDiv) == true)
    rising(lrDiv, candles) ? red:green
else
    na
plot(lrDiv)
plot(lrDiv, color=lrDivColor, linewidth=4)
```
