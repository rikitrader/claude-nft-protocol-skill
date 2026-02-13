---
id: PUB;1330
title: DiNapoli MACD & Stoch [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 2583
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1330
---

# Description
DiNapoli MACD & Stoch [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// 
// List of my public indicators: http://bit.ly/1LQaPK8 
// List of my app-store indicators: http://blog.tradingview.com/?p=970 
//
study(title="DiNapoli MACD [LazyBear]", shorttitle="DMACD_LB", overlay=false)
lc = input(17.5185, title="Long Cycle")
sc =input(8.3896, title="Short Cycle") 
sp =input(9.0503, title="Signal Length") 
src=input(close, title="Source")
fs = nz(fs[1]) + 2.0 / (1.0 + sc) * (src- nz(fs[1]))
ss = nz(ss[1]) + 2.0 / (1.0 + lc) * (src - nz(ss[1]))
r = fs - ss
s = nz(s[1]) + 2.0/(1 + sp)*(r - nz(s[1]))
plot(r, style=columns, color=r>0?green:red, transp=80, title="Histo")
plot(s, color=teal, linewidth=2, title="Dinapoli MACD") 
```
