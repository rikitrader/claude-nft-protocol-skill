---
id: PUB;423
title: Indicators: 6 RSI variations
author: LazyBear
type: indicator
tags: []
boosts: 2952
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_423
---

# Description
Indicators: 6 RSI variations

# Source Code
```pine
//
// @author LazyBear
// 
// If you use this code in its original/modified form, do drop me a note. 
//
study("RSI + Volume [LazyBear]", shorttitle="RSIVolume_LB")
length=input(14)
ob=input(80, title="Overbought")
os=input(20, title="Oversold")

WiMA(src, length) => 
    MA_s=(src + nz(MA_s[1] * (length-1)))/length
    MA_s

calc_rsi_volume(fv, length) =>	
	up=iff(fv>fv[1],abs(fv-fv[1])*volume,0)
	dn=iff(fv<fv[1],abs(fv-fv[1])*volume,0)
	upt=WiMA(up,length)
	dnt=WiMA(dn,length)
	100*(upt/(upt+dnt))

rsi_v = calc_rsi_volume(close, length)

u=plot(ob)
l=plot(os)
fill(u,l,red)
plot(50)
plot(rsi_v, color=red, linewidth=1)
```
