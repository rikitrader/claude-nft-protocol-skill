---
id: PUB;1564
title: EurUsd Momentum Heiken Ashi
author: TheBulltrader
type: indicator
tags: []
boosts: 345
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1564
---

# Description
EurUsd Momentum Heiken Ashi

# Source Code
```pine
study(title="Momentum", shorttitle="MO", overlay =false)
x=security(tickerid,'D',high)
y=security(tickerid,'D',low)
z=security(tickerid,'D',close)

line=0
plot(line,color=green)
theta=asin((close-open))
a=iff(theta>=.0001,.0001,0)
plot(theta)



```
