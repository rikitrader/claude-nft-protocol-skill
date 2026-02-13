---
id: PUB;412
title: Indicators: Twiggs Money Flow [TMF] & Wilder's MA [WiMA]
author: LazyBear
type: indicator
tags: []
boosts: 2254
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_412
---

# Description
Indicators: Twiggs Money Flow [TMF] & Wilder's MA [WiMA]

# Source Code
```pine
//
// @author LazyBear
// @credits http://www.incrediblecharts.com/indicators/twiggs_money_flow.php
// 
// If you use this code in its original/modified form, do drop me a note. 
//
study("Twiggs Money Flow [LazyBear]", shorttitle="TMF_LB")
length = input( 21, "Period")
WiMA(src, length) => 
    MA_s=(src + nz(MA_s[1] * (length-1)))/length
    MA_s
    
hline(0)
tr_h=max(close[1],high)
tr_l=min(close[1],low)
tr_c=tr_h-tr_l
adv=volume*((close-tr_l)-(tr_h-close))/ iff(tr_c==0,9999999,tr_c)
wv=volume+(volume[1]*0)
wmV= WiMA(wv,length)
wmA= WiMA(adv,length)
tmf= iff(wmV==0,0,wmA/wmV)
plot(tmf, style=area)


```
