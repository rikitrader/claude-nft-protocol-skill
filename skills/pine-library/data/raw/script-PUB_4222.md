---
id: PUB;4222
title: Three EMA Crossover Trading Strategy
author: peopleisliking
type: indicator
tags: []
boosts: 749
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_4222
---

# Description
Three EMA Crossover Trading Strategy

# Source Code
```pine
study("Three EMA Crossover Trading Strategy",overlay=true)
 
LowestPeriod = input(title="Lowest Period",type=integer,defval=10)
MediumPeriod = input(title="Medium Period",type=integer,defval=25)
LongestPeriod = input(title="Longest Period",type=integer,defval=50)
 


LowestEMA = ema(close,LowestPeriod)
MediumEMA = ema(close,MediumPeriod)
LongestEMA = ema(close,LongestPeriod)


LEColor = LowestEMA > LowestEMA[1] ? green : red
MEColor = MediumEMA > MediumEMA[1] ? lime : maroon
LLEColor = LongestEMA > LongestEMA[1] ? gray : purple


plot( LowestEMA, color= LEColor , title="Lowest EMA", trackprice=false, style=line)
plot( MediumEMA ,color= MEColor , title="Medium EMA", trackprice=false, style=line)
plot( LongestEMA , color= LLEColor , title="Longest EMA", trackprice=false, style=line)

//plotshape(cross(close,Tsl) and close>Tsl , "Up Arrow", shape.triangleup,location.belowbar,green,0,0)
//plotshape(cross(Tsl,close) and close<Tsl , "Down Arrow", shape.triangledown , location.abovebar, red,0,0)
//plot(Trend==1 and Trend[1]==-1,color = linecolor, style = circles, linewidth = 3,title="Trend")
Trend = LowestEMA > MediumEMA and LowestEMA > LongestEMA ? 1 : LowestEMA < MediumEMA and LowestEMA < LongestEMA ? -1 : 0
plotarrow(Trend == 1 and Trend[1] != 1 ? Trend : na, title="Up Entry Arrow", colorup=lime, maxheight=60, minheight=50, transp=0)
plotarrow(Trend == -1 and Trend[1] != -1 ? Trend : na, title="Down Entry Arrow", colordown=red, maxheight=60, minheight=50, transp=0)

```
