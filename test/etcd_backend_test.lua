local constants = require('topology.constants')
local fio = require('fio')
local http_client_lib = require('http.client')
local log = require('log')
local math = require('math')
local t = require('luatest')
local topology = require('topology.topology')
local Process = require('luatest.process')

local seed = os.getenv("SEED")
if not seed then
    seed = os.time()
end
math.randomseed(seed)

local DEFAULT_ENDPOINT = 'http://localhost:2379'

local g = t.group()

-- {{{ Data generators

-- Generate a pseudo-random string
local function gen_string(length)
    local symbols = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local length = length or 10
    local string = ''
    local t = {}
    symbols:gsub(".",function(c) table.insert(t, c) end)
    for _ = 1, length do
        string = string .. t[math.random(1, #t)]
    end

    return string
end

-- }}} Data generators

-- {{{ Setup / teardown

g.before_all(function()
    -- Show logs from the etcd transport.
    -- cfg() is not available on 1.10
    pcall(log.cfg, {level = 6})

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

    -- Create a topology.
    local topology_name = gen_string()
    g.topology = topology.new(topology_name, {endpoints = {DEFAULT_ENDPOINT},
                                              driver = 'etcd'})
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
    local instance_name = gen_string()
    local response = g.topology:new_server(instance_name)
    t.assert_equals(response, nil)
end

-- }}} new_server

-- {{{ new_instance

g.test_new_instance = function()
    -- TODO: check new_instance() wo name and wo opts
    -- TODO: check new_instance() with non-string name
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    local box_cfg = {memtx_memory = 268435456}
    local opts = {box_cfg = box_cfg,
                  distance = 13,
                  is_master = true,
                  is_storage = false,
                  is_router = false,
                  zone = 13,
                 }
    g.topology:new_instance(instance_name, replicaset_name, opts)
end

-- }}} new_instance

-- {{{ new_replicaset

g.test_new_replicaset = function()
    local opts = {master_mode = constants.MASTER_MODE.MODE_AUTO,
                  failover_priority = {},
                  weight = 1}
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name, opts)
end

-- }}} new_replicaset

-- {{{ new_instance_link

g.test_new_instance_link = function()
    local instance_name = gen_string()
    local instances = { gen_string(), gen_string() }

    local response = g.topology:new_instance_link(instance_name, instances)
    t.assert_equals(response, nil)
end

-- }}} new_instance_link

-- {{{ delete_replicaset

g.test_delete_replicaset = function()
    local opts = {}
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name, opts)
    g.topology:delete_replicaset(replicaset_name)
    -- TODO: test an attempt to remove replicaset that contains instance(s)
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:delete_instance(instance_name)
end

-- }}} delete_instance

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
    local instance_name = gen_string()
    local instances = { gen_string(), gen_string() }
    g.topology:new_instance_link(instance_name, instances)
    g.topology:delete_instance_link()
end

-- }}} delete_instance_link

-- {{{ set_instance_property

g.test_set_instance_property = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    local opts = {}
    local response = g.topology:set_instance_property(instance_name, opts)
    t.assert_equals(response, nil)
end

-- }}} set_instance_property

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    local opts = {}
    g.topology:set_instance_property(instance_name, opts)
end

-- }}} set_instance_reachable

-- {{{ set_instance_unreachable

g.test_set_instance_unreachable = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    local opts = {}
    g.topology:set_instance_property(instance_name, opts)
end

-- }}} set_instance_unreachable

-- {{{ set_replicaset_property

g.test_set_replicaset_property = function()
    local replicaset_name = gen_string()
    local opts = {}
    g.topology:new_replicaset(replicaset_name, opts)
    local opts = {master_mode = constants.MASTER_MODE.MODE_AUTO}
    g.topology:new_replicaset(replicaset_name, opts)
    g.topology:set_replicaset_property(replicaset_name, opts)
end

-- }}} set_replicaset_property


-- {{{ set_topology_property

g.test_set_topology_property = function()
    local opts = {}
    g.topology:set_topology_property(opts)
end

-- }}} set_topology_property

-- {{{ get_routers

g.test_get_routers = function()
    -- create topology
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    -- create topology
end

-- }}} get_storages

-- {{{ get_instance_conf

g.test_get_instance_conf = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:get_instance_conf(instance_name)
end

-- }}} get_instance_conf
