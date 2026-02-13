---
id: PUB;2232
title: AutoFib channel by-Stocksight
author: SighTTrader
type: indicator
tags: []
boosts: 382
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2232
---

# Description
AutoFib channel by-Stocksight

# Source Code
```pine
//Created by Stocksight on January 1, 2016. Version 1.0
study("AF", overlay=true, max_bars_back= 89)

//Inputs,  Fib inputs can be added here incase custom values are needed.  Will add that on next revision
z = input (50)
p_offset= input(2)
transp =input(60)

a=(lowest(z)+highest(z))/2
b=lowest(z)
c=highest(z)

//Fib Cals
fib1 = (((c-b)*.764)+b)
fib2 = (((c-b)*.618)+b)
fib3 = (((c-b)*.382)+b)
fib4 = (((c-b)*.500)+b)
fib5 = (((c-b)*.236)+b)

plot(b[p_offset], color = red, linewidth=2)
plot(c[p_offset], color = green, linewidth=2)
plot(fib1[p_offset], color = purple, style=cross, transp = 40, join=true, linewidth=2)
plot(fib2[p_offset], color = yellow, style = cross,transp = transp)
plot(fib3[p_offset], color = yellow, style = cross,transp = transp )
plot(fib4[p_offset], color = red, style = cross,transp = transp, join=true)
plot(fib5[p_offset], color = purple, style = cross,transp = 40, join=true, linewidth=2)




```
