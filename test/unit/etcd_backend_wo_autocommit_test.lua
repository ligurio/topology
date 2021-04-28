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
    local autocommit = false
    g.topology = topology.new(g.conf_client, topology_name, autocommit)
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
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    local instance_cfg = g.topology:get_instance_conf(instance_name)
    -- no changes in configuration storage without commit
    t.assert_equals(instance_cfg, nil)
    -- commit changes
    g.topology:commit()
    instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_not_equals(instance_cfg.instance_uuid, nil)
end

-- }}} new_instance

-- {{{ new_replicaset

g.test_new_replicaset = function()
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    -- no changes expected in configuration storage without commit
    t.assert_equals(replicaset_opts, nil)
    -- commit changes
    g.topology:commit()
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_not_equals(replicaset_opts, nil)
end

-- }}} new_replicaset

-- {{{ new_instance_link

g.test_new_instance_link = function()
    t.skip('not implemented')
end

-- }}} new_instance_link

-- {{{ delete_replicaset

g.test_delete_replicaset = function()
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    g.topology:commit()
    local topology_opt = g.topology:get_topology_options()
    t.assert_items_include(topology_opt.replicasets, { replicaset_name })
    local replicaset_opt = g.topology:get_replicaset_options(replicaset_name)
    t.assert_not_equals(replicaset_opt, nil)

    -- no changes expected in configuration storage without commit
    g.topology:delete_replicaset(replicaset_name)
    topology_opt = g.topology:get_topology_options()
    t.assert_items_include(topology_opt.replicasets, { replicaset_name })
    replicaset_opt = g.topology:get_replicaset_options(replicaset_name)
    t.assert_not_equals(replicaset_opt, nil)

    -- commit changes
    g.topology:commit()
    topology_opt = g.topology:get_topology_options()
    t.assert_equals(next(topology_opt.replicasets), nil)
    replicaset_opt = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opt, nil)
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local instance_name = gen_string()
    local replicaset_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name)
    g.topology:commit()
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_items_include(replicaset_opts.replicas, { instance_name })
    local instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_not_equals(instance_cfg, nil)

    -- no changes expected in configuration storage without commit
    g.topology:delete_instance(instance_name)
    instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_not_equals(instance_cfg, nil)

    -- commit changes
    g.topology:commit()
    instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_equals(instance_cfg, nil)
end

-- }}} delete_instance

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
    t.skip('not implemented')
end

-- }}} delete_instance_link

-- }}} delete_instance

-- {{{ set_instance_options

g.test_set_instance_options = function()
    --[[
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
    local opts = { is_storage = false, is_master = true, box_cfg = box_cfg }
    g.topology:set_instance_options(instance_name, opts)
    ]]
end

-- }}} set_instance_options

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    t.skip('not implemented')
end

-- }}} set_instance_reachable

-- {{{ set_instance_unreachable

g.test_set_instance_unreachable = function()
    t.skip('not implemented')
end

-- }}} set_instance_unreachable

-- {{{ set_replicaset_options

g.test_set_replicaset_options = function()
    --[[
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
    g.topology:set_replicaset_options(replicaset_name, opts)
    local cfg = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(cfg.master_mode, constants.MASTER_MODE.SINGLE)
    ]]
end

-- }}} set_replicaset_options


-- {{{ set_topology_options

g.test_set_topology_options = function()
    --[[
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
    g.topology:set_topology_options(opts)
    local cfg = g.topology:get_topology_options()
    t.assert_equals(cfg.discovery_mode, opts.discovery_mode)
    ]]
end

-- }}} set_topology_options

-- {{{ get_routers

g.test_get_routers = function()
    -- no routers are expected
    local routers = g.topology:get_routers()
    t.assert_equals(next(routers), nil)

    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    local instance_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name,
                            { is_router = true })
    -- still no routers are expected
    routers = g.topology:get_routers()
    t.assert_equals(next(routers), nil)

    -- commit changes and make sure we have one router
    g.topology:commit()
    routers = g.topology:get_routers()
    t.assert_items_include(routers, { instance_name })
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    -- no storages are expected
    local storages = g.topology:get_storages()
    t.assert_equals(next(storages), nil)

    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    local instance_name = gen_string()
    g.topology:new_instance(instance_name, replicaset_name,
                            { is_storage = true })
    -- still no storages are expected
    storages = g.topology:get_storages()
    t.assert_equals(next(storages), nil)

    -- commit changes and make sure we have one storage
    g.topology:commit()
    storages = g.topology:get_storages()
    t.assert_items_include(storages, { instance_name })
end

-- }}} get_storages

-- {{{ get_replicaset_options

g.test_get_replicaset_options = function()
    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    g.topology:commit()
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    -- replicaset is in configuration storage and failover_priority is not set
    t.assert_not_equals(replicaset_opts, nil)
    t.assert_equals(replicaset_opts.failover_priority, nil)

    -- failover_priority is not set without commit
    local opts = { failover_priority = true }
    g.topology:set_replicaset_options(replicaset_name, opts)
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.failover_priority, nil)

    -- commit changes and failover_priority is set to true as expected
    g.topology:commit()
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.failover_priority, true)
end

-- }}} get_replicaset_options

-- {{{ get_instance_conf

g.test_get_instance_conf = function()
    local replicaset_name = gen_string()
    local instance_name = gen_string()

    local instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_equals(instance_cfg, nil)

    -- create replicaset
    g.topology:new_replicaset(replicaset_name)
    -- create instance
    g.topology:new_instance(instance_name, replicaset_name)
    -- no changes in configuration storage
    instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_equals(instance_cfg, nil)

    -- commit changes and make sure changes are there
    g.topology:commit()
    instance_cfg = g.topology:get_instance_conf(instance_name)
    t.assert_not_equals(instance_cfg, nil)
end

-- }}} get_instance_conf

-- {{{ get_topology_options

g.test_get_topology_options = function()
    --[[
    local opts = {
	bucket_count = 154,
        discovery_mode = 'on',
        weights = true,
        shard_index = 'v',
    }
    g.topology:set_topology_options(opts)
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
    ]]
end

-- }}} get_topology_options

-- {{{ get_vshard_config

g.test_get_vshard_config = function()
    local vshard_cfg = g.topology:get_vshard_config()
    t.assert_equals(next(vshard_cfg), nil)

    -- create replicaset
    local replicaset_name = gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- create instances
    local instance_1_name = gen_string()
    local instance_2_name = gen_string()
    g.topology:new_instance(instance_1_name, replicaset_name)
    g.topology:new_instance(instance_2_name, replicaset_name)

    -- no changes in configuration storage
    vshard_cfg = g.topology:get_vshard_config()
    t.assert_equals(next(vshard_cfg), nil)

    -- commit changes to configuration storage
    g.topology:commit()
    vshard_cfg = g.topology:get_vshard_config()
    t.assert_not_equals(vshard_cfg.sharding, nil)

end

-- }}} get_vshard_config
