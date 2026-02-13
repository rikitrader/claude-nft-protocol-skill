---
id: PUB;3
title: Indicator: Krivo Index [Forex]
author: LazyBear
type: indicator
tags: []
boosts: 331
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_3
---

# Description
Indicator: Krivo Index [Forex]

# Source Code
```pine
//
// @author LazyBear
//
// If you use this code in its original/modified form, do drop me a note. 
//
study("EUR Krivo Index [LazyBear]", shorttitle="EURKI_LB")

src=close
lengthMA=input(200)

// Helper fns
calc_score(s, l) =>
    ma = sma(s, l)
    s >= ma ? 1 : -1

calc_invscore(s, l) =>
    score=calc_score(s,l)
    -1 * score

// EUR 
ieurchf=security("FX:EURCHF", period, src)
ieurusd=security("FX:EURUSD", period, src)
ieurdkk=security("FX:EURDKK", period, src)
ieurjpy=security("FX:EURJPY", period, src)
ieurpln=security("FX:EURPLN", period, src)
ieurgbp=security("FX:EURGBP", period, src)
ieursek=security("FX:EURSEK", period, src)
ieurcad=security("FX:EURCAD", period, src)
ieurnok=security("FX:EURNOK", period, src)
ieurhuf=security("FX:EURHUF", period, src)
ieurtry=security("FX:EURTRY", period, src)
ieuraud=security("FX:EURAUD", period, src)
ieurnzd=security("FX:EURNZD", period, src)
ieurczk=security("FX:EURCZK", period, src)

// Calculate KI
eur_t = calc_score(ieurusd, lengthMA) +
        calc_score(ieurchf, lengthMA) + 
        calc_score(ieurjpy, lengthMA) + 
        calc_score(ieurdkk, lengthMA) + 
        calc_score(ieurpln, lengthMA) + 
        calc_score(ieurgbp, lengthMA) + 
        calc_score(ieursek, lengthMA) + 
        calc_score(ieurcad, lengthMA) + 
        calc_score(ieurnok, lengthMA) + 
        calc_score(ieurhuf, lengthMA) + 
        calc_score(ieurtry, lengthMA) + 
        calc_score(ieuraud, lengthMA) + 
        calc_score(ieurnzd, lengthMA) + 
        calc_score(ieurczk, lengthMA) 
        
plot(eur_t, color=maroon, linewidth=2, title="EUR KI")

```
