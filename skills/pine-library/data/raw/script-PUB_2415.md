---
id: PUB;2415
title: altcoin index overlay
author: noomnahor
type: indicator
tags: []
boosts: 54
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2415
---

# Description
altcoin index overlay

# Source Code
```pine
//@version=2
study("altcoin index overlay", overlay=true, scale=scale.right)

curr = security(tickerid, period, ohlc4)

ch1 = input(true, "include ppc", bool)
ch2 = input(false, "include eth", bool)
ch3 = input(true, "include nmc", bool)
ch4 = input(true, "include nxt", bool)
ch5 = input(true, "include xmr", bool)

count = ch1 + ch2 + ch3 + ch4 + ch5

ppc = iff(ch1, security("THEROCKTRADING:PPCBTC", period, ohlc4), 0)
eth = iff(ch2, security("KRAKEN:ETHXBT", period, ohlc4), 0)
nmc = iff(ch3, security("THEROCKTRADING:NMCBTC", period, ohlc4), 0)
nxt = iff(ch4, security("HITBTC:NXTBTC", period, ohlc4), 0)
xmr = iff(ch5, security("HITBTC:XMRBTC", period, ohlc4), 0)

average = avg(ppc, eth, nmc, nxt, xmr)

plot(average, "average", color=white)
```
