---
id: PUB;1940
title: [NM] EMADiff v01 - an indicator for everyone !
author: Profit_Through_Patience
type: indicator
tags: []
boosts: 579
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1940
---

# Description
[NM] EMADiff v01 - an indicator for everyone !

# Source Code
```pine
//@version=1
// this code uses the difference between the close of a candle and the slow EMA on one hand
// and the difference between the slow EMA and the fast EMA on the other hand
// Use : if both lines color green : buy, if both lines color red : sell
// Advice : 
// - watch price action and eventual support/resistance to try and eliminate false entries
// - use an ADX indicator in order to determine what moves are backed by momentum
// - for safer entries wait till both lines are above zero for buying, below zero for selling
// You can select to smoothen both lines by enabling it in the settings
// You can adapt the EMA settings to your likings, higher EMAs will smoothen out more and thus show less color changes


study(title='[NM] EMADiff v01', shorttitle='EMADiffv01', overlay=false)
fastEMA = input(title = 'Fast EMA (default = 12)', type = integer, defval = 12)
slowEMA = input(title = 'Slow EMA (default = 26)', type = integer, defval = 26)
smooth = input(title='Smooth ? (default = Yes)', type=bool, defval=true)
smap = input(title='Smooth factor (default = 10)', type=integer, defval=10, minval=2, maxval=20)
sigma = input(title='Sigma default = 6)', type=integer, defval=6)
safer = input(title='Show safer trades (default = yes)', type = bool, defval = true)


emadiff = ema(close,fastEMA) - ema(close,slowEMA)
emadiffp = close - ema(close,slowEMA)



ep = smooth ? alma(emadiffp, smap, 0.9, sigma) : emadiffp
ef = smooth ? alma(emadiff, smap, 0.9, sigma) : emadiff
pcolor = safer ? (ep[0] > ep[1] and ef[0] > ef[1] ? green : ep[0] < ep[1] and ef[0] < ef[1] ? red : yellow) : ep[0] > ep[1] ? green : red
fcolor = safer ? (ef[0] > ef[1] and ef[0] > 0 ? green : ef[0] < ef[1] and ef[0] < 0 ? red : yellow) : ef[0] > ef[1] ? green : red


plot(title='EMA Difference', series=ef, style=line, linewidth=2, color= fcolor)
plot(title='Difference to close', series=ep, style=line, linewidth=2, color= pcolor)
plot(0,title='zero line', color= gray, linewidth=1)



```
