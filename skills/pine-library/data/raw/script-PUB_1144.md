---
id: PUB;1144
title: [RS] MTF Murrey's Math Lines Channel
author: pipCharlie
type: indicator
tags: []
boosts: 1173
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1144
---

# Description
[RS] MTF Murrey's Math Lines Channel

# Source Code
```pine
study(title="[RS-MTF] Murrey's Math Lines Channel Colors", shorttitle="[RS] MTF MMLC", overlay=true)
//Defaults to Current Chart Time Frame --- But Can Be Changed to Higher Or Lower Time Frames
useCurrentRes = input(true, title="Use Current Chart Resolution?")
resCustom = input(title="Use Different Timeframe? Uncheck Box Above", type=resolution, defval="D")
res = useCurrentRes ? period : resCustom

//SET COLORS
color08 = #008000 
color18 = #3CB371
color28 = #32CD32
color38 = #ADFF2F
color48 = gray
color58 = #CD5C5C
color68 = #FA8072
color78 = #FFA07A
color88 = #FF0000

length00 = input(100)
fmultiplier = input(defval=0.125, type=float)

//MIDLINE CALCULATION
hhi = highest(high, length00)
llo = lowest(low, length00)
fraction = (hhi - llo) * fmultiplier
midline = llo + fraction * 4

//MTF MIDLINE CALCULATION
MTF_HHI = security(tickerid, res, hhi)
MTF_LLO = security(tickerid, res, llo)
MTF_FRACTION = security(tickerid, res, fraction)
MTF_MIDLINE = security(tickerid, res, midline)

//PLOT MMLC
plot(MTF_MIDLINE, color=color48, linewidth=2)
plot(MTF_MIDLINE + MTF_FRACTION * 1, color=color38)
plot(MTF_MIDLINE + MTF_FRACTION * 2, color=color28)
p00 = plot(MTF_MIDLINE + MTF_FRACTION * 3, color=color18, linewidth=1)
p01 = plot(MTF_MIDLINE + MTF_FRACTION * 4, color=color08, linewidth=1)
plot(MTF_MIDLINE - MTF_FRACTION * 1 , color=color58)
plot(MTF_MIDLINE - MTF_FRACTION * 2, color=color68)
p02 = plot(MTF_MIDLINE - MTF_FRACTION * 3, color=color78, linewidth=1)
p03 = plot(MTF_MIDLINE - MTF_FRACTION * 4, color=color88, linewidth=1)
fill(p00, p01, color=lime, transp=85)
fill(p02, p03, color=orange, transp=85)

```
