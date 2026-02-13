---
id: PUB;2644
title: MACD DEMA Heat Bckgrd
author: ToFFF
type: indicator
tags: []
boosts: 700
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_2644
---

# Description
MACD DEMA Heat Bckgrd

# Source Code
```pine
study("MACD DEMA Heat Bckgrd",shorttitle='MACD_DEMA_Heat', overlay=true)
//by ToFFF
//MACD DEMA en Overlay sur le graphe principal 
sma = input(12,title='DEMA Courte')
lma = input(26,title='DEMA Longue')
tsp = input(9,title='Signal')
switch = input(true, title="Enable Heatmap?")

MMEslowa = ema(close,lma)
MMEslowb = ema(MMEslowa,lma)
DEMAslow = ((2 * MMEslowa) - MMEslowb )

MMEfasta = ema(close,sma)
MMEfastb = ema(MMEfasta,sma)
DEMAfast = ((2 * MMEfasta) - MMEfastb)

LigneMACDZeroLag = (DEMAfast - DEMAslow)

MMEsignala = ema(LigneMACDZeroLag, tsp)
MMEsignalb = ema(MMEsignala, tsp)
Lignesignal = ((2 * MMEsignala) - MMEsignalb )

MACDZeroLag = (LigneMACDZeroLag - Lignesignal)

MACDZeroLagColor = LigneMACDZeroLag > Lignesignal ? #69A84F : #FF473B
bgcolor(switch?MACDZeroLagColor:na,transp=40)
```
