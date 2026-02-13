---
id: PUB;1937
title: SuperTrend Oscillator
author: j1O9SB
type: indicator
tags: []
boosts: 579
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1937
---

# Description
SuperTrend Oscillator

# Source Code
```pine
//@version=2
study(title="SuperTrend Oscillator",shorttitle="STO",overlay=false)
//Inputs
spt_ures=input(false,title="Use Cutsom Resolution?")
spt_res=input(type=resolution,defval="D")
spt_lenw=input(200,title="Length Of Warning Range")
spt_len=input(14,title="SuperTrend Length")
spt_mult=input(1,title="SuperTrend Multiple")
colup=green
coldn=red
//SuperTrend
spt_atr=atr(spt_len)
spt_nsb=hl2+spt_atr*spt_mult
spt_nlb=hl2-spt_atr*spt_mult
spt_lb=close[1]>spt_lb[1]?max(spt_nlb,spt_lb[1]):spt_nlb
spt_sb=close[1]<spt_sb[1]?min(spt_nsb,spt_sb[1]):spt_nsb
spt_tdur=close>spt_sb[1]?1:close<spt_lb[1]?-1:nz(spt_tdur[1],1)
spt_td=spt_ures?(security(tickerid,spt_res,spt_tdur)):spt_tdur
spt_lvlur=(close-(spt_td==1?spt_lb:spt_sb))
spt_lvl=spt_ures?(security(tickerid,spt_res,spt_lvlur)):spt_lvlur
//Components
spt_lvlup=spt_td==1?spt_lvl:na
spt_lvldn=spt_td==-1?spt_lvl:na
spt_tdup=(spt_td==1)and(spt_td[1]==-1)
spt_tddn=(spt_td==-1)and(spt_td[1]==1)
spt_matrur=sma((tr),spt_lenw)
spt_matr=spt_ures?(security(tickerid,spt_res,spt_matrur)):spt_matrur
spt_lvlwup=(spt_lvlup<spt_matr)and(close<close[1])
spt_lvlwdn=(spt_lvldn>-spt_matr)and(close>close[1])
//Color
spt_col=spt_td==1?colup:coldn
spt_colhst=spt_tdup?colup:spt_tddn?coldn:spt_lvlwdn?colup:spt_lvlwup?coldn:na
//Plot
p0=plot(0,color=spt_col,style=line,linewidth=1,transp=0,title="Midline")
p1=plot(spt_lvlup,color=colup,style=linebr,linewidth=1,transp=0,title="Uptrend Line")
p2=plot(spt_lvldn,color=coldn,style=linebr,linewidth=1,transp=0,title="Downtrend Line")
plot(spt_lvl,color=spt_colhst,style=histogram,linewidth=2,transp=0,title="Trend Change")
fill(p0,p1,color=colup,transp=90)
fill(p0,p2,color=red,transp=90)
```
