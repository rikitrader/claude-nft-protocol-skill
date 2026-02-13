---
id: PUB;1437
title: Madrid Donchian Channel
author: Madrid
type: indicator
tags: []
boosts: 762
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1437
---

# Description
Madrid Donchian Channel

# Source Code
```pine
// Hector R. Madrid : 6/JUN/2014 : 15:35 : 2.0 : Donchian Channel
//
study("Madrid Donchian Channel", shorttitle="MDonCh", overlay=true)
src = close

length = input(13, "Length")

highestBar=highest(high, length)
lowestBar=lowest(low, length)
midBar=(highestBar+lowestBar)/2

// Output
channelColor = abs(highestBar-src) < abs(lowestBar-src) ? green : red
midChannel=plot(midBar, color=channelColor, style=line, linewidth=1)

upperChannel=plot(highestBar, color=channelColor, style=line, linewidth=1 )
lowerChannel=plot(lowestBar, color=channelColor, style=line, linewidth=1 )

upperMidChannel=plot(midBar+(highestBar-midBar)*0.5, style=line, linewidth=1, color=channelColor)
lowerMidChannel=plot(midBar-(midBar-lowestBar)*0.5, style=line, linewidth=1, color=channelColor)

fill(midChannel,upperChannel, color=green, transp=80)
fill(lowerChannel, midChannel, color=red, transp=80)

fill(upperMidChannel, upperChannel, color=green, transp=80)
fill(lowerChannel, lowerMidChannel, color=red, transp=80)
```
