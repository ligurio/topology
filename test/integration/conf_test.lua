local conf_lib = require('conf')
local fio = require('fio')
local http_client_lib = require('http.client')
local t = require('luatest')
local Process = require('luatest.process')

local bool = require 'lqc.generators.bool'
local byte = require 'lqc.generators.byte'
local char = require 'lqc.generators.char'
local float = require 'lqc.generators.float'
local int = require 'lqc.generators.int'
local str = require 'lqc.generators.string'

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
    random.seed()
    lqc.init(100, 100)
    lqc.properties = {}
    r.report = function() end
end)

g.after_each(function()
    g.conf_client = nil
end)

-- {{{ str value

g.test_string_value = function()
    property 'roundtrip with set and get string value' {
        generators = { str() },
        check = function(v)
            g.conf_client:set('string', v)
            t.assert_equals(g.conf_client:get('string').data, v)
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} str value

-- {{{ byte value

g.test_byte_value = function()
    property 'roundtrip with set and get byte value' {
        generators = { byte() },
        check = function(v)
            g.conf_client:set('byte', v)
            t.assert_equals(g.conf_client:get('byte').data, v)
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} byte value

-- {{{ boolean value

g.test_boolean_value = function()
    property 'roundtrip with set and get boolean  value' {
        generators = { bool() },
        check = function(v)
            g.conf_client:set('boolean', v)
            t.assert_equals(g.conf_client:get('boolean').data, v)
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} boolean value

-- {{{ int value

g.test_int_value = function()
    property 'roundtrip with set and get int value' {
        generators = { int() },
        check = function(v)
            g.conf_client:set('int', v)
            t.assert_equals(g.conf_client:get('int').data, v)
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} int value

-- {{{ float value

g.test_float_value = function()
    property 'roundtrip with set and get float value' {
        generators = { float() },
        check = function(v)
            g.conf_client:set('float', v)
            t.assert_equals(tostring(g.conf_client:get('float').data), tostring(v))
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} float value

-- {{{ char value

g.test_char_value = function()
    property 'roundtrip with set and get char value' {
        generators = { char() },
        check = function(v)
            g.conf_client:set('char', v)
            t.assert_equals(g.conf_client:get('char').data, v)
        end
    }
    lqc.check()
    t.assert_equals(1, #lqc.properties)
end

-- }}} char value
