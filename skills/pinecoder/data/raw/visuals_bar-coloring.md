<!-- source: https://www.tradingview.com/pine-script-docs/visuals/bar-coloring -->
<!-- scraped: pine-script-docs v6 -->

[User Manual](/pine-script-docs)  / [Visuals](/pine-script-docs/visuals/overview) / Bar coloring        
# Bar coloring

The [barcolor()](https://www.tradingview.com/pine-script-reference/v6/#fun_barcolor) function colors bars on the main chart, regardless of whether the script is running in the main chart pane or a separate pane.

The function’s signature is:

```pine
barcolor(color, offset, editable, show_last, title, display) → void
```

The coloring can be conditional because the `color` parameter accepts “series color” arguments.

The following script renders *inside* and *outside* bars in different colors:

![image](/pine-script-docs/_astro/BarColoring-1.BVBRLjUu_2gjXX.webp)

[Pine Script®](https://tradingview.com/pine-script-docs)Copied`//@version=6indicator("barcolor example", overlay = true)isUp = close > openisDown = close <= openisOutsideUp = high > high[1] and low < low[1] and isUpisOutsideDown = high > high[1] and low < low[1] and isDownisInside = high < high[1] and low > low[1]barcolor(isInside ? color.yellow : isOutsideUp ? color.aqua : isOutsideDown ? color.purple : na)`

Note that:

- The [na](https://www.tradingview.com/pine-script-reference/v6/#var_na) value leaves bars as is.

- In the [barcolor()](https://www.tradingview.com/pine-script-reference/v6/#fun_barcolor) call, we use embedded [?:](https://www.tradingview.com/pine-script-reference/v6/#op_%7Bquestion%7D%7Bcolon%7D) ternary operator expressions to select the color.

        [Previous       Backgrounds](/pine-script-docs/visuals/backgrounds)  [Next   Bar plotting](/pine-script-docs/visuals/bar-plotting)