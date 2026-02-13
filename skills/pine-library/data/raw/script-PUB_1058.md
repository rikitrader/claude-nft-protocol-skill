---
id: PUB;1058
title: Linear regression bands
author: max007
type: indicator
tags: []
boosts: 836
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1058
---

# Description
Linear regression bands

# Source Code
```pine
// linear regression band (regression curve +/- ATR)

study(title="Linear regression band", shorttitle="LRB", overlay=true)

src = close
//Input
nlookback = input (defval = 20, minval = 1, title = "Number of Lookback")
scale = input(defval=1,  title="scale of ATR")
nATR = input(defval = 14, title="ATR Parameter")

//Linear Regression Curve
lrc = linreg(src, nlookback, 0)
lrc_u = lrc + scale*atr(nATR)
lrc_l = lrc - scale*atr(nATR)
plot(lrc, color = red, style = line, linewidth = 2)
plot(lrc_u, color = red,style = line,  linewidth = 1)
plot(lrc_l, color = red, style = line, linewidth = 1)
```
