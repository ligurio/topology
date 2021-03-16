local fio = require('fio')
local http_client_lib = require('http.client')
local log = require('log')
local t = require('luatest')
local topology = require('topology.topology')
local Process = require('luatest.process')

local DEFAULT_ENDPOINT = 'http://localhost:2379'

local g = t.group()

-- {{{ Data generators

local kv_next = 1

local function gen_key()
    local res = 'key_' .. tostring(kv_next)
    kv_next = kv_next + 1
    return res
end

local function gen_value()
    local res = 'value_' .. tostring(kv_next)
    kv_next = kv_next + 1
    return res
end

-- }}} Data generators

-- {{{ Setup / teardown

g.before_all(function()
    -- Show logs from the etcd transport.
    log.cfg({level = 6})

    -- Wake up etcd.
    g.etcd_datadir = fio.tempdir()
    g.etcd_process = Process:start('/usr/bin/etcd', {}, {
        ETCD_DATA_DIR = g.etcd_datadir,
        ETCD_LISTEN_CLIENT_URLS = DEFAULT_ENDPOINT,
        ETCD_ADVERTISE_CLIENT_URLS = DEFAULT_ENDPOINT,
    }, {
        output_prefix = 'etcd',
    })
    t.helpers.retrying({}, function()
        local url = DEFAULT_ENDPOINT .. '/v3/cluster/member/list'
        local response = http_client_lib.post(url)
        --t.assert(response.status == 200, 'etcd started')
    end)

    -- Create a topology.
    etcd_backend = { endpoints = { DEFAULT_ENDPOINT },
                     http_client = { request = { verbose = false,
                                                 verify_peer = false }},
                   }
    g.topology = topology.new({ backend = etcd_backend,
                                backend_type = 'etcd',
                                name = 'xxx' })
end)

g.after_all(function()
    -- Tear down etcd.
    g.etcd_process:kill()
    t.helpers.retrying({}, function()
        t.assert_not(g.etcd_process:is_alive(), 'etcd is still running')
    end)
    g.etcd_process = nil
    fio.rmtree(g.etcd_datadir)

    -- Remove the topology.
    --g.topology.delete()
    g.topology = nil
end)

-- }}} Setup / teardown

-- {{{ Helpers


-- }}} Helpers

-- {{{ new_instance

g.test_new_instance = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:new_instance()
    t.assert_equals(response, nil)
end

-- }}} new_instance

-- {{{ new_replicaset

g.test_new_replicaset = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:new_replicaset()
    t.assert_equals(response, nil)
end

-- }}} new_replicaset

-- {{{ delete_replicaset

g.test_delete_replicaset = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:delete_replicaset()
    t.assert_equals(response, nil)
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:delete_instance()
    t.assert_equals(response, nil)
end

-- }}} delete_instance
