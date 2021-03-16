local fio = require('fio')
local t = require('luatest')
local topology = require('topology.topology')

local g = t.group()

-- {{{ Data generators

local kv_next = 1

local function gen_value(opts)
    local opts = opts or {}
    local res = 'value_' .. tostring(kv_next)
    if opts.size then
        res = res .. '_'
        for i = 1, opts.size - string.len(res) do
            res = res .. string.char(i % 256)
        end
    end
    kv_next = kv_next + 1
    return res
end

-- }}} Data generators

-- {{{ Setup / teardown

g.before_all(function()
    -- Create a topology.
    g.datadir = fio.tempdir()
    g.filename = gen_value()
    g.topology = topology.new({ filename = g.datadir .. g.filename })
end)

g.after_all(function()
    fio.rmtree(g.datadir)

    -- Remove the topology.
    --g.topology.delete()
    g.topology = nil
end)

-- }}} Setup / teardown
