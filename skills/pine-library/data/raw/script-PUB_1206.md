---
id: PUB;1206
title: [RS][JR]RSI Ribbon + Candle
author: QuantitativeExhaustion
type: indicator
tags: []
boosts: 740
views: 0
has_source: true
scraped_at: 2026-02-13
slug: script-PUB_1206
---

# Description
[RS][JR]RSI Ribbon + Candle

# Source Code
```pine
study(title="[RS][JR]RSI Ribbon + Candle", shorttitle="[RS][JR]RSI.MA", overlay=false)

//  ||-----------------------------------------------------------
//  ||---   Inputs:
//  ||-----------------------------------------------------------
src = input(defval=close, type=source, title="RSI Source:")
fast_rsi_length = input(defval=14, minval=1, title="Fast RSI Period Length:")
ma_length_scalar = input(defval=2, minval=1, title="MA Period Length Incremental Scalar:")
exponential = input(true, title="Exponential MA Set 1?")
//  ||-----------------------------------------------------------
//  ||---   RSI MA Function:
//  ||-----------------------------------------------------------
isExpMA(isExp, src, length) => isExp ? ema(src, length) : sma(src, length)
//  ||-----------------------------------------------------------
//  ||---   RSI MA Function:
//  ||-----------------------------------------------------------
rsiMA_barColor(tpower) =>
        tpower >= 10 and tpower < 20 ? green :
        tpower >= 4 and tpower < 10 ? lime :
        tpower >= -4 and tpower < 4 ? yellow :
        tpower <= -4 and tpower > -10 ? red :
        tpower <= -10 and tpower > -20 ? maroon : na
//  ||-----------------------------------------------------------
//  ||---   RSI MA Trend Line Strength Function:
//  ||-----------------------------------------------------------
maRank(ma, maRef1, maRef2) => 
              change(ma)>=0 and maRef1>maRef2 ? +1
            : change(ma)<0  and maRef1>maRef2 ? -1
            : change(ma)<=0 and maRef1<maRef2 ? -2
            : change(ma)>=0 and maRef1<maRef2 ? +2
            : 0//  ||-----------------------------------------------------------
//  ||-----------------------------------------------------------
//  ||---   Usage:
//  ||---   barcolor(rsiMA_barColor(true, rsi(close, 14), 30, 50))
//  ||-----------------------------------------------------------
//  ||-----------------------------------------------------------
//  ||---   RSI Basis:
//  ||-----------------------------------------------------------
fast_rsi = rsi(src, fast_rsi_length)

plot(fast_rsi, color=black)
//  ||-----------------------------------------------------------
//  ||---   MA's:
//  ||-----------------------------------------------------------

src0 = (fast_rsi)

ma01 = isExpMA(exponential, fast_rsi, ma_length_scalar)
ma02 = isExpMA(exponential, fast_rsi, ma_length_scalar*2)
ma03 = isExpMA(exponential, fast_rsi, ma_length_scalar*4)
ma04 = isExpMA(exponential, fast_rsi, ma_length_scalar*8)
ma05 = isExpMA(exponential, fast_rsi, ma_length_scalar*16)
ma06 = isExpMA(exponential, fast_rsi, ma_length_scalar*32)
ma07 = isExpMA(exponential, fast_rsi, ma_length_scalar*64)
ma08 = isExpMA(exponential, fast_rsi, ma_length_scalar*128)
ma09 = isExpMA(exponential, fast_rsi, ma_length_scalar*256)


maColor(ma, maRef) => 
              change(ma)>=0 and ma02>maRef ? lime
            : change(ma)<0  and ma02>maRef ? red
            : change(ma)<=0 and ma02<maRef ? maroon
            : change(ma)>=0 and ma02<maRef ? green
            : gray
            
plot( ma01, color=maColor(ma01,ma09), style=line, title="MMA05", linewidth=1)
plot( ma02, color=maColor(ma02,ma09), style=line, title="MMA30", linewidth=2)
plot( ma03, color=maColor(ma03,ma09), style=line, title="MMA50", linewidth=3)
plot( ma04, color=maColor(ma04,ma09), style=line, title="MMA70", linewidth=4)
plot( ma05, color=maColor(ma05,ma09), style=line, title="MMA90", linewidth=4)
plot( ma06, color=maColor(ma06,ma09), style=line, title="MMA90", linewidth=3)
plot( ma07, color=maColor(ma07,ma09), style=line, title="MMA90", linewidth=2)
plot( ma08, color=maColor(ma08,ma09), style=line, title="MMA90", linewidth=1)

//plot( ma01, color=maColor(ma01,ma09), style=columns, title="MMA05", transp=70, histbase=50)
//plot( ma02, color=maColor(ma02,ma09), style=columns, title="MMA30", transp=70, histbase=50)
//plot( ma03, color=maColor(ma03,ma09), style=columns, title="MMA50", transp=70, histbase=50)
//plot( ma04, color=maColor(ma04,ma09), style=columns, title="MMA70", transp=70, histbase=50)
//plot( ma05, color=maColor(ma05,ma09), style=columns, title="MMA90", transp=70, histbase=50)
//plot( ma06, color=maColor(ma06,ma09), style=columns, title="MMA90", transp=70, histbase=50)
//plot( ma07, color=maColor(ma07,ma09), style=columns, title="MMA90", transp=70, histbase=50)
//plot( ma08, color=maColor(ma08,ma09), style=columns, title="MMA90", transp=70, histbase=50)

//  ||-----------------------------------------------------------
//  ||---   Bar Color:
//  ||-----------------------------------------------------------
hline(0, color=black, title="RSI 0 Line")
hline(50, color=black, title="RSI 50 Line")
hline(100, color=black, title="RSI 100 Line")
//  ||-----------------------------------------------------------
//  ||---   Bar Color:
//  ||-----------------------------------------------------------
ma_TPower = maRank(ma01, ma02, ma09) + maRank(ma02, ma02, ma09) + maRank(ma03, ma02, ma09) + maRank(ma04, ma02, ma09) + maRank(ma05, ma02, ma09) + maRank(ma06, ma02, ma09) + maRank(ma07, ma02, ma09) + maRank(ma08, ma02, ma09)

barcolor(rsiMA_barColor(ma_TPower))

```
