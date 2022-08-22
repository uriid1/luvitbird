local luvitbird = { _version = "1.0" }

luvitbird.host = "0.0.0.0"
luvitbird.port = 8000

luvitbird.lines = {}
luvitbird.maxlines = 200

luvitbird.loadstring = loadstring or load
luvitbird.buffer = ""
luvitbird.updateinterval = 0.5
luvitbird.debug = false
luvitbird.wrapprint = true
luvitbird.timestamp = true
luvitbird.allowhtml = false
luvitbird.echoinput = true

-- inspect table
luvitbird.inspect = {
    _G = _G;
    luvitbird = luvitbird;
}
_G.inspect = luvitbird.inspect

-- Libs
local path = require('path')
local net = require('net')
local fs  = require('fs')

--
luvitbird.pages = {}
luvitbird.pages["buffer"]   = [[ <?luvit echo(luvitbird.buffer) ?> ]]
luvitbird.pages["index"]    = fs.readFileSync(path.join(module.dir, 'pages', 'index.html'), 'rb')
luvitbird.pages["env.json"] = fs.readFileSync(path.join(module.dir, 'pages', 'env.json'), 'rb')

local function dprint(...)
    if luvitbird.debug then
        p(...)
    end
end

-- Add table to inspect
function luvitbird.toinspect(name, tbl)
    luvitbird.inspect[name] = tbl
end
luvitbird.toinspect('luvitbird', luvitbird)

-- Обработка ошибок
function luvitbird.onerror(err)
    -- Отправит результат выполнения
    luvitbird.pushline({ type = "error", str = err })

    -- Скажет в консоле, что произошла ошибка
    if luvitbird.wrapprint then
        luvitbird.origprint("[luvitbird] ERROR: " .. err)
    end
end


function luvitbird.onrequest(req, client)
  local page = req.parsedurl.path
  page = page ~= "" and page or "index"

  -- Handle "page not found"
  if not luvitbird.pages[page] then
    return "HTTP/1.1 404\r\nContent-Length: 8\r\n\r\nBad page"
  end

  -- Handle page
  local str
  xpcall(function()
    local data = luvitbird.pages[page](luvitbird, req)
    local contenttype = "text/html"
    if string.match(page, "%.json$") then
      contenttype = "application/json"
    end
    str = "HTTP/1.1 200 OK\r\n" ..
          "Content-Type: " .. contenttype .. "\r\n" ..
          "Content-Length: " .. #data .. "\r\n" ..
          "\r\n" .. data
  end, luvitbird.onerror)

  return str
end


function luvitbird.unescape(str)
    local f = function(x)
        return string.char(tonumber("0x"..x))
    end
    return (str:gsub("%+", " "):gsub("%%(..)", f))
end


function luvitbird.trace(...)
    local str = "[luvitbird] " .. table.concat(luvitbird.map({...}, tostring), " ")

    if not luvitbird.wrapprint then
        luvitbird.print(str)
    end
end


function luvitbird.parseurl(url)
    local res = {}
    res.path, res.search = url:match("/([^%?]*)%??(.*)")
    res.query = {}

    for k, v in res.search:gmatch("([^&^?]-)=([^&^#]*)") do
        res.query[k] = luvitbird.unescape(v)
    end

    return res
end


local htmlescapemap = {
  ["<"] = "&lt;",
  ["&"] = "&amp;",
  ['"'] = "&quot;",
  ["'"] = "&#039;",
}


function luvitbird.htmlescape(str)
    return ( str:gsub("[<&\"']", htmlescapemap) )
end


function luvitbird.truncate(str, len)
    if #str <= len then
        return str
    end
    return str:sub(1, len - 3) .. "..."
end


function luvitbird.clear()
    luvitbird.lines = {}
    luvitbird.buffer = ""
end


function luvitbird.compare(a, b)
    local na, nb = tonumber(a), tonumber(b)
    if na then
        if nb then
            return na < nb
        end
        return false
    elseif nb then
        return true
    end

    return tostring(a) < tostring(b)
end


function luvitbird.map(t, fn)
  local res = {}
  for k, v in pairs(t) do
    res[k] = fn(v)
  end
  return res
end


function luvitbird.recalcbuffer()
    local function doline(line)
        local str = line.str
        
        if not luvitbird.allowhtml then
            str = luvitbird.htmlescape(line.str):gsub("\n", "<br>")
        end

        if line.type == "input" then
            str = '<span class="inputline">'..str..'</span>'
        else
            if line.type == "error" then
                str = '<span class="errormarker">!</span> '..str
                str = '<span class="errorline">'..str..'</span>'
            end

            if line.count > 1 then
                str = '<span class="repeatcount">'..line.count..'</span> '..str
            end

            if luvitbird.timestamp then
                str = os.date('<span class="timestamp">%H:%M:%S</span> ', line.time)..str
            end
        end

        return str
    end

    luvitbird.buffer = table.concat(luvitbird.map(luvitbird.lines, doline), "<br>")
end


function luvitbird.pushline(line)
    line.time = os.time()
    line.count = 1

    table.insert(luvitbird.lines, line)
    if #luvitbird.lines > luvitbird.maxlines then
        table.remove(luvitbird.lines, 1)
    end

    luvitbird.recalcbuffer()
end


function luvitbird.template(str, params, chunkname)
    params = params and ("," .. params) or ""
    local f = function(x)
        return string.format(" echo(%q)", x)
    end

    str = ("?>"..str.."<?luvit"):gsub("%?>(.-)<%?luvit", f)
    str = "local echo " .. params .. " = ..." .. str

    local fn = assert(luvitbird.loadstring(str, chunkname))
    return function(...)
        local output = {}
        local echo = function(str)
            table.insert(output, str)
        end
        fn(echo, ...)
        return table.concat(luvitbird.map(output, tostring))
    end
end


function luvitbird.onconnect(client, chunk)
    -- Create request table
    local requestptn = "(%S*)%s*(%S*)%s*(%S*)"
    local req = {}

    req.socket = client
    req.addr, req.port = client:getsockname().ip, client:getsockname().port
    req.request = chunk:match("[^\n\r]+")
    req.method, req.url, req.proto = req.request:match(requestptn)
    req.headers = {}

    -- Parse headers
    for line in chunk:gmatch("[^\n]+") do
        for k, v in line:gmatch("(.-):%s*(.*)$") do
            req.headers[k] = v
        end
    end

    -- 'input=print(123)'
    if req.headers["Content-Length"] then
        local res = chunk:match('input=(.+)$')
        if res then
            req.body = 'input=' .. res
        end 
    end

    -- Parse body
    req.parsedbody = {}
    if req.body then
        for k, v in req.body:gmatch("([^&]-)=([^&^#]*)") do
          req.parsedbody[k] = luvitbird.unescape(v)
        end
    end

    -- Parse request line's url
    req.parsedurl = luvitbird.parseurl(req.url)

    -- Handle request; get data to send and send
    local data = luvitbird.onrequest(req)
    client:write(data)
end

function luvitbird.print(...)
    local t = {}
    for i = 1, select("#", ...) do
        table.insert(t, tostring(select(i, ...)))
    end

    local str = table.concat(t, " ")
    local last = luvitbird.lines[#luvitbird.lines]
    
    if last and str == last.str then
        -- Update last line if this line is a duplicate of it
        last.time = os.time()
        last.count = last.count + 1
        luvitbird.recalcbuffer()
    else
        -- Create new line
        luvitbird.pushline({ type = "output", str = str })
    end
end


function luvitbird:init()
    -- Start the server
    local server = net.Server:new()
    server:listen(luvitbird.port, luvitbird.host)


    -- Compile page templates
    for k, page in pairs(luvitbird.pages) do
        luvitbird.pages[k] = luvitbird.template(page, "luvitbird, req", "pages." .. k)
    end


    -- Wrap print
    luvitbird.origprint = print
    if luvitbird.wrapprint then
        local oldprint = print
        print = function(...)
            oldprint(...)
            luvitbird.print(...)
        end
        _G.print = print
    end


    server:on('connection', function(socket)
        dprint('[luvitbird] New connection.')

        -- Init
        luvitbird.addr, luvitbird.port = socket:getsockname().ip, socket:getsockname().port

        -- data
        socket:on('data', function(chunk)
            luvitbird.onconnect(socket, chunk)
        end)

        -- ends the connection.
        socket:on('end', function()
            dprint('[luvitbird] Closing connection with the client')
        end)

        -- Don't forget to catch error, for your own sake.
        socket:on('error', function(err)
            dprint('[luvitbird] Error: ', err)
        end)

        socket:on('close', function(err)
            dprint('[luvitbird] Close')
        end)
    end)
end

return luvitbird