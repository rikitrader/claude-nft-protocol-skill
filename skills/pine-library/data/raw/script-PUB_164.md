---
id: PUB;164
title: Indicator: Premier Stochastic Oscillator
author: LazyBear
type: indicator
tags: []
boosts: 4360
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_164
---

# Description
Indicator: Premier Stochastic Oscillator

# Source Code
```pine
//
// @author LazyBear
//
study("Premier Stochastic Oscillator [LazyBear]", shorttitle="PSO_LB")
stochlen = input(8, title="Stoch length")
smoothlen = input(25, title="Smooth length")
sk = stoch( close, high, low, stochlen)
len = round(sqrt( smoothlen ))
nsk = 0.1 * ( sk - 50 )
ss = ema( ema( nsk, len ), len )
expss = exp( ss )
pso = ( expss - 1 )/( expss + 1 )
plot( pso, title="Premier Stoch", color=black, linewidth=2 )
plot( pso, color=iff( pso < 0, red, blue ), style=histogram )
plot(0, color=gray)
plot( 0.2, color=blue, style=3 )
plot( 0.9, color=blue)
plot( -0.2, color=red, style=3)
plot( -0.9, color=red )
```
