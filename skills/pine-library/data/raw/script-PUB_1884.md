---
id: PUB;1884
title: EMA FIBS
author: Kangaroo
type: indicator
tags: []
boosts: 657
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1884
---

# Description
EMA FIBS

# Source Code
```pine
study(title="EMA FIBS", shorttitle="EMA FIBS", overlay=true)
len = input(8, minval=1, title="Length")
src = input(close, title="Source")
out = ema(src, len)
plot(out, title="EMA", color=blue)

len2 = input(13, minval=1, title="Length")
src2 = input(close, title="Source")
out2 = ema(src2, len2)
plot(out2, title="EMA", color=blue)


len3 = input(21, minval=1, title="Length")
src3 = input(close, title="Source")
out3 = ema(src3, len3)
plot(out3, title="EMA", color=blue)

len4 = input(34, minval=1, title="Length")
src4 = input(close, title="Source")
out4 = ema(src4, len4)
plot(out4, title="EMA", color=blue)

len5 = input(55, minval=1, title="Length")
src5 = input(close, title="Source")
out5 = ema(src5, len5)
plot(out5, title="EMA", color=blue)

len6 = input(89, minval=1, title="Length")
src6 = input(close, title="Source")
out6 = ema(src6, len6)
plot(out6, title="EMA", color=blue)

len7 = input(144, minval=1, title="Length")
src7 = input(close, title="Source")
out7 = ema(src7, len7)
plot(out7, title="EMA", color=blue)

len8 = input(233, minval=1, title="Length")
src8 = input(close, title="Source")
out8 = ema(src8, len8)
plot(out8, title="EMA", color=blue)

len9 = input(377, minval=1, title="Length")
src9 = input(close, title="Source")
out9 = ema(src9, len9)
plot(out9, title="EMA", color=blue)




```
