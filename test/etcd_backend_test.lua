local constants = require('topology.client.constants')
local conf_lib = require('conf')
local fio = require('fio')
local http_client_lib = require('http.client')
local log = require('log')
local math = require('math')
local t = require('luatest')
local topology = require('topology')
local Process = require('luatest.process')

local DEFAULT_ENDPOINT = 'http://localhost:2379'

local g = t.group()

-- {{{ Data generators

-- Generate a pseudo-random string
local function gen_string(length)
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
    -- Create a topology.
    local topology_name = gen_string()
    local urls = { DEFAULT_ENDPOINT }
    g.conf_client = conf_lib.new({driver = 'etcd', endpoints = urls})
    g.topology = topology.new(g.conf_client, topology_name)
    assert(g.topology ~= nil)
end)

g.after_each(function()
    -- Remove the topology.
    g.topology:delete()
    g.topology = nil
    g.conf_client = nil
end)

-- }}} Setup / teardown

-- {{{ Helpers

-- }}} Helpers

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
    local instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_not_equals(instance_cfg.instance_uuid, nil)
end

-- }}} new_instance

-- {{{ new_replicaset

g.test_new_replicaset = function()
    -- TODO:
    -- 1. add replicasets with same names
    local replicaset_1_name = gen_string()
    local replicaset_2_name = gen_string()
    g.topology:new_replicaset(replicaset_1_name)
    g.topology:new_replicaset(replicaset_2_name)
    local opt_1 = g.topology:get_replicaset_options(replicaset_1_name)
    t.assert_not_equals(opt_1, nil)
    local opt_2 = g.topology:get_replicaset_options(replicaset_2_name)
    t.assert_not_equals(opt_2, nil)

    t.assert_not_equals(opt_1.cluster_uuid, nil)
    t.assert_not_equals(opt_2.cluster_uuid, nil)
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
    local instances = { gen_string(), gen_string() }
    g.topology:new_instance_link(instance_name, instances)
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
    topology_opt = g.topology:get_topology_options(replicaset_name)
    t.assert_equals(next(topology_opt.replicasets), nil)
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.replicas[1], instance_name)

    g.topology:delete_instance(instance_name)
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(next(replicaset_opts.replicas), nil)
end

-- }}} delete_instance

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
    local instance_name = gen_string()
    local instances = { gen_string(), gen_string() }
    g.topology:new_instance_link(instance_name, instances)
    g.topology:delete_instance_link(instance_name, instances)
    -- TODO: check replication in box.cfg['hot_standby']
    -- it must contain all specified links
    -- local cfg = g.get_instance_conf(instance)
    -- t.assert_equals()
end

-- }}} delete_instance_link

-- }}} delete_instance

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

    -- FIXME: special case - nested options should be merged too, not replaced by new table
    local box_cfg = { replication_sync_timeout = 10 }
    local opts = { is_storage = false, is_master = true, box_cfg = box_cfg }
    g.topology:set_instance_property(instance_name, opts)
    -- TODO: check new options
end

-- }}} set_instance_property

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:set_instance_reachable(instance_name)
end

-- }}} set_instance_reachable

-- {{{ set_instance_unreachable

g.test_set_instance_unreachable = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:set_instance_unreachable(instance_name)
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
        discovery_mode = 'on',
        sync_timeout = 3,
        collect_bucket_garbage_interval = 3,
        collect_lua_garbage = true,
        weights = weights,
    }
    g.topology:set_topology_property(opts)
    local cfg = g.topology:get_topology_options()
    t.assert_equals(cfg.discovery_mode, opts.discovery_mode)
end

-- }}} set_topology_property

-- {{{ get_routers

g.test_get_routers = function()
    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instances
    local instance_1_name = gen_string()
    local instance_2_name = gen_string()
    g.topology:new_instance(instance_1_name, replicaset_name,
                                { is_router = true })
    g.topology:new_instance(instance_2_name, replicaset_name,
                                { is_router = false, is_storage = true })

    local routers = g.topology:get_routers()
    t.assert_not_equals(routers, nil)
    t.assert_items_include(routers, { instance_1_name } )
    -- Update role for instance 2 and check again
    g.topology:set_instance_property(instance_2_name, { is_router = true })
    routers = g.topology:get_routers()
    t.assert_items_include(routers, { instance_1_name, instance_2_name } )
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    -- Create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instances
    local instance_1_name = gen_string()
    local instance_2_name = gen_string()
    g.topology:new_instance(instance_1_name, replicaset_name,
                            { is_storage = false })
    g.topology:new_instance(instance_2_name, replicaset_name,
                            { is_storage = true, is_router = true })
    -- Check a list of storages
    local storages = g.topology:get_storages()
    t.assert_not_equals(storages, nil)
    t.assert_items_include(storages, { instance_2_name } )
    -- Update role for instance 1 and check again
    g.topology:set_instance_property(instance_1_name, { is_storage = true })
    storages = g.topology:get_storages()
    t.assert_items_include(storages, { instance_1_name, instance_2_name } )
end

-- }}} get_storages

-- {{{ get_replicaset_options

g.test_get_replicaset_options = function()
    -- create replicaset
    local replicaset_name = gen_string()
    local opts = {
	-- options with integer value
	master_mode = constants.MASTER_MODE.SINGLE,
	-- option with boolean value
	failover_priority = true,
    }
    g.topology:new_replicaset(replicaset_name, opts)

    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.master_mode, opts.master_mode)
    t.assert_equals(replicaset_opts.failover_priority, opts.failover_priority)
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
	-- option with integer value
	replication_sync_timeout = 6,
	-- option with boolean value
        feedback_enabled = true,
	-- option with string value
        wal_mode = 'write',
    }
    local opts = { is_storage = true, is_master = false, box_cfg = box_cfg }
    g.topology:new_instance(instance_name, replicaset_name, opts)

    local cfg = g.topology:get_instance_conf(instance_name)
    t.assert_equals(cfg.replication_sync_timeout, box_cfg.replication_sync_timeout)
    t.assert_equals(cfg.feedback_enabled, box_cfg.feedback_enabled)
    t.assert_equals(cfg.wal_mode, box_cfg.wal_mode)
    t.assert_not_equals(cfg.instance_uuid, nil)
    t.assert_not_equals(cfg.replicaset_uuid, nil)
    t.assert_not_equals(cfg.replication, nil)
    t.assert_not_equals(cfg.read_only, false)
end

-- }}} get_instance_conf

-- {{{ get_topology_options

g.test_get_topology_options = function()
    local opts = {
	bucket_count = 154,
        discovery_mode = 'on',
        weights = true,
        shard_index = 'v',
    }
    g.topology:set_topology_property(opts)
    local cfg = g.topology:get_topology_options()
    t.assert_not_equals(cfg, nil)

    -- Create replicaset.
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)

    -- Get a current topology configuration.
    local cfg = g.topology:get_topology_options()
    t.assert_not_equals(cfg, nil)
    t.assert_items_include(cfg.replicasets, { replicaset_name })
    t.assert_equals(opts.bucket_count, cfg.bucket_count)
    t.assert_equals(opts.rebalancer_disbalance_threshold, cfg.rebalancer_disbalance_threshold)
    t.assert_equals(opts.discovery_mode, cfg.discovery_mode)
end

-- }}} get_topology_options

-- {{{ get_vshard_config

g.test_get_vshard_config = function()
    -- Create replicaset.
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)

    -- Create instances.
    local instance_1_name = gen_string()
    local instance_2_name = gen_string()

    local instance_1_opts = {
         box_cfg = {},
         advertise_uri = 'storage:storage@127.0.0.1:3301',
         listen_uri = '127.0.0.1:3301',
         is_master = true,
    }
    local instance_2_opts = {
         box_cfg = {},
         advertise_uri = 'storage:storage@127.0.0.1:3302',
         listen_uri = '127.0.0.1:3302',
         is_master = false,
    }
    g.topology:new_instance(instance_1_name, replicaset_name, instance_1_opts)
    g.topology:new_instance(instance_2_name, replicaset_name, instance_2_opts)

    local vshard_cfg = g.topology:get_vshard_config()
    t.assert_not_equals(vshard_cfg, nil)

    -- Check configuration of replicas in replicaset.
    local instance_1_cfg = g.topology:get_instance_conf(instance_1_name)
    local instance_2_cfg = g.topology:get_instance_conf(instance_2_name)
    -- Check that UUID of replicaset has a valid value.
    t.assert_not_equals(instance_1_cfg.replicaset_uuid, nil)
    t.assert_equals(instance_1_cfg.replicaset_uuid, instance_2_cfg.replicaset_uuid)
    local replicaset_uuid = instance_1_cfg.replicaset_uuid
    t.assert_not_equals(replicaset_uuid, nil)
    -- Get replicaset replicas and master's UUID.
    local replicaset_replicas = vshard_cfg.sharding[replicaset_uuid].replicas
    local replicaset_master_uuid = vshard_cfg.sharding[replicaset_uuid].master
    -- Check instances names.
    t.assert_equals(replicaset_replicas[instance_1_cfg.instance_uuid].name, instance_1_name)
    t.assert_equals(replicaset_replicas[instance_2_cfg.instance_uuid].name, instance_2_name)
    -- Check master name.
    t.assert_equals(replicaset_replicas[replicaset_master_uuid].name, instance_1_name)
    -- TODO: Check replication.
end

-- }}} get_vshard_config

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
