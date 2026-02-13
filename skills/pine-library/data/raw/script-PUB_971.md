---
id: PUB;971
title: Price Volume Rank [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 1247
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_971
---

# Description
Price Volume Rank [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
// 
study("Price Volume Rank [LazyBear]", shorttitle="PVR_LB", overlay=false)
showMA=input(true, title="Show MA Crossovers")
ma1=input(5, title="Fast MA Length", defval=5),ma2=input(10, title="Slow MA Length", defval=10)
dblSmoothing=input(false, title="Double Smoothing")
pvr=iff(close>close[1] and volume>volume[1],1,
	iff(close>close[1] and volume<=volume[1],2,
	iff(close<=close[1] and volume<=volume[1],3,4)))
ux=pvr>3.0?pvr:na,lx=pvr<2.0?pvr:na
u=plot(showMA?na:na(volume)?na:2.0, color=green, title="BullLine")
l=plot(showMA?na:na(volume)?na:3.0, color=red, title="BearLine")
fill(u,l,gray)
mal=plot(showMA?na(volume)?na:2.5:na, color=gray, title="MACutoff")
plot(showMA?na:na(volume)?na:pvr, style=histogram, histbase=2, color=pvr>3.0?red:pvr<2.0?green:gray, linewidth=2,transp=40, title="PVR")
plot(showMA?na:na(volume)?na:pvr, style=circles, color=pvr>=3.0?red:pvr<=2.0?green:gray, linewidth=4, title="PVR Points")
sma1=not showMA?na:dblSmoothing?sma(sma(pvr,ma1),ma1):sma(pvr,ma1), sma2=not showMA?na:dblSmoothing?sma(sma(pvr,ma2),ma2):sma(pvr,ma2)
plot(showMA?na(volume)?na:sma1:na, style=linebr, color=red, linewidth=2, title="Fast MA")
plot(showMA?na(volume)?na:sma2:na, style=linebr, color=green, linewidth=1, title="Slow MA")
x=na(volume)?(nz(x[1])+0.4)%4.0:na
plotshape(na(volume)?x:na, style=shape.circle, color=red, text="No volume", location=location.absolute, title="ErrorText")

```
