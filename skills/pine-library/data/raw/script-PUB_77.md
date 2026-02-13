---
id: PUB;77
title: RSI based on ROC
author: HPotter
type: indicator
tags: []
boosts: 1991
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_77
---

# Description
RSI based on ROC

# Source Code
```pine
////////////////////////////////////////////////////////////
//  Copyright by HPotter v1.0 14/05/2014
// This is the new-age indicator which is version of RSI calculated upon 
// the Rate-of-change indicator.
// The name "Relative Strength Index" is slightly misleading as the RSI 
// does not compare the relative strength of two securities, but rather 
// the internal strength of a single security. A more appropriate name 
// might be "Internal Strength Index." Relative strength charts that compare 
// two market indices, which are often referred to as Comparative Relative Strength.
// And in its turn, the Rate-of-Change ("ROC") indicator displays the difference 
// between the current price and the price x-time periods ago. The difference can 
// be displayed in either points or as a percentage. The Momentum indicator displays 
// the same information, but expresses it as a ratio.
////////////////////////////////////////////////////////////
study(title="RSI based on ROC", shorttitle="RSI/ROC")
RSILength = input(20, minval=1)
ROCLength = input(20, minval=1)
xPrice = close
hline(70, color=red, linestyle=line, title = "Upper")
hline(30, color=green, linestyle=line, title = "Lower")
nRes = rsi(roc(xPrice,ROCLength),RSILength)
plot(nRes, color=blue, title="RSI/ROC")
```
