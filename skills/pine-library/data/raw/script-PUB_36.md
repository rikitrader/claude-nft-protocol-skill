---
id: PUB;36
title: Custom Indicator--Interesting Thought Process!
author: ChrisMoody
type: indicator
tags: []
boosts: 1446
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_36
---

# Description
Custom Indicator--Interesting Thought Process!

# Source Code
```pine
//Created by ChrisMoody on 5/5/2014 by request from Drat
//Reference Article with Specifics and Trade Patterns.  http://www.forexfactory.com/showthread.php?t=37111

study(title="CM_Stochastic_Threads", shorttitle="CM_Stoch_Threads")
//length = input(14, minval=1)
smoothK = input(3, minval=1, title="SmoothK - Keep at Setting 3")
smoothD = input(3, minval=1, title="SmoothD - Keep at Setting 3")
//k = sma(stoch(close, high, low, length), smoothK)
//d = sma(k, smoothD)

k6 = sma(stoch(close, high, low, 6), smoothK)
k7 = sma(stoch(close, high, low, 7), smoothK)
k8 = sma(stoch(close, high, low, 8), smoothK)
k9 = sma(stoch(close, high, low, 9), smoothK)
k10 = sma(stoch(close, high, low, 10), smoothK)
k11 = sma(stoch(close, high, low, 11), smoothK)
k12 = sma(stoch(close, high, low, 12), smoothK)
k13 = sma(stoch(close, high, low, 13), smoothK)

k14 = sma(stoch(close, high, low, 14), smoothK)

k15 = sma(stoch(close, high, low, 15), smoothK)
k16 = sma(stoch(close, high, low, 16), smoothK)
k17 = sma(stoch(close, high, low, 17), smoothK)
k18 = sma(stoch(close, high, low, 18), smoothK)
k19 = sma(stoch(close, high, low, 19), smoothK)
k20 = sma(stoch(close, high, low, 20), smoothK)
k21 = sma(stoch(close, high, low, 21), smoothK)
k22 = sma(stoch(close, high, low, 22), smoothK)
k23 = sma(stoch(close, high, low, 23), smoothK)
k24 = sma(stoch(close, high, low, 24), smoothK)


plot(k6, title="%K 6 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k7, title="%K 7 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k8, title="%K 8 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k9, title="%K 9 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k10, title="%K 10 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k11, title="%K 11 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k12, title="%K 12 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)
plot(k13, title="%K 13 Lower Time Frame Stoch", style=line, linewidth=1, color=aqua)

plot(k14, title="***%K 14 Base Stoch***(Keep Thick Line)", style=line, linewidth=4, color=red)

plot(k15, title="%K 15 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k16, title="%K 16 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k17, title="%K 17 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k18, title="%K 18 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k19, title="%K 19 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k20, title="%K 20 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k21, title="%K 21 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k22, title="%K 22 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k23, title="%K 23 Higher Time Frame Stoch", style=line, linewidth=1, color=red)
plot(k24, title="%K 24 Higher Time Frame Stoch", style=line, linewidth=1, color=red)

//plot(d, color=orange)
h0 = hline(80)
h1 = hline(20)
fill(h0, h1, color=silver, transp=75)
```
