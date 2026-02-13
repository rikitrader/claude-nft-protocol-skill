---
id: PUB;2724
title: ema-sma
author: MarcoValente
type: indicator
tags: []
boosts: 1759
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2724
---

# Description
ema-sma

# Source Code
```pine
//
study(title="ema-sma", shorttitle="ema-sma + vol")
src =input(close,title="source"),length = input(9, minval=1,title="short ema"),lensma=input(17,title="long sma")
vol=volume
vm=100*((sma(vol,length)-(sma(vol,length)[4]))/(sma(vol,length)[4]))
vvm=100*(sma(((vm-vm[1])/vm[1]),3))
osc=sma((ema(src,length)-sma(src,lensma)),3)
sig=(osc+2*osc[1]+2*osc[2]+osc[3])/6
cc=osc>0 ? lime : osc<0 ? red: na
cut=abs(vvm/8)> abs(sma(vvm,5)) ?osc/0.7 : na
cv=cut>0 ? aqua : orange 
si=plot(sig,color=cc)
duml=plot((osc>sig?osc:sig), style=circles, linewidth=0, color=gray)
os=plot(osc,color=cc,linewidth=2, title="ROC")
fill(si,duml,color=green,transp=60)
fill(os,duml,color=red,transp=60)
hline(0, title="Zero Line",color=white)
plot(cut,color=cv,style=columns,linewidth=2,transp=60)
```
