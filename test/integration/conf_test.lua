local conf_lib = require('conf')
local fio = require('fio')
local http_client_lib = require('http.client')
local t = require('luatest')
local log = require('log')
local Process = require('luatest.process')

local bool = require 'lqc.generators.bool'
local byte = require 'lqc.generators.byte'
local char = require 'lqc.generators.char'
local int = require 'lqc.generators.int'
local str = require 'lqc.generators.string'
local tbl = require 'lqc.generators.table'

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
    g.conf_client = conf_lib.new({driver = 'etcd', endpoints = urls})
    assert(g.conf_client ~= nil)

    -- lqc initialization
    random.seed(os.time())
    lqc.init(100, 100)
    lqc.properties = {}
    r.report = function() end
end)

g.after_each(function()
    g.conf_client = nil
end)

local check_key = function(k)
    log.info(string.format('Key: "%s"', k))
    -- known issue
    if k == '.' then
        return
    end
    g.conf_client:set(k, 'value')
    t.assert_equals(g.conf_client:get(k).data, 'value')
end

local check_value = function(v)
    log.info(string.format('Value: "%s"', v))
    g.conf_client:set('key', v)
    t.assert_equals(g.conf_client:get('key').data, v)
end

g.test_value_byte = function()
    property 'roundtrip with set and get' {
        generators = { byte(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_value_bool = function()
    property 'roundtrip with set and get' {
        generators = { bool(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_value_char = function()
    property 'roundtrip with set and get' {
        generators = { char(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_value_int = function()
    property 'roundtrip with set and get' {
        generators = { int(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_value_tbl = function()
    t.skip('to be implemented')
    property 'roundtrip with set and get' {
        generators = { tbl(10) },
        check = check_value,
    }
    lqc.check()
end

g.test_value_str = function()
    property 'roundtrip with set and get' {
        generators = { str(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_key_char = function()
    property 'roundtrip with set and get' {
        generators = { char(1000) },
        check = check_key,
    }
    lqc.check()
end

g.test_key_str = function()
    t.skip('to be implemented')
    property 'roundtrip with set and get' {
        generators = { str(2) },
        check = check_key,
    }
    lqc.check()
end

g.test_key_byte = function()
    property 'roundtrip with set and get' {
        generators = { byte(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_key_bool = function()
    t.skip('to be implemented')
    property 'roundtrip with set and get' {
        generators = { bool(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_key_int = function()
    property 'roundtrip with set and get' {
        generators = { int(1000) },
        check = check_value,
    }
    lqc.check()
end

g.test_key_tbl = function()
    t.skip('to be implemented')
    property 'roundtrip with set and get' {
        generators = { tbl(10) },
        check = check_value,
    }
    lqc.check()
end
