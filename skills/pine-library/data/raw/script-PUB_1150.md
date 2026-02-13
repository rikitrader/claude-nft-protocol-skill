---
id: PUB;1150
title: Multi Timeframe MACD
author: 20813
type: indicator
tags: []
boosts: 1055
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1150
---

# Description
Multi Timeframe MACD

# Source Code
```pine
study("Multi Timeframe MACD", shorttitle="MTF_MACD")
fast = input(12, title="Fastline", type=integer)
slow = input(26, title="Slowline", type=integer)
smoothing = input(9, title="Smoothing", type=integer)
src = input(close, title="Source", type=source)
show5m = input(true, title="show 5m", type=bool)
show15m = input(true, title="show 15m", type=bool)
show30m = input(true, title="show 30m", type=bool)
show1h = input(true, title="show 1h", type=bool)
show2h = input(true, title="show 2h", type=bool)
show4h = input(true, title="show 4h", type=bool)

fastMACurrent = ema(src, fast)
slowMACurrent = ema(src, slow)
macdCurrent = fastMACurrent - slowMACurrent

fastMA5m = security(ticker,"5",ema(src, fast))
slowMA5m = security(ticker,"5",ema(src, slow))
macd5m = sma(fastMA5m - slowMA5m,smoothing)

fastMA15m = security(ticker,"15",ema(src, fast))
slowMA15m = security(ticker,"15",ema(src, slow))
macd15m = sma(fastMA15m - slowMA15m,smoothing*2)

fastMA30m = security(ticker,"30",ema(src, fast))
slowMA30m = security(ticker,"30",ema(src, slow))
macd30m = sma(fastMA30m - slowMA30m,smoothing*4)

fastMA1h = security(ticker,"60",ema(src, fast))
slowMA1h = security(ticker,"60",ema(src, slow))
macd1h = sma(fastMA1h - slowMA1h,smoothing*6)

fastMA2h = security(ticker,"120",ema(src, fast))
slowMA2h = security(ticker,"120",ema(src, slow))
macd2h = sma(fastMA2h - slowMA2h,smoothing*12)

fastMA4h = security(ticker,"240",ema(src, fast))
slowMA4h = security(ticker,"240",ema(src, slow))
macd4h = sma(fastMA4h - slowMA4h,smoothing*24)

plot(macdCurrent, color=blue, title="fl current")


plot(show5m ? macd5m : na, color=interval < 5 and not isdaily and not isweekly and not ismonthly  ? #aaaaaa : na, title="MACD 5m")
plot(show15m ? macd15m : na, color=interval < 15 and not isdaily and not isweekly and not ismonthly  ? #999999 : na, title="MACD 15m")
plot(show30m ? macd30m : na, color=interval < 30 and not isdaily and not isweekly and not ismonthly  ? #888888 : na, title="MACD 30m")
plot(show1h ? macd1h : na, color=interval < 60 and not isdaily and not isweekly and not ismonthly  ? #777777 : na, title="MACD 1h")
plot(show2h ? macd2h : na, color=interval < 120 and not isdaily and not isweekly and not ismonthly  ? #666666 : na, title="MACD 2h")
plot(show4h ? macd4h : na, color=interval < 240 and not isdaily and not isweekly and not ismonthly ? #555555 : na, title="MACD 4h")
//plot(show1D ? macd1D : na, color=not isdaily and not isweekly and not ismonthly ? #444444 : na, title="MACD 1D")
```
