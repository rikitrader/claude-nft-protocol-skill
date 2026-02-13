---
id: PUB;4242
title: Normalized MACD (v420)
author: SeaSide420
type: indicator
tags: []
boosts: 437
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_4242
---

# Description
Normalized MACD (v420)

# Source Code
```pine
// Normalized MACD modified by SeaSide420. Normalized MACD v420
study("Normalized MACD (v420)",shorttitle='NmacD(v420)')
jah=input(title="HullMA cross",type=integer,defval=14)
tsp = input(33,title='Trigger')
np = input(50,title='Normalize')
h=input(false,title='Histogram')
docol = input(true,title="Color Change")
dofill=input(false,title="Fill")
n2ma=2*wma(close,round(jah/2))
nma=wma(close,jah)
diff=n2ma-nma
sqn=round(sqrt(jah))
n2ma1=2*wma(close[1],round(jah/2))
nma1=wma(close[1],jah)
diff1=n2ma1-nma1
sqn1=round(sqrt(jah))
n1=wma(diff,sqn)
n2=wma(diff1,sqn)
sh=n1
lon=n2
ratio = min(sh,lon)/max(sh,lon)
Mac = (iff(sh>lon,2-ratio,ratio)-1)
MacNorm = ((Mac-lowest(Mac, np)) /(highest(Mac, np)-lowest(Mac, np)+.000001)*2)- 1
MacNorm2 = iff(np<2,Mac,MacNorm)
Trigger = wma(MacNorm2, tsp)
Hist =(MacNorm2-Trigger)
Hist2= Hist>1?1:Hist<-1?-1:Hist
swap = docol ? Hist2>0?green:red:black
swap1 = docol ? Hist2>Hist2[1]?red:green:black
swap2 = docol ? MacNorm2 > MacNorm2[1] ? #0094FF : #FF006E : red
swap3 = docol ? Trigger>0?green:red:black
hline(0)
plot(h?Hist2:na,color=swap2,style=columns,title='Hist',histbase=0)
plot(dofill?MacNorm2:na,color=swap1,style=columns)
teh=MacNorm2+MacNorm2[2]-MacNorm2[1]
n1e=plot(teh,color=black,title='MacNorm')
n2e=plot(Trigger,color=swap3, style=line, linewidth = 3, title='Trigger')
fill(n1e, n2e, color=swap, transp=50)
plot(cross(Trigger, MacNorm2) ? Trigger : na, style = cross,color=swap, linewidth = 4)
plot(cross(Trigger, MacNorm2) ? Trigger : na, style = cross,color=black, linewidth = 2)
```
