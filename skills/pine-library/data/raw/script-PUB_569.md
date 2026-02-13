---
id: PUB;569
title: Percent Volume Oscillator(by ucsgears)
author: UDAY_C_Santhakumar
type: indicator
tags: []
boosts: 769
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_569
---

# Description
Percent Volume Oscillator(by ucsgears)

# Source Code
```pine
// Created by UCSgears, Based on the Percent Price Oscillator (PPO)

study("Advanced Percent Volume Oscillator", shorttitle="UCS_PVO", overlay=false)
src = volume
shortlen=input(21, minval=1, title="Primary Length") 
longlen=input(55, minval=1, title="Base Length")
smooth=input(13, minval=1, title="Signal Length")

short = ema(src, shortlen)
long = ema(src, longlen)
ppo = ((short - long)/long)*100
sig = ema(ppo,smooth)

plot(ppo, title="PPO", color=aqua)
plot(sig, title="signal", color=orange)
plot(ppo-sig,color=#FF006E,style=histogram, color=gray, linewidth = 3)
```
