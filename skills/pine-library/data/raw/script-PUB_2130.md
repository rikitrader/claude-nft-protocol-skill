---
id: PUB;2130
title: High-Low Difference Channels r2
author: JayRogers
type: indicator
tags: []
boosts: 448
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2130
---

# Description
High-Low Difference Channels r2

# Source Code
```pine
//@version=2

study(title="High-Low Difference Channels r2 - SMA/EMA/WMA/VWMA/SMMA/DEMA/HullMA/LSMA", shorttitle="HLDC_r2", overlay=true)

// Revision:    2
// Author:      JayRogers
//
// Description / Usage:
//  - Adjust length and multiplier much the same way you would expect with Bollinger Bands.
//  - multiplier of 1 gives you a base channel consisting of one high, and one low sourced MA
//  - The outer channels are increments of the base high-low channel width, away from the hl2 sourced MA
//
// r2 Changes:
//  - Increased amount of up/down channels to 5, and lowered multiplier default to 1 (previously 1.5)
//  - Tweaked default colour scheme.
//  - Pick your MA poison of choice! Added choices for all your common MA variants.
//
// Issues *
//  - VWMA bugs out and refuses to draw sometimes. No idea why.

hlc_typeString  = input(defval="SMA", title="Pick your Poison: SMA, EMA, WMA, VWMA, SMMA, DEMA, HullMA, LSMA (case sensitive)", type=string)
hlc_length      = input(defval=50, title="Channel Length", minval=1)
hlc_diffMult    = input(defval=1.0, title="Channel Width Multiplier", minval=0.1, maxval=50)
lsma_offset     = input(defval=0, title="LSMA Offset (only affects LSMA)")

maVariant(maT, maS, maL) =>
    v1 = sma(maS, maL)                                                  // Simple
    v2 = ema(maS, maL)                                                  // Exponential
    v3 = wma(maS, maL)                                                  // Weighted
    v4 = vwma(maS, maL)                                                 // Volume Weighted *
    v5 = na(v5[1]) ? sma(maS, maL) : (v5[1] * (maL - 1) + maS) / maL    // Smoothed
    v6 = 2 * ema(maS, maL) - ema(ema(maS, maL), maL)                    // Double Exponential
    v7 = wma(2 * wma(maS, maL / 2) - wma(maS, maL), round(sqrt(maL)))   // Hull
    v8 = linreg(maS, maL, lsma_offset)                                  // Least Squares
    // return MA poison of choice, defaults to SMA (in case of input typo)
    r = maT=="SMA"?v1 : maT=="EMA"?v2 : maT=="WMA"?v3 : maT=="VWMA"?v4 : maT=="SMMA"?v5 : maT=="DEMA"?v6 : maT=="HullMA"?v7 : maT=="LSMA"?v8 : v1

hl2_line    = maVariant(hlc_typeString, hl2, hlc_length)
high_line   = maVariant(hlc_typeString, high, hlc_length)
low_line    = maVariant(hlc_typeString, low, hlc_length)

diffMult(num) =>
    hldm = (high_line - low_line) * hlc_diffMult
    r = hldm * num

midline     = plot(hl2_line, title="Midline", color=#0066AA, linewidth=1, transp=50)

highLine    = plot(hl2_line + (diffMult(1) / 2), title="Center Channel Upper", color=silver, transp=100)
lowLine     = plot(hl2_line - (diffMult(1) / 2), title="Center Channel Lower", color=silver, transp=100)

diffUp1     = plot(hl2_line + diffMult(1), title="High Diff 1", color=#0099FF, transp=80)
diffUp2     = plot(hl2_line + diffMult(2), title="High Diff 2", color=#0099FF, transp=80)
diffUp3     = plot(hl2_line + diffMult(3), title="High Diff 3", color=#0099FF, transp=80)
diffUp4     = plot(hl2_line + diffMult(4), title="High Diff 4", color=#0099FF, transp=80)
diffUp5     = plot(hl2_line + diffMult(5), title="High Diff 5", color=#0099FF, transp=80)

diffDown1   = plot(hl2_line - diffMult(1), title="Low Diff 1", color=#0099FF, transp=80)
diffDown2   = plot(hl2_line - diffMult(2), title="Low Diff 2", color=#0099FF, transp=80)
diffDown3   = plot(hl2_line - diffMult(3), title="Low Diff 3", color=#0099FF, transp=80)
diffDown4   = plot(hl2_line - diffMult(4), title="Low Diff 4", color=#0099FF, transp=80)
diffDown5   = plot(hl2_line - diffMult(5), title="Low Diff 5", color=#0099FF, transp=80)

fill(highLine, lowLine, title="Center High-Low Fill", color=silver, transp=70)
```
