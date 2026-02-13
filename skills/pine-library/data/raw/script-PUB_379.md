---
id: PUB;379
title: Colored Volume Bars [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 10988
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_379
---

# Description
Colored Volume Bars [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: https://www.tradingview.com/v/4IneGo8h/
//
study("Colored Volume Bars [LazyBear]", shorttitle="CVOLB_LB")
lookback=input(10)
showMA=input(false)
lengthMA=input(20)
p2=close
v2=volume
p1=p2[lookback] 
v1=v2[lookback] 
c=	iff(p2>p1 and v2>v1, green, 
	iff(p2>p1 and v2<v1, blue,
	iff(p2<p1 and v2<v1, orange,
	iff(p2<p1 and v2>v1, red, gray))))
plot(v2, style=columns, color=c)
plot(showMA?sma(v2, lengthMA):na, color=maroon)

```
