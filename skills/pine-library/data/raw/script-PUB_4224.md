---
id: PUB;4224
title: Phi35 - Candlestick Reversal Patterns V1 ©
author: phi35
type: indicator
tags: []
boosts: 619
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_4224
---

# Description
Phi35 - Candlestick Reversal Patterns V1 ©

# Source Code
```pine
//@version=2
study("Phi35 - Candlestick Reversal Patterns V1", overlay=true)

//Candlestick Reversal Pattern V1 by Phi35 - 9rd September 2016 (c)
//Check also the "Candlestick Continuation Pattern" Indicator by me!
//Do not modify the code without permission!
//If there is an issue or any suggestions, feel free to contact me on the link below
//https://new.tradingview.com/u/phi35/

//It seems to work well but still no guarantee on completeness!
//RISK WARNING! PAST PERFORMANCE IS NOT NECESSARILY INDICATIVE OF FUTURE RESULTS. IN MAKING AN INVESTMENT DECISION, TRADERS MUST RELY ON THEIR OWN EXAMINATION OF THE ENTITY MAKING THE TRADING DECISIONS!
//Wait always for confirmation (next opening price or closing price)


// RECOGNIZABLE REVERSAL PATTERNS
// 01.Engulfing
// 02.Harami
// 03.Piercing Line
// 04.Morning Star
// 05.Evening Star
// 06.Belt Hold
// 07.Three White Soldiers
// 08.Three Black Crows
// 09.Three Stars in the South
// 10.Stick Sandwich
// 11.Meeting Line
// 12.Kicking
// 13.Ladder Bottom

// Although the Engulfing and Harami Patterns are important but can occur too often and give false signals, I give you the option to turn them completely off.

//Engulfing Bullish
bullish_engulfing = high[0]>high[1] and low[0]<low[1] and open[0]<open[1] and close[0]>close[1] and close[0]>open[0] and close[1]<close[2] and close[0]>open[1]
plotshape(bullish_engulfing,text='Engulfing', style=shape.triangleup, color=#BEDB39, editable=true, title="Bullish Engulfing Text")
barcolor(high[0]>high[1] and low[0]<low[1] and open[0]<open[1] and close[0]>close[1] and close[0]>open[0] and close[1]<close[2] and close[0]>open[1] ? #BEDB39 : na, title="Bullish Engulfing")

//Engulfing Bearish
bearish_engulfing = high[0]>high[1] and low[0]<low[1] and open[0]>open[1] and close[0]<close[1] and close[0]<open[0] and close[1]>close[2] and close[0]<open[1]
plotshape(bearish_engulfing,text='Engulfing', style=shape.triangledown, color=#FF3D2E, editable=true, title="Bearish Engulfing Text")
barcolor(high[0]>high[1] and low[0]<low[1] and open[0]>open[1] and close[0]<close[1] and close[0]<open[0] and close[1]>close[2] and close[0]<open[1] ? #FF3D2E : na, title="Bearish Engulfing")



//Harami Bullish
bullish_harami = open[1]>close[1] and close[1]<close[2] and open[0]>close[1] and open[0]<open[1] and close[0]>close[1] and close[0]<open[1] and high[0]<high[1] and low[0]>low[1] and close[0]>=open[0]
plotshape(bullish_harami,text='Harami', style=shape.triangleup, color=#BEDB39, editable=true, title="Bullish Harami Text")
barcolor(open[1]>close[1] and close[1]<close[2] and open[0]>close[1] and open[0]<open[1] and close[0]>close[1] and close[0]<open[1] and high[0]<high[1] and low[0]>low[1] and close[0]>=open[0] ? #BEDB39 : na, title="Bullish Harami")

//Harami Bearish
bearish_harami = open[1]<close[1] and close[1]>close[2] and open[0]<close[1] and open[0]>open[1] and close[0]<close[1] and close[0]>open[1] and high[0]<high[1] and low[0]>low[1] and close[0]<=open[0]
plotshape(bearish_harami,text='Harami', style=shape.triangledown, color=#FF3D2E, editable=true, title="BEarish Harami Text")
barcolor(open[1]<close[1] and close[1]>close[2] and open[0]<close[1] and open[0]>open[1] and close[0]<close[1] and close[0]>open[1] and high[0]<high[1] and low[0]>low[1] and close[0]<=open[0] ? #FF3D2E : na, title="Bearish Harami")



//Piercing Line
piercing_line = close[2]>close[1] and open[0]<low[1] and close[0]>avg(open[1],close[1]) and close[0]<open[1]
plotshape(piercing_line,text='Piercing Line', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(close[2]>close[1] and open[0]<low[1] and close[0]>avg(open[1],close[1]) and close[0]<open[1] ? #BEDB39 : na, title="Piercing Line")

//Dark Cloud Cover 
dark_cloud_cover = close[2]<close[1] and open[0]>high[1] and close[0]<avg(open[1],close[1]) and close[0]>open[1]
plotshape(dark_cloud_cover,text='Dark Cloud Cover', style=shape.triangledown, color=#FF3D2E, editable=false)
barcolor(close[2]<close[1] and open[0]>high[1] and close[0]<avg(open[1],close[1]) and close[0]>open[1] ? #FF3D2E : na, title="Dark Cloud Cover")



//Morning Star (Body of the last candle is smaller than the penultimate candle. This causes less false signals)
morning_star = close[3]>close[2] and close[2]<open[2] and open[1]<close[2] and close[1]<close[2] and open[0]>open[1] and open[0]>close[1] and close[0]>close[2] and open[2]-close[2]>close[0]-open[0]
plotshape(morning_star,text='Morning Star', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(close[3]>close[2] and close[2]<open[2] and open[1]<close[2] and close[1]<close[2] and open[0]>open[1] and open[0]>close[1] and close[0]>close[2] and open[2]-close[2]>close[0]-open[0] ? #BEDB39 : na, title="Morning Star")
barcolor(close[3]>close[2] and close[2]<open[2] and open[1]<close[2] and close[1]<close[2] and open[0]>open[1] and open[0]>close[1] and close[0]>close[2] and open[2]-close[2]>close[0]-open[0] ? #BEDB39 : na, title="Morning Star-1", offset=-1)
barcolor(close[3]>close[2] and close[2]<open[2] and open[1]<close[2] and close[1]<close[2] and open[0]>open[1] and open[0]>close[1] and close[0]>close[2] and open[2]-close[2]>close[0]-open[0] ? #BEDB39 : na, title="Morning Star-2", offset=-2)

//Evening Star (Body of the last candle is smaller than the penultimate candle. This causes less false signals)
evening_star = close[3]<close[2] and close[2]>open[2] and open[1]>close[2] and close[1]>close[2] and open[0]<open[1] and open[0]<close[1] and close[0]<close[2] and close[2]-open[2]>open[0]-close[0]
plotshape(evening_star,text='Evening Star', style=shape.triangledown, color=#FF3D2E, editable=false)
barcolor(close[3]<close[2] and close[2]>open[2] and open[1]>close[2] and close[1]>close[2] and open[0]<open[1] and open[0]<close[1] and close[0]<close[2] and close[2]-open[2]>open[0]-close[0] ? #FF3D2E : na, title="Evening Star")
barcolor(close[3]<close[2] and close[2]>open[2] and open[1]>close[2] and close[1]>close[2] and open[0]<open[1] and open[0]<close[1] and close[0]<close[2] and close[2]-open[2]>open[0]-close[0] ? #FF3D2E : na, title="Evening Star-1", offset=-1)
barcolor(close[3]<close[2] and close[2]>open[2] and open[1]>close[2] and close[1]>close[2] and open[0]<open[1] and open[0]<close[1] and close[0]<close[2] and close[2]-open[2]>open[0]-close[0] ? #FF3D2E : na, title="Evening Star-2", offset=-2)



//Belt Hold Bullish
bullish_belt_hold = close[1]<open[1] and low[1]>open[0] and close[1]>open[0] and open[0]==low[0] and close[0]>avg(close[0],open[0])
plotshape(bullish_belt_hold,text='Belt Hold', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(close[1]<open[1] and low[1]>open[0] and close[1]>open[0] and open[0]==low[0] and close[0]>avg(close[0],open[0]) ? #BEDB39 : na, title="Belt Hold")

//Belt Hold Bearish
bearish_belt_hold = close[1]>open[1] and high[1]<open[0] and close[1]<open[0] and open[0]==high[0] and close[0]<avg(close[0],open[0])
plotshape(bearish_belt_hold,text='Belt Hold', style=shape.triangledown, color=#FF3D2E, editable=false)
barcolor(close[1]>open[1] and high[1]<open[0] and close[1]<open[0] and open[0]==high[0] and close[0]<avg(close[0],open[0]) ? #FF3D2E : na, title="Belt Hold")



//Aka Sanpei (Three White Soldiers) Bullish
aka_sanpei = close[3]<open[3] and open[2]<close[3] and close[2]>avg(close[2],open[2]) and open[1]>open[2] and open[1]<close[2] and close[1]>avg(close[1],open[1]) and open[0]>open[1] and open[0]<close[1] and close[0]>avg(close[0],open[0]) and high[1]>high[2] and high[0]>high[1]
plotshape(aka_sanpei,text='Aka Sanpei', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(close[3]<open[3] and open[2]<close[3] and close[2]>avg(close[2],open[2]) and open[1]>open[2] and open[1]<close[2] and close[1]>avg(close[1],open[1]) and open[0]>open[1] and open[0]<close[1] and close[0]>avg(close[0],open[0]) and high[1]>high[2] and high[0]>high[1] ? #BEDB39 : na, title="Aka Sanpei")
barcolor(close[3]<open[3] and open[2]<close[3] and close[2]>avg(close[2],open[2]) and open[1]>open[2] and open[1]<close[2] and close[1]>avg(close[1],open[1]) and open[0]>open[1] and open[0]<close[1] and close[0]>avg(close[0],open[0]) and high[1]>high[2] and high[0]>high[1] ? #BEDB39 : na, title="Aka Sanpei-1", offset=-1)
barcolor(close[3]<open[3] and open[2]<close[3] and close[2]>avg(close[2],open[2]) and open[1]>open[2] and open[1]<close[2] and close[1]>avg(close[1],open[1]) and open[0]>open[1] and open[0]<close[1] and close[0]>avg(close[0],open[0]) and high[1]>high[2] and high[0]>high[1] ? #BEDB39 : na, title="Aka Sanpei-2", offset=-2)

//Sanba garasu (Three Black Crows) bearish
sanba_garasu = close[3]>open[3] and open[2]>close[3] and close[2]<avg(close[2],open[2]) and open[1]<open[2] and open[1]>close[2] and close[1]<avg(close[1],open[1]) and open[0]<open[1] and open[0]>close[1] and close[0]<avg(close[0],open[0]) and low[1]<low[2] and low[0]<low[1]
plotshape(sanba_garasu,text='Sanba Garasu', style=shape.triangledown, color=#FF3D2E, editable=false)
barcolor(close[3]>open[3] and open[2]>close[3] and close[2]<avg(close[2],open[2]) and open[1]<open[2] and open[1]>close[2] and close[1]<avg(close[1],open[1]) and open[0]<open[1] and open[0]>close[1] and close[0]<avg(close[0],open[0]) and low[1]<low[2] and low[0]<low[1] ? #FF3D2E : na, title="Sanba Garasu")
barcolor(close[3]>open[3] and open[2]>close[3] and close[2]<avg(close[2],open[2]) and open[1]<open[2] and open[1]>close[2] and close[1]<avg(close[1],open[1]) and open[0]<open[1] and open[0]>close[1] and close[0]<avg(close[0],open[0]) and low[1]<low[2] and low[0]<low[1] ? #FF3D2E : na, title="Sanba Garasu-1", offset=-1)
barcolor(close[3]>open[3] and open[2]>close[3] and close[2]<avg(close[2],open[2]) and open[1]<open[2] and open[1]>close[2] and close[1]<avg(close[1],open[1]) and open[0]<open[1] and open[0]>close[1] and close[0]<avg(close[0],open[0]) and low[1]<low[2] and low[0]<low[1] ? #FF3D2E : na, title="Sanba Garasu-2", offset=-2)



//Three Stars in the South (kyoku no santen bashi)
tss = open[3]>close[3] and open[2]>close[2] and open[2]==high[2] and open[1]>close[1] and open[1]<open[2] and open[1]>close[2] and low[1]>low[2] and open[1]==high[1] and open[0]>close[0] and open[0]<open[1] and open[0]>close[1] and open[0]==high[0] and close[0]==low[0] and close[0]>=low[1]
plotshape(tss,text='3 Stars South', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(open[3]>close[3] and open[2]>close[2] and open[2]==high[2] and open[1]>close[1] and open[1]<open[2] and open[1]>close[2] and low[1]>low[2] and open[1]==high[1] and open[0]>close[0] and open[0]<open[1] and open[0]>close[1] and open[0]==high[0] and close[0]==low[0] and close[0]>=low[1] ? #BEDB39 : na, title="3 Stars South")




//Stick Sandwich (Bullish)
stick_sandwich = open[2]>close[2] and open[1]>close[2] and open[1]<close[1] and open[0]>close[1] and open[0]>close[0] and close[0]==close[2]
plotshape(stick_sandwich,text='Stick Sandwich', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(open[2]>close[2] and open[1]>close[2] and open[1]<close[1] and open[0]>close[1] and open[0]>close[0] and close[0]==close[2] ? #BEDB39 : na, title="Stick Sandwich")
barcolor(open[2]>close[2] and open[1]>close[2] and open[1]<close[1] and open[0]>close[1] and open[0]>close[0] and close[0]==close[2] ? #BEDB39 : na, title="Stick Sandwich-1", offset=-1)
barcolor(open[2]>close[2] and open[1]>close[2] and open[1]<close[1] and open[0]>close[1] and open[0]>close[0] and close[0]==close[2] ? #BEDB39 : na, title="Stick Sandwich-2", offset=-2)




//Meeting Line Bullish
bullish_ml = open[2]>close[2] and open[1]>close[1] and close[1]==close[0] and open[0]<close[0] and open[1]>=high[0]
plotshape(bullish_ml,text='Meeting Line', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(bullish_ml ? #BEDB39 : na, title="Meeting Line")
barcolor(bullish_ml ? #BEDB39 : na, title="Meeting Line-1", offset=-1)

//Meeting Line Bearish
bearish_ml = open[2]<close[2] and open[1]<close[1] and close[1]==close[0] and open[0]>close[0] and open[1]<=low[0]
plotshape(bearish_ml,text='Meeting Line', style=shape.triangledown, color=#FF3D2E, editable=false)
barcolor(bearish_ml ? #FF3D2E : na, title="Meeting Line")
barcolor(bearish_ml ? #FF3D2E : na, title="Meeting Line-1", offset=-1)




//Kicking Bullish
bullish_kicking = open[1]>close[1] and open[1]==high[1] and close[1]==low[1] and open[0]>open[1] and open[0]==low[0] and close[0]==high[0] and close[0]-open[0]>open[1]-close[1]
plotshape(bullish_kicking,text='Kicking', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(bullish_kicking ? #BEDB39 : na, title="Kicking")

//Kicking Bearish
bearish_kicking = open[1]<close[1] and open[1]==low[1] and close[1]==high[1] and open[0]<open[1] and open[0]==high[0] and close[0]==low[0] and open[0]-close[0]>close[1]-open[1]
plotshape(bearish_kicking,text='Kicking', style=shape.triangledown, color=#FF3D2E, editable=false)
barcolor(bearish_kicking ? #FF3D2E : na, title="Kicking")



//Ladder Bottom (Bullish)
ladder_bottom = open[4]>close[4] and open[3]>close[3] and open[3]<open[4] and open[2]>close[2] and open[2]<open[3] and open[1]>close[1] and open[1]<open[2] and open[0]<close[0] and open[0]>open[1] and low[4]>low[3] and low[3]>low[2] and low[2]>low[1]
plotshape(ladder_bottom,text='Ladder Bottom', style=shape.triangleup, color=#BEDB39, editable=false)
barcolor(ladder_bottom ? #BEDB39 : na, title="Ladder Bottom")
barcolor(ladder_bottom ? #BEDB39 : na, title="Ladder Bottom-1", offset=-1)
barcolor(ladder_bottom ? #BEDB39 : na, title="Ladder Bottom-2", offset=-2)
barcolor(ladder_bottom ? #BEDB39 : na, title="Ladder Bottom-3", offset=-3)
barcolor(ladder_bottom ? #BEDB39 : na, title="Ladder Bottom-4", offset=-4)





```
