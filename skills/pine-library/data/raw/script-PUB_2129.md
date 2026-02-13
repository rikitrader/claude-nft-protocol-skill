---
id: PUB;2129
title: High-Low Difference Channels - SMA/EMA
author: JayRogers
type: indicator
tags: []
boosts: 645
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2129
---

# Description
High-Low Difference Channels - SMA/EMA

# Source Code
```pine
//@version=2

study(title="High-Low Difference Channels - SMA/EMA", shorttitle="HLDC", overlay=true)

// Revision:    1
// Author:      JayRogers
// Reasoning:   I wrote this up as a potential replacement for my BB based strategies, and so far it's
//              looking pretty nifty.
//
// Description / Usage:
//
//  - Adjust length and multiplier much the same way you would expect with Bollinger Bands.
//  - multiplier of 1 gives you a base channel consisting of one high, and one low sourced SMA (or EMA)
//  - The outer channels are increments of the base channels width, away from the median hl2 sourced SMA (..or EMA)

hlc_length      = input(50, title="Channel Length", minval=1)
hlc_diffMult    = input(1.5, title="Difference Multiplier", minval=0.1, maxval=50)
hlc_useEMA      = input(false, title="Use EMA instead of SMA?")

hl2_line    = hlc_useEMA ? ema(hl2, hlc_length) : sma(hl2, hlc_length)
high_line   = hlc_useEMA ? ema(high, hlc_length) : sma(high, hlc_length)
low_line    = hlc_useEMA ? ema(low, hlc_length) : sma(low, hlc_length)

diffMult(num) =>
    hldm = (high_line - low_line) * hlc_diffMult
    r = hldm * num

midline     = plot(hl2_line, title="Midline", color=silver, transp=0)

highLine    = plot(hl2_line + (diffMult(1) / 2), title="Center Channel Upper", color=silver, transp=100)
lowLine     = plot(hl2_line - (diffMult(1) / 2), title="Center Channel Lower", color=silver, transp=100)

diffUp1     = plot(hl2_line + diffMult(1), title="High Diff 1", color=silver, transp=0)
diffUp2     = plot(hl2_line + diffMult(2), title="High Diff 2", color=silver, transp=0)
diffUp3     = plot(hl2_line + diffMult(3), title="High Diff 3", color=silver, transp=0)

diffDown1   = plot(hl2_line - diffMult(1), title="Low Diff 1", color=silver, transp=0)
diffDown2   = plot(hl2_line - diffMult(2), title="Low Diff 2", color=silver, transp=0)
diffDown3   = plot(hl2_line - diffMult(3), title="Low Diff 3", color=silver, transp=0)

fill(highLine, lowLine, title="Center High-Low Fill", color=silver, transp=50)
```
