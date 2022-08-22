local timer = require("timer")
local path = require('path')

-- Load and init luvitbird
local lb = require(path.join(module.dir, 'luvitbird'))
lb.host = "0.0.0.0"
lb.port = 8000
lb:init()

-- The table that we will check
local foo = {
    val = 0
}

lb.toinspect('foo', foo)

timer.setInterval(500, function()
    foo.val = foo.val + 1
end)