---
id: PUB;2798
title: K.M Trend Strategy (BETA 1.2)
author: TradeWithConfidence
type: indicator
tags: []
boosts: 1687
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2798
---

# Description
K.M Trend Strategy (BETA 1.2)

# Source Code
```pine
//@version=2
strategy("K.M Trend Strategy (BETA 1.2)")
    //// This script is built by Kevin Manrrique, if you have any information or questions ////
    //// about this script and how it works please message me. K.M Trend Alerts (BETA 1.2) is a //// 
    //// testing indicator. If your intrested in recieving signals please follow us on; Instagram: TWTForexGroup ////
    //// We build, rebuild, repair, and test if intrested inbox me /////
    //// Appreciate what you have around you, not everyone lives like us ////
    //// Sincerely, ////
    //// Kevin Manrrique //// 

    //// Main ////
tim="2440", minval=1
tim2="1440", minval2=1

    //// Lines ////
line1 = security(tickerid, tim, close[1])
line2 = security(tickerid, tim2, close[0.99])
line3 = line2 - line1

    //// Plot ////
plot(line3, style=columns, color=orange, linewidth=3, title="P")

    //// Additions ////
baseline=0
plot(baseline, style=line, color=black, title="B")

    //// Signals ////
longcondition = cross(line3, baseline)
if (longcondition)
    strategy.entry("Buy",  strategy.long)

shortcondition = crossunder(line3, baseline)
if (shortcondition)
    strategy.entry("Sell", strategy.short)






```
