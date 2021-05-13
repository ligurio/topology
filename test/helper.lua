require('strict').on()

local fio = require('fio')
local digest = require('digest')
local helpers = table.copy(require('test-helpers'))
local t = require('luatest')

t.configure({shuffle = 'group'})

helpers.project_root = fio.dirname(debug.sourcedir())

local __fio_tempdir = fio.tempdir
fio.tempdir = function(base)
    base = base or os.getenv('TMPDIR')
    if base == nil or base == '/tmp' then
        return __fio_tempdir()
    else
        local random = digest.urandom(9)
        local suffix = digest.base64_encode(random, {urlsafe = true})
        local path = fio.pathjoin(base, 'tmp.topology.' .. suffix)
        fio.mktree(path)
        return path
    end
end

function helpers.entrypoint(name)
    local path = fio.pathjoin(
        helpers.project_root,
        'test', 'entrypoint',
        string.format('%s.lua', name)
    )
    if not fio.path.exists(path) then
        error(path .. ': no such entrypoint', 2)
    end
    return path
end

function helpers.box_cfg()
    if type(box.cfg) ~= 'function' then
        return
    end

    local tempdir = fio.tempdir()
    box.cfg({
        memtx_dir = tempdir,
        wal_mode = 'none',
    })
    fio.rmtree(tempdir)
end

-- Generate a pseudo-random string
function helpers.gen_string(length)
    local symbols = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local length = length or 10
    local string = ''
    local t = {}
    symbols:gsub(".", function(c) table.insert(t, c) end)
    for _ = 1, length do
        string = string .. t[math.random(1, #t)]
    end

    return string
end

return helpers
