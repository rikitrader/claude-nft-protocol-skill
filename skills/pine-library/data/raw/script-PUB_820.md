---
id: PUB;820
title: Market Direction Indicator [LazyBear]
author: LazyBear
type: indicator
tags: []
boosts: 2298
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_820
---

# Description
Market Direction Indicator [LazyBear]

# Source Code
```pine
//
// @author LazyBear 
// List of all my indicators: 
// https://docs.google.com/document/d/15AGCufJZ8CIUvwFJ9W-IKns88gkWOKBCvByMEvm5MLo/edit?usp=sharing
// 
study("Market Direction Indicator [LazyBear]", shorttitle="MDI_LB")
src=close
lenMA1=input(13, title="Short Length"), lenMA2=input(55, title="Long Length")
cutoff=input(2, title="No-trend cutoff")
sbz=input(false, title="Show Below Zero")
om=input(false, title="Enable overlay mode")
calc_cp2(src, len1, len2) =>
    (len1*(sum(src, len2-1)) - len2*(sum(src, len1-1))) / (len2-len1)

cp2=calc_cp2(src, lenMA1, lenMA2)
mdi=100*(nz(cp2[1]) - cp2)/((src+src[1])/2)
mdic=mdi<-cutoff?(mdi<mdi[1]?red:orange):mdi>cutoff?(mdi>mdi[1]?green:lime):gray
plot(om ? na : 0, color=gray, title="ZeroLine"), plot(om ? na : sbz ? mdi : abs(mdi), style=columns, color=mdic, linewidth=3, title="MDI")
barcolor(om ? mdic:na)
```
