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
    -- note: log.cfg() is not available on tarantool 1.10
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
    local backend_opts = {
        endpoints = {DEFAULT_ENDPOINT},
        driver = 'etcd',
    }
    g.topology = topology.new(topology_name, backend_opts)
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
    -- TODO: check new_server() wo name and wo opts
    -- TODO: check new_server() with non-string name
    local server_name = gen_string()
    g.topology:new_server(server_name)
    -- TODO: add assert
end

-- }}} new_server

-- {{{ new_instance

g.test_new_instance = function()
    -- TODO: check new_instance() wo name and wo opts
    -- TODO: check new_instance() with non-string name
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    local box_cfg = { memtx_memory = 268435456 }
    local opts = {
	box_cfg = box_cfg,
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
    -- TODO:
    -- 1. add replicasets with same names
    local opts = {}
    local replicaset_1_name = gen_string()
    local replicaset_2_name = gen_string()
    g.topology:new_replicaset(replicaset_1_name, opts)
    g.topology:new_replicaset(replicaset_2_name, opts)
    local opt_1 = g.topology:get_replicaset_options(replicaset_1_name)
    local opt_2 = g.topology:get_replicaset_options(replicaset_2_name)
    t.assert_not_equals(opt_1.cluster_uuid, opt_2.cluster_uuid)
end

-- }}} new_replicaset

-- {{{ new_instance_link

g.test_new_instance_link = function()
    -- TODO:
    -- 1. check box_cfg.replication
    -- 2. check topology-specific and replicaset-specific box.cfg options
    -- 3. check replication in box.cfg['hot_standby'] it must contain all specified links
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    local instances = { gen_string(), gen_string() }
    g.topology:new_instance_link(instance_name, replicaset_name, instances)
end

-- }}} new_instance_link

-- {{{ delete_replicaset

g.test_delete_replicaset = function()
    -- TODO:
    -- 1. remove replicaset that contains instance(s)
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    local topology_opt = g.topology:get_topology_options()
    t.assert_items_include(topology_opt.replicasets, { replicaset_name })
    g.topology:delete_replicaset(replicaset_name)
    -- topology_opt = g.topology:get_topology_options(replicaset_name)
    -- t.assert_equals(topology_opt.replicasets, {})
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:delete_instance(instance_name, replicaset_name)
end

-- }}} delete_instance

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    local instances = { gen_string(), gen_string() }
    g.topology:new_instance_link(instance_name, replicaset_name, instances)
    g.topology:delete_instance_link(instance_name, replicaset_name, instances)
    -- TODO: check replication in box.cfg['hot_standby']
    -- it must contain all specified links
    -- local cfg = g.get_instance_conf(instance, replicaset_name)
    -- t.assert_equals()
end

-- }}} delete_instance_link

-- {{{ set_instance_property

g.test_set_instance_property = function()
    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    local instance_name = gen_string()
    local box_cfg = {
	replication_sync_timeout = 6,
	election_mode = 'off',
        wal_mode = 'write',
    }
    local opts = { is_storage = true, is_master = false, box_cfg = box_cfg }
    g.topology:new_instance(instance_name, replicaset_name, opts)

    local box_cfg = { replication_sync_timeout = 10 }
    local opts = { is_storage = false, is_master = true, box_cfg = box_cfg }
    g.topology:set_instance_property(instance_name, replicaset_name, opts)
    -- TODO: check new options
end

-- }}} set_instance_property

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:set_instance_reachable(instance_name, replicaset_name)
end

-- }}} set_instance_reachable

-- {{{ set_instance_unreachable

g.test_set_instance_unreachable = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    local opts = {}
    g.topology:set_instance_property(instance_name, replicaset_name, opts)
end

-- }}} set_instance_unreachable

-- {{{ set_replicaset_property

g.test_set_replicaset_property = function()
    -- create replicaset
    local replicaset_name = gen_string()
    local opts = {master_mode = constants.MASTER_MODE.AUTO}
    g.topology:new_replicaset(replicaset_name, opts)
    -- create instance
    local instance_name = gen_string()
    opts = {}
    -- check current master_mode
    g.topology:new_instance(instance_name, replicaset_name, opts)
    local cfg = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(cfg.master_mode, constants.MASTER_MODE.AUTO)
    -- set and check new master_mode
    opts = {master_mode = constants.MASTER_MODE.SINGLE}
    g.topology:set_replicaset_property(replicaset_name, opts)
    local cfg = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(cfg.master_mode, constants.MASTER_MODE.SINGLE)
end

-- }}} set_replicaset_property


-- {{{ set_topology_property

g.test_set_topology_property = function()
    local weights = {
        [1] = {
            [2] = 1, -- Zone 1 routers sees weight of zone 2 as 1.
            [3] = 2, -- Weight of zone 3 as 2.
            [4] = 3, -- ...
        },
        [2] = {
            [1] = 10,
            [2] = 0,
            [3] = 10,
            [4] = 20,
        },
        [3] = {
            [1] = 100,
            [2] = 200, -- Zone 3 routers sees weight of zone 2 as 200. Note
                       -- that it is not equal to weight of zone 2 visible from
                       -- zone 1.
            [4] = 1000,
        }
    }
    local opts = {
	is_bootstrapped = false,
	bucket_count = 154,
	rebalancer_disbalance_threshold = 13,
        rebalancer_max_receiving = 4,
        rebalancer_max_sending = 6,
        discovery_mode = 'on',
        sync_timeout = 3,
        collect_bucket_garbage_interval = 3,
        collect_lua_garbage = true,
        weights = weights,
        shard_index = 'v',
    }
    g.topology:set_topology_property(opts)
end

-- }}} set_topology_property

-- {{{ get_routers

g.test_get_routers = function()
    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    local instance_name = gen_string()
    local opts = { is_router = true }
    g.topology:new_instance(instance_name, replicaset_name, opts)

    -- local routers = g.topology:get_routers()
    -- FIXME
    -- t.assert_equals(routers[1], instance_name)
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    local instance_name = gen_string()
    local opts = { is_storage = true }
    g.topology:new_instance(instance_name, replicaset_name, opts)

    -- local storages = g.topology:get_storages()
    -- FIXME
    -- t.assert_equals(storages[1], instance_name)
end

-- }}} get_storages

-- {{{ get_replicaset_options

g.test_get_replicaset_options = function()
    -- create replicaset
    local replicaset_name = gen_string()
    local opts = {
	master_mode = constants.MASTER_MODE.SINGLE,
	-- FIXME
	-- failover_priority = true,
        weight =10,
    }
    g.topology:new_replicaset(replicaset_name, opts)

    local options = g.topology:get_replicaset_options(replicaset_name)
    opts.replicas = {}
    t.assert_equals(options, opts)
end

-- }}} get_replicaset_options

-- {{{ get_instance_conf

g.test_get_instance_conf = function()
    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    local instance_name = gen_string()
    local box_cfg = {
	replication_sync_timeout = 6,
	election_mode = 'off',
        -- FIXME
        --feedback_enabled = true,
        wal_mode = 'write',
    }
    local opts = { is_storage = true, is_master = false, box_cfg = box_cfg }
    g.topology:new_instance(instance_name, replicaset_name, opts)

    local cfg = g.topology:get_instance_conf(instance_name, replicaset_name)
    t.assert_equals(cfg, box_cfg)
end

-- }}} get_instance_conf

-- {{{ get_topology_options

g.test_set_topology_options = function()
    local opts = {
	is_bootstrapped = false,
	bucket_count = 154,
	rebalancer_disbalance_threshold = 13,
        rebalancer_max_receiving = 4,
        rebalancer_max_sending = 6,
        discovery_mode = 'on',
        sync_timeout = 3,
        collect_bucket_garbage_interval = 3,
        collect_lua_garbage = true,
        weights = true,
        shard_index = 'v',
    }
    g.topology:set_topology_property(opts)
    -- local cfg = g.topology:get_topology_options()
    -- FIXME
    -- t.assert_equals(cfg, opts)
end

-- }}} get_topology_options


-- {{{ gen_string

g.test_gen_string = function()
    local str1 = gen_string()
    local str2 = gen_string()
    local str3 = gen_string()
    t.assert_not_equals(str1, str2)
    t.assert_not_equals(str1, str3)
    t.assert_not_equals(str2, str3)
end

--- }}} gen_string
