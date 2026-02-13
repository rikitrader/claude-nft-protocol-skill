---
id: PUB;810
title: Commodity channel index x2 v1
author: IldarAkhmetgaleev
type: indicator
tags: []
boosts: 396
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_810
---

# Description
Commodity channel index x2 v1

# Source Code
```pine
study(title="Commodity Channel Index x2" , shorttitle='CCIx2')

fast_lenght = input(title="Fast CCI Length", type=integer, defval=6, minval=1)
slow_lenght = input(title="Slow CCI Length", type=integer, defval=14, minval=1)

source = close

fast_cci = cci(source, fast_lenght)
slow_cci = cci(source, slow_lenght)

hist = (fast_cci - slow_cci)
hist_color = hist > 0 ? green : red

hline(0, title="Zero Line", color=gray, linestyle=dotted)
overbought = hline(100, title="Positive Line", color=gray, linestyle=dotted)
oversold = hline(-100, title="Negative Line", color=gray, linestyle=dotted)
fill(overbought, oversold, color=#9915ff, transp=90)

plot(hist, color=hist_color, title='Difference', style=histogram)
fast_line = plot(fast_cci, color=#9922ff, title='Fast CCI')
slow_line = plot(slow_cci, color=#447711, title='Slow CCI')
fill(fast_line, slow_line, color=#004499, transp=90)
```
