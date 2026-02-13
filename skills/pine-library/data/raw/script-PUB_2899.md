---
id: PUB;2899
title: I_Heikin Ashi Candle
author: samtsui
type: indicator
tags: []
boosts: 1568
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2899
---

# Description
I_Heikin Ashi Candle

# Source Code
```pine
//@version=2
// Note:
//   if you only want to see the Heikin Ashi Candle but not the normal Candle,
//   change the overlay option to overlay=true, then hide the normal Candle
study("I_Heikin Ashi Candle", shorttitle="I_HA Candle", overlay=false)


// --------------- Calculating HA Candle's values
//  -- you can use either one of the methods below, they give the same values

//   Method 1 - calculate the HA candle's value by formula
haclose = (open + high + low + close) / 4
haopen = na(haopen[1]) ? (open + close) / 2 : (haopen[1] + haclose[1]) / 2
hahigh = max(high, max(haopen, haclose))
halow = min(low, min(haopen, haclose))

//   Method 2 - calculate the HA candle's value by pine script function heikinashi()
// haclose = security(heikinashi(tickerid), period, close)
// haopen = security(heikinashi(tickerid), period, open)
// hahigh = security(heikinashi(tickerid), period, high)
// halow = security(heikinashi(tickerid), period, low)



// --------------- Using HA Candle's values to define indicators

// then use the haclose, haopen, hahigh, halow to calculate whatever indicators you want:
// e.g.

// 1. stochastic
// k = sma(stoch(haclose, hahigh, halow, 14), 3)
// d = sma(k, 3)

// 2. sma
// sma14 = sma(haclose, 14)

// 3. ema
// ema14 = ema(haclose, 14)

// --------------- Plotting
plotcandle(haopen, hahigh, halow, haclose, title='Heikin-Ashi', color=(haopen < haclose) ? green : red, wickcolor=gray)
// END
```
