---
id: PUB;2135
title: Keltner Channels Oscillator
author: j1O9SB
type: indicator
tags: []
boosts: 330
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2135
---

# Description
Keltner Channels Oscillator

# Source Code
```pine
study(title="Keltner Channels Oscillator",shorttitle="KCO",overlay=false,precision=1)
//Inputs
kc_len=input(21,title="Keltner Channel Length")
kc_mult1=input(1,title="Keltner Channel First Multiple")
kc_mult2=input(2,title="Keltner Channel Second Multiple")
kc_src=input(close,title="Keltner Channel Source")
//Keltner Channel
kc_ma=ema(kc_src,kc_len)
kc_rng=ema(tr,kc_len)
kc_oneup=kc_ma+kc_rng*kc_mult1
kc_onedn=kc_ma-kc_rng*kc_mult1
kc_twoup=kc_ma+kc_rng*kc_mult2
kc_twodn=kc_ma-kc_rng*kc_mult2
//Oscillator
kc_lvlclose=(close-kc_ma)/kc_rng
kc_lvlopen=(open-kc_ma)/kc_rng
kc_lvlhigh=(high-kc_ma)/kc_rng
kc_lvllow=(low-kc_ma)/kc_rng
kc_lvloneup=(kc_oneup-kc_ma)/kc_rng
kc_lvlonedn=(kc_onedn-kc_ma)/kc_rng
kc_lvltwoup=(kc_twoup-kc_ma)/kc_rng
kc_lvltwodn=(kc_twodn-kc_ma)/kc_rng
//Color
kc_col=kc_lvlclose>0?green:red
kc_colbar=((kc_lvlclose>kc_lvlonedn)and(kc_lvllow<kc_lvlonedn))?green:((kc_lvlclose<kc_lvloneup)and(kc_lvlhigh>kc_lvloneup))?red:(close>open)?white:black
//Plots
plotbar(kc_lvlopen,kc_lvlhigh,kc_lvllow,kc_lvlclose,color=kc_colbar,editable=true)
plot(kc_lvloneup,color=#C285E6,style=line,linewidth=1,editable=false)
plot(kc_lvlonedn,color=#C285E6,style=line,linewidth=1,editable=false)
plot(kc_lvltwoup,color=#C285E6,style=line,linewidth=1,editable=false)
plot(kc_lvltwodn,color=#C285E6,style=line,linewidth=1,editable=false)
```
