---
id: PUB;1157
title: Wave Channel 3D 
author: QuantitativeExhaustion
type: indicator
tags: []
boosts: 1005
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1157
---

# Description
Wave Channel 3D 

# Source Code
```pine
study(title="3D-Wave Channel", shorttitle="3D-WC", overlay=true)
timespace = input(1)
smooth = input(89)
offsetMultiplier=input(8)
useDonchianAverage = input(false)
src = input(ohlc4)
ma = useDonchianAverage ? avg(highest(smooth),lowest(smooth)) : ema(src, smooth)
plot(ma[0], color=black, offset=offsetMultiplier*01)
plot(ma[timespace*01], color=silver, offset=offsetMultiplier*02)
plot(ma[timespace*02], color=silver, offset=offsetMultiplier*03)
plot(ma[timespace*03], color=gray, offset=offsetMultiplier*04)
plot(ma[timespace*04], color=gray, offset=offsetMultiplier*05)
plot(ma[timespace*05], color=gray, offset=offsetMultiplier*06)
plot(ma[timespace*06], color=silver, offset=offsetMultiplier*07)
plot(ma[timespace*07], color=silver, offset=offsetMultiplier*08)
plot(ma[timespace*08], color=gray, offset=offsetMultiplier*09)
plot(ma[timespace*09], color=gray, offset=offsetMultiplier*10)
plot(ma[timespace*10], color=black, offset=offsetMultiplier*11)

max_ma()=>max(ma[timespace*10],max(ma[timespace*9],max(ma[timespace*8],max(ma[timespace*7],max(ma[timespace*6],max(ma[timespace*5],max(ma[timespace*4],max(ma[timespace*3],max(ma[timespace*2],max(ma[timespace*1], ma))))))))))
min_ma()=>min(ma[timespace*10],min(ma[timespace*9],min(ma[timespace*8],min(ma[timespace*7],min(ma[timespace*6],min(ma[timespace*5],min(ma[timespace*4],min(ma[timespace*3],min(ma[timespace*2],min(ma[timespace*1], ma))))))))))

top = highest(max_ma(), smooth)
bot = lowest(min_ma(), smooth)

plot(top, color=black, offset=offsetMultiplier)
plot(bot, color=black, offset=offsetMultiplier)
```
