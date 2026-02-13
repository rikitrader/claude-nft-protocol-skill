---
id: PUB;206
title: TRIX MA
author: munkeefonix
type: indicator
tags: []
boosts: 1100
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_206
---

# Description
TRIX MA

# Source Code
```pine
study("TRIX Moving Average", shorttitle="TRIX MA")
//  Trix with a EMA or SMA. 
//
//  @author munkeefonix
//  https://www.tradingview.com/u/munkeefonix/
//
//  inputs:
//  Length: Length of the Trix
//  Use Ema: Use an ema or sma.
//  Moving Average: Moving Average used on the TRIX Value.
//  Histogram Multiplier: Exaggerate  the difference between the TRIX and Moving Average.

_length=input(15, title="TRIX Length", minval=1)
_useEma=input(true, type=bool, title="Use Ema")
_ma=input(9, title="Moving Average", minval=1)
_mult=input(2.0, type=float, minval=1, title="Histogram Multiplier")

tema(a, b)=>ema(ema(ema(a, b), b), b)
trix(a)=>((a-a[1]) / a[1]) * 10000

_trix=trix(tema(close, _length))
_trixs=_useEma ? ema(_trix, _ma) : sma(_trix, _ma)
_trixh=(_trix-_trixs)

hline(0, color=#000000, title="Zero Line")

plot(_trixh * _mult, color=#000000, style=area, transp=80, title="Histogram")
plot(_trix, color=#FFCC00, title="TRIX")
plot(_trixs, color=#CC0000, title="TRIX Moving Average")
plot(cross(_trix, _trixs) ? _trix : na, color=white, style=cross, linewidth=2, title="TRIX Moving Average")

```
