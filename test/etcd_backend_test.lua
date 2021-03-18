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
    -- cfg() is not available on 1.10
    pcall(log.cfg, {level = 6})

    -- Wake up etcd.
    local etcd_bin = '/usr/bin/etcd'
    if not fio.path.exists(etcd_bin) then
        etcd_bin = '/tmp/etcd/etcd'
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

    -- Create a topology.
    g.topology = topology.new('xxx', {backend = {endpoints = {DEFAULT_ENDPOINT}},
                                      backend_type = 'etcd'})
    assert(g.topology ~= nil)
end)

g.after_all(function()
    -- Remove the topology.
    g.topology:delete()
    g.topology = nil

    -- Tear down etcd.
    g.etcd_process:kill()
    t.helpers.retrying({}, function()
        t.assert_not(g.etcd_process:is_alive(), 'etcd is still running')
    end)
    g.etcd_process = nil
    fio.rmtree(g.etcd_datadir)
end)

-- }}} Setup / teardown

-- {{{ Helpers


-- }}} Helpers

-- {{{ new_server

g.test_new_server = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:new_server()
    t.assert_equals(response, nil)
end

-- }}} new_server

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

-- {{{ new_instance_link

g.test_new_instance_link = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:new_instance_link()
    t.assert_equals(response, nil)
end

-- }}} new_instance_link

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

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:delete_instance_link()
    t.assert_equals(response, nil)
end

-- }}} delete_instance_link

-- {{{ set_instance_property

g.test_set_instance_property = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:set_instance_property()
    t.assert_equals(response, nil)
end

-- }}} set_instance_property

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:set_instance_reachable()
    t.assert_equals(response, nil)
end

-- }}} set_instance_reachable

-- {{{ set_instance_unreachable

g.test_set_instance_unreachable = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:set_instance_unreachable()
    t.assert_equals(response, nil)
end

-- }}} set_instance_unreachable

-- {{{ set_topology_property

g.test_set_topology_property = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:set_topology_property()
    t.assert_equals(response, nil)
end

-- }}} set_topology_property

-- {{{ get_routers

g.test_get_routers = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:get_routers()
    t.assert_equals(response, nil)
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:get_storages()
    t.assert_equals(response, nil)
end

-- }}} get_storages

-- {{{ get_instance_conf

g.test_get_instance_conf = function()
    local key = gen_key()
    local value = gen_value()

    local response = g.topology:get_instance_conf()
    t.assert_equals(response, nil)
end

-- }}} get_instance_conf
