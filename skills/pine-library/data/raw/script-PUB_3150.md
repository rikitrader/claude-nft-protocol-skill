---
id: PUB;3150
title: SMA 3-987 Fibonacci
author: traderUS180
type: indicator
tags: []
boosts: 843
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3150
---

# Description
SMA 3-987 Fibonacci

# Source Code
```pine
// @author traderUS180

study(title="SMA 3-987", overlay=true)
src = input(close, title="Source")
len0 = input(3, minval=1, title="Length")
out0 = sma(src, len0)
len1 = input(5, minval=1, title="Length")
out1 = sma(src, len1)
len2 = input(8, minval=1, title="Length")
out2 = sma(src, len2)
len3 = input(13, minval=1, title="Length")
out3 = sma(src, len3)
len4 = input(21, minval=1, title="Length")
out4 = sma(src, len4)
len5 = input(34, minval=1, title="Length")
out5 = sma(src, len5)
len6 = input(55, minval=1, title="Length")
out6 = ema(src, len6)
len7 = input(89, minval=1, title="Length")
out7 = sma(src, len7)
len8 = input(144, minval=1, title="Length")
out8 = sma(src, len8)
len9 = input(233, minval=1, title="Length")
out9 = sma(src, len9)
len10 = input(377, minval=1, title="Length")
out10 = sma(src, len10)
len11 = input(610, minval=1, title="Length")
out11 = sma(src, len11)
len12 = input(987, minval=1, title="Length")
out12 = sma(src, len12)



plot(out0, linewidth=2, color=white, transp=0)
plot(out1, linewidth=2, color=green, transp=0)
plot(out2, linewidth=2, color=yellow, transp=0)
plot(out3, linewidth=2, color=orange, transp=0)
plot(out4, linewidth=3, color=red, transp=0)
plot(out5, linewidth=3, color=maroon, transp=0)

plot(out6, linewidth=3, color=yellow, transp=0)
plot(out7, linewidth=3, color=orange, transp=0)
plot(out8, linewidth=4, color=green, transp=0)
plot(out9, linewidth=4, color=maroon, transp=0)
plot(out10, linewidth=4, color=blue, transp=0)
plot(out11, linewidth=4, color=white, transp=0)
plot(out12, linewidth=4, color=red, transp=0)

```
