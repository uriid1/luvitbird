# luvitbird
![Screenshot](https://github.com/uriid1/scrfmp/blob/main/luvitbird/luvitbird.png) <br>
A browser-based debug console for the luvit.<br>
Based on [lovebird](https://github.com/rxi/lovebird)<br>

## Usage
```lua
local lb = require('./luvitbird')
lb:init()
```
The console can then be accessed by opening the following URL in a web browser:
```
http://0.0.0.0:8000
```
### luvitbird.toinspect
Adds a table to `_G.inspect` for display in the console and further debugging

### luvitbird.port
The port which luvitbird listens for connections on. By default this is `8000`

### luvitbird.wrapprint
Whether luvitbird should wrap the `print()` function or not. If this is true
then all the calls to print will also be output to luvitbird's console. This is
`true` by default.

### luvitbird.echoinput
Whether luvitbird should display inputted commands in the console's output
buffer; `true` by default.

### luvitbird.maxlines
The maximum number of lines luvitbird should store in its console's output
buffer. By default this is `200`.

### luvitbird.updateinterval
The interval in seconds that the page's information is updated; this is `0.5`
by default.

### luvitbird.allowhtml
Whether prints should allow HTML. If this is true then any HTML which is
printed will be rendered as HTML; if it false then all HTML is rendered as
text. This is `false` by default.

### luvitbird.print(...)
Prints its arguments to luvitbird's console. If `luvitbird.wrapprint` is set to
true this function is automatically called when print() is called.

### luvitbird.clear()
Clears the contents of the console, returning it to an empty state.