package.path = 'conf/?.lua;conf/?/init.lua;' .. package.path
local conf_lib = require('conf')
local fio = require('fio')
local http_client_lib = require('http.client')
local t = require('luatest')
local Process = require('luatest.process')

local any = require 'lqc.generators.any'
local lqc = require 'lqc.quickcheck'
local property = require 'lqc.property'
local random = require 'lqc.random'
local r = require 'lqc.report'

local DEFAULT_ENDPOINT = 'http://localhost:2379'

local g = t.group()

-- {{{ Setup / teardown

g.before_all(function()
    -- Wake up etcd.
    local etcd_bin = tostring(os.getenv("ETCD_PATH")) .. '/etcd'
    if not fio.path.exists(etcd_bin) then
        etcd_bin = '/usr/bin/etcd'
        t.assert_equals(fio.path.exists(etcd_bin), true)
    end
    g.etcd_datadir = fio.tempdir()
    g.etcd_process = Process:start(etcd_bin, {}, {
        ETCD_DATA_DIR = g.etcd_datadir,
        ETCD_LISTEN_CLIENT_URLS = DEFAULT_ENDPOINT,
        ETCD_ADVERTISE_CLIENT_URLS = DEFAULT_ENDPOINT,
    }, {
        output_prefix = 'etcd',
    })
    t.helpers.retrying({}, function()
        local url = DEFAULT_ENDPOINT .. '/v3/cluster/member/list'
        local response = http_client_lib.post(url)
        t.assert(response.status == 200, 'etcd started')
    end)
end)

g.after_all(function()
    -- Tear down etcd.
    g.etcd_process:kill()
    t.helpers.retrying({}, function()
        t.assert_not(g.etcd_process:is_alive(), 'etcd is still running')
    end)
    g.etcd_process = nil
    fio.rmtree(g.etcd_datadir)
end)

g.before_each(function()
    local urls = { DEFAULT_ENDPOINT }
    g.conf_client = conf_lib.new(urls, {driver = 'etcd'})
    assert(g.conf_client ~= nil)

    -- lqc initialization
    random.seed()
    lqc.init(100, 100)
    lqc.properties = {}
    r.report = function() end
end)

g.after_each(function()
    g.conf_client = nil
end)

-- {{{ set_get_value

g.test_set_get_value = function()
    property 'set and get in configuration' {
        generators = { any() },
        check = function(v)
            local key = 'a'
            g.conf_client:set(key, v)
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} set_get_value
