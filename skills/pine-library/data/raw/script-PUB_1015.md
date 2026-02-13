---
id: PUB;1015
title: LBR Oscillator
author: 20813
type: indicator
tags: []
boosts: 789
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1015
---

# Description
LBR Oscillator

# Source Code
```pine
study("LBR Oscillator", shorttitle="LBR_OSC")
fast = input(title="Fast Length", type=integer, defval=3)
slow = input(title="Slow Length", type=integer, defval=10)
smoothing = input(title="Signal Smoothing", type=integer, defval=16)

[fastline, slowline, histline] = macd(close,fast,slow,smoothing)

plot(0, color=gray)
plot(fastline, color=fastline > 0 ? green : red, style=histogram)
plot(fastline, color=fastline > fastline[1] ? green :red)
plot(slowline, color=slowline > slowline[1] ? green : red)
```
