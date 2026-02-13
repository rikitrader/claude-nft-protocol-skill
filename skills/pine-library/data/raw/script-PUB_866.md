---
id: PUB;866
title: Vortex Indicator with Thresholds Defined
author: Rashad
type: indicator
tags: []
boosts: 1646
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_866
---

# Description
Vortex Indicator with Thresholds Defined

# Source Code
```pine
//Vortex indicator with defined thresholds created by Rashad
study(title = "Vortex Indicator With Thresholds defined", shorttitle="VI")
period_ = input(7, title="Period", minval=1)

VMP = sum( abs( high - low[1]), period_ )
VMM = sum( abs( low - high[1]), period_ )
STR = sum( atr(1), period_ )
VIP = VMP / STR
VIM = VMM / STR

plot( VIP, title="VI +", color=fuchsia, linewidth=2)
plot( VIM, title="VI -", color=aqua, linewidth=2)
bandy1 = hline(1, color=gray, linestyle=dashed)
bandy2 = hline(0.9, color=orange, linestyle=dashed)
bandy3 = hline(1.1, color=orange, linestyle=dashed)
bandy4 = hline(1.3, color=red, linestyle=dashed)
bandy5 = hline(0.7, color=red, linestyle =dashed)
```
