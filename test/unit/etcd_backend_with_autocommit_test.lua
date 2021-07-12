local fio = require('fio')
local log = require('log')
local t = require('luatest')
local helpers = require('test.helper')
local consts = require('topology.client.consts')
local conf_lib = require('conf')
local topology_lib = require('topology')

local g = t.group()

-- {{{ Setup / teardown

g.before_all(function()
    -- Show logs from the etcd transport.
    -- note: log.cfg() is not available on tarantool 1.10
    pcall(log.cfg, {level = 3})

    -- Setup etcd.
    local etcd_path = tostring(os.getenv("ETCD_PATH")) .. '/etcd'
    if not fio.path.exists(etcd_path) then
        etcd_path = '/usr/bin/etcd'
        t.skip_if(not fio.path.exists(etcd_path), 'etcd missing, set ETCD_PATH')
    end
    g.datadir = fio.tempdir()
    g.etcd_process = helpers.Etcd:new({
        workdir = fio.tempdir('/tmp'),
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = 'http://127.0.0.1:14001',
    })
    g.etcd_process:start()
end)

g.after_all(function()
    -- Teardown etcd.
    g.etcd_process:stop()
    fio.rmtree(g.etcd_process.workdir)
    fio.rmtree(g.datadir)
    g.etcd_process = nil
end)

g.before_each(function()
    -- Create a topology.
    local topology_name = helpers.gen_string()
    local urls = { g.etcd_process.client_url }
    local ok, conf_client = pcall(conf_lib.new, {driver = 'etcd', endpoints = urls})
    t.assert_equals(ok, true)
    t.assert_not_equals(conf_client, nil)
    local autocommit = true
    g.topology = topology_lib.new(conf_client, topology_name, autocommit)
    t.assert_not_equals(g.topology, nil)
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
    -- TODO: check new_instance() with non-exist vshard group
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    local box_cfg = {
        memtx_memory = 268435456,
    }
    local opts = {
	box_cfg = box_cfg,
	zone = 13,
	is_master = true,
	is_storage = false,
	is_router = false,
	replicaset = replicaset_name,
	vshard_groups = {'default'},
    }
    g.topology:new_instance(instance_name, opts)
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_not_equals(instance_opts.box_cfg.instance_uuid, nil)
    t.assert_equals(instance_opts.status, 'reachable')
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.replicas[1], instance_name)
end

-- }}} new_instance

-- {{{ new_replicaset

g.test_new_replicaset = function()
    -- TODO:
    -- 1. add replicasets with same names
    local replicaset_1_name = helpers.gen_string()
    local replicaset_2_name = helpers.gen_string()
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
    t.skip('not implemented')
    local instance_name = helpers.gen_string()
    local instances = { helpers.gen_string(), helpers.gen_string() }
    g.topology:new_instance_link(instance_name, instances)
end

-- }}} new_instance_link

-- {{{ delete_replicaset

g.test_delete_replicaset = function()
    -- TODO:
    -- 1. remove replicaset that contains instance(s)
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    local topology_opt = g.topology:get_topology_options()
    t.assert_items_include(topology_opt.replicasets, { replicaset_name })

    g.topology:delete_replicaset(replicaset_name)
    topology_opt = g.topology:get_topology_options()
    t.assert_equals(next(topology_opt.replicasets), nil)
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.replicas[1], instance_name)

    g.topology:delete_instance(instance_name)
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(#replicaset_opts.replicas, 0)
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'expelled')
end

-- }}} delete_instance

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
    local instance_name_1 = helpers.gen_string()
    local instance_name_2 = helpers.gen_string()
    local instance_name_3 = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    g.topology:new_instance(instance_name_1, {
        replicaset = replicaset_name,
    })
    g.topology:new_instance(instance_name_2, {
        replicaset = replicaset_name,
    })
    g.topology:new_instance(instance_name_3, {
        replicaset = replicaset_name,
    })
    g.topology:new_instance_link(instance_name_1, { instance_name_2, instance_name_3 })
    g.topology:delete_instance_link(instance_name_1, { instance_name_2, instance_name_3 })
    -- TODO: check replication in box.cfg['hot_standby']
    -- it must contain all specified links
    -- local cfg = g.get_instance_options(instance)
    -- t.assert_equals()
    t.skip('not implemented')
end

-- }}} delete_instance_link

-- {{{ set_instance_options

g.test_set_instance_options = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instance.
    local instance_name = helpers.gen_string()
    local box_cfg = {
	replication_sync_timeout = 6,
	election_mode = 'off',
        wal_mode = 'write',
    }
    local opts = {
        is_storage = true,
        is_master = false,
        box_cfg = box_cfg,
        replicaset = replicaset_name,
    }
    g.topology:new_instance(instance_name, opts)

    -- FIXME: special case - nested options should be merged too,
    -- not replaced by new table.
    local box_cfg = {
        replication_sync_timeout = 10,
    }
    local opts = {
        is_storage = false,
        is_master = true,
        box_cfg = box_cfg,
        replicaset = replicaset_name,
    }
    g.topology:set_instance_options(instance_name, opts)
    -- TODO: check new options
end

-- }}} set_instance_options

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    -- Status 'reachable' by default, set to 'unreachable'.
    g.topology:set_instance_unreachable(instance_name)
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'unreachable')
    -- Set status to 'reachable'.
    g.topology:set_instance_reachable(instance_name)
    instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'reachable')
end

-- }}} set_instance_reachable

-- {{{ set_instance_unreachable

g.test_set_instance_unreachable = function()
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    -- Status 'reachable' by default, set to 'unreachable'.
    g.topology:set_instance_unreachable(instance_name)
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'unreachable')
end

-- }}} set_instance_unreachable

-- {{{ set_replicaset_options

g.test_set_replicaset_options = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    local opts = {
        master_mode = consts.MASTER_MODE.AUTO
    }
    g.topology:new_replicaset(replicaset_name, opts)
    -- Create instance.
    local instance_name = helpers.gen_string()
    -- Check current master_mode.
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    local cfg = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(cfg.master_mode, consts.MASTER_MODE.AUTO)
    -- Set and check new master_mode.
    opts = {master_mode = consts.MASTER_MODE.SINGLE}
    g.topology:set_replicaset_options(replicaset_name, opts)
    local cfg = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(cfg.master_mode, consts.MASTER_MODE.SINGLE)
end

-- }}} set_replicaset_options


-- {{{ set_topology_options

g.test_set_topology_options = function()
    local zone_distances = {
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

    local vshard_groups = {
        ['superb'] = {
            bucket_count = 1000,
        }
    }
    local opts = {
        zone_distances = zone_distances,
        vshard_groups = vshard_groups,
    }
    g.topology:set_topology_options(opts)
    local topology_opts = g.topology:get_topology_options()
    t.assert_equals(topology_opts.zone_distances, opts.zone_distances)
    t.assert_not_equals(topology_opts.vshard_groups.default, nil)
    t.assert_not_equals(topology_opts.vshard_groups.superb, nil)
    local superb_vshard_group = topology_opts.vshard_groups['superb']
    t.assert_equals(superb_vshard_group.bucket_count, vshard_groups.superb.bucket_count)
end

-- }}} set_topology_options

-- {{{ get_routers

g.test_get_routers = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instances.
    local instance_1_name = helpers.gen_string()
    local instance_2_name = helpers.gen_string()
    g.topology:new_instance(instance_1_name, {
        is_router = true,
        replicaset = replicaset_name,
    })
    g.topology:new_instance(instance_2_name, {
       is_router = false,
       is_storage = true,
       replicaset = replicaset_name,
    })
    local routers = g.topology:get_routers()
    t.assert_not_equals(routers, nil)
    t.assert_items_include(routers, { instance_1_name } )
    -- Update role for instance 2 and check again
    g.topology:set_instance_options(instance_2_name, { is_router = true })
    routers = g.topology:get_routers()
    t.assert_items_include(routers, { instance_1_name, instance_2_name } )
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instances.
    local instance_1_name = helpers.gen_string()
    local instance_2_name = helpers.gen_string()
    g.topology:new_instance(instance_1_name, {
        is_storage = false,
        replicaset = replicaset_name,
    })
    g.topology:new_instance(instance_2_name, {
        is_storage = true,
        is_router = true,
        replicaset = replicaset_name,
    })
    -- Check a list of storages.
    local storages = g.topology:get_storages()
    t.assert_not_equals(storages, nil)
    t.assert_items_include(storages, { instance_2_name } )
    -- Update role for instance 1 and check again.
    g.topology:set_instance_options(instance_1_name, { is_storage = true })
    storages = g.topology:get_storages()
    t.assert_items_include(storages, { instance_1_name, instance_2_name } )
end

-- }}} get_storages

-- {{{ get_replicaset_options

g.test_get_replicaset_options = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    local opts = {
	master_mode = consts.MASTER_MODE.SINGLE,
	failover_priority = {},
    }
    g.topology:new_replicaset(replicaset_name, opts)

    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.master_mode, opts.master_mode)
    t.assert_equals(replicaset_opts.failover_priority, opts.failover_priority)
end

-- }}} get_replicaset_options

-- {{{ get_instance_options

g.test_get_instance_options = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instance.
    local instance_name = helpers.gen_string()
    local box_cfg = {
	-- Option with integer value.
	replication_sync_timeout = 6,
	-- Option with boolean value.
        feedback_enabled = true,
	-- Option with string value.
        wal_mode = 'write',
    }
    local opts = {
        is_storage = true,
	is_master = false,
	box_cfg = box_cfg,
	replicaset = replicaset_name,
    }
    g.topology:new_instance(instance_name, opts)

    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.box_cfg.replication_sync_timeout,
		    box_cfg.replication_sync_timeout)
    t.assert_equals(instance_opts.box_cfg.feedback_enabled,
		    box_cfg.feedback_enabled)
    t.assert_equals(instance_opts.box_cfg.wal_mode,
		    box_cfg.wal_mode)
    t.assert_not_equals(instance_opts.box_cfg.instance_uuid, nil)
    t.assert_not_equals(instance_opts.box_cfg.replicaset_uuid, nil)
    t.assert_not_equals(instance_opts.box_cfg.replication, nil)
    t.assert_not_equals(instance_opts.box_cfg.read_only, false)
end

-- }}} get_instance_options

-- {{{ get_topology_options

g.test_get_topology_options = function()
    local opts = {
	zone_distances = {},
    }
    g.topology:set_topology_options(opts)
    local topology_opts = g.topology:get_topology_options()
    t.assert_not_equals(topology_opts, nil)
    t.assert_not_equals(topology_opts.zone_distances, nil)
    local vshard_groups = topology_opts.vshard_groups
    t.assert_not_equals(vshard_groups, nil)
    t.assert_equals(vshard_groups.default.bucket_count, 3000)
    t.assert_equals(vshard_groups.default.rebalancer_max_receiving, 100)
    t.assert_equals(vshard_groups.default.rebalancer_max_sending, 1)
    t.assert_equals(vshard_groups.default.rebalancer_disbalance_threshold, 1)
    t.assert_equals(vshard_groups.default.sync_timeout, 1)
    t.assert_equals(vshard_groups.default.collect_lua_garbage, false)
    t.assert_equals(vshard_groups.default.discovery_mode, 'on')
    t.assert_equals(vshard_groups.default.shard_index, 'bucket_id')

    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)

    -- Get a current topology configuration.
    topology_opts = g.topology:get_topology_options()
    t.assert_not_equals(topology_opts, nil)
    t.assert_items_include(topology_opts.replicasets, { replicaset_name })
end

-- }}} get_topology_options

-- {{{ get_vshard_config_basic

g.test_get_vshard_config_basic = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)

    -- Create instances.
    local instance_1_name = helpers.gen_string()
    local instance_2_name = helpers.gen_string()

    local instance_1_opts = {
        box_cfg = {
            listen = '127.0.0.1:3301',
        },
        advertise_uri = 'storage:storage@127.0.0.1:3301',
        is_master = true,
        is_router = true,
        replicaset = replicaset_name,
    }
    local instance_2_opts = {
        box_cfg = {
            listen = '127.0.0.1:3302',
        },
        advertise_uri = 'storage:storage@127.0.0.1:3302',
        is_master = false,
        is_storage = true,
        replicaset = replicaset_name,
    }
    g.topology:new_instance(instance_1_name, instance_1_opts)
    g.topology:new_instance(instance_2_name, instance_2_opts)

    local vshard_cfg = g.topology:get_vshard_config()
    t.assert_not_equals(vshard_cfg, nil)

    -- Check configuration of replicas in replicaset.
    local instance_1_opts = g.topology:get_instance_options(instance_1_name)
    local instance_2_opts = g.topology:get_instance_options(instance_2_name)
    -- Check that UUID of replicaset has a valid value.
    t.assert_not_equals(instance_1_opts.box_cfg.replicaset_uuid, nil)
    t.assert_equals(instance_1_opts.box_cfg.replicaset_uuid,
                    instance_2_opts.box_cfg.replicaset_uuid)
    local replicaset_uuid = instance_1_opts.box_cfg.replicaset_uuid
    t.assert_not_equals(replicaset_uuid, nil)
    -- Get replicaset replicas and master's UUID.
    local replicaset_replicas = vshard_cfg.sharding[replicaset_uuid].replicas
    local replicaset_master_uuid = vshard_cfg.sharding[replicaset_uuid].master
    -- Check instances names.
    t.assert_equals(replicaset_replicas[instance_1_opts.box_cfg.instance_uuid].name,
                    instance_1_name)
    t.assert_equals(replicaset_replicas[instance_2_opts.box_cfg.instance_uuid].name,
                    instance_2_name)
    -- Check master name.
    t.assert_equals(replicaset_replicas[replicaset_master_uuid].name, instance_1_name)
    -- Check vshard default parameters.
    t.assert_equals(vshard_cfg.bucket_count, 3000)
    --t.assert_equals(vshard_cfg.collect_bucket_garbage_interval, 0.5)
    t.assert_equals(vshard_cfg.collect_lua_garbage, false)
    t.assert_equals(vshard_cfg.discovery_mode, 'on')
    t.assert_equals(vshard_cfg.rebalancer_disbalance_threshold, 1)
    t.assert_equals(vshard_cfg.rebalancer_max_receiving, 100)
    t.assert_equals(vshard_cfg.rebalancer_max_sending, 1)
    t.assert_equals(vshard_cfg.shard_index, 'bucket_id')
    t.assert_equals(vshard_cfg.sync_timeout, 1)
    -- TODO: Check replication.
end

-- }}} get_vshard_config_basic

-- {{{ get_vshard_config_empty_replicaset

g.test_get_vshard_config_empty_replicaset = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    local vshard_cfg = g.topology:get_vshard_config()
    t.assert_equals(vshard_cfg, nil)
end

-- }}} get_vshard_config_empty_replicaset

-- {{{ commit

g.test_commit = function()
    t.skip('not implemented')
end

-- }}} commit

-- {{{ on_change

g.test_on_change = function()
    t.skip('not implemented')
    local fiber = require('fiber')
    g.ch = fiber.channel(10)

    -- Set a callback on topology changes
    fiber.create(g.topology.on_change, function() print('') end)

    -- Make two changes in topology
    g.topology:new_replicaset(helpers.gen_string())
    g.topology:new_replicaset(helpers.gen_string())

    -- Make sure we have two messages in a channel
    t.assert_equals(g.ch:count(), 2)
end

-- }}} on_change

-- {{{ delete

g.test_delete = function()
    -- Create a topology.
    local topology_name = helpers.gen_string()
    local urls = { g.etcd_process.client_url }
    local ok, conf_client = pcall(conf_lib.new, {driver = 'etcd', endpoints = urls})
    t.assert_equals(ok, true)
    t.assert_not_equals(conf_client, nil)
    local topology_conf = topology_lib.new(conf_client, topology_name, true)
    t.assert_not_equals(topology_conf, nil)

    -- Remove the topology.
    topology_conf:delete()

    -- Make sure topology has been removed.
    local data = conf_client:get(topology_name)
    data = data.data
    t.assert_equals(data, nil)
end

-- }}} delete

-- {{{ get_instances_it

g.test_get_instances_it = function()
    -- Create instances.
    local instance_1_name = helpers.gen_string()
    local instance_2_name = helpers.gen_string()
    local instance_3_name = helpers.gen_string()
    g.topology:new_instance(instance_1_name, {
        is_router = true,
    })
    g.topology:new_instance(instance_2_name, {
        is_router = true,
    })
    g.topology:new_instance(instance_3_name, {
        is_router = true,
    })

    t.assert_equals(g.topology:get_instances_it():is_null(), false)
    t.assert_equals(g.topology:get_instances_it():length(), 3)
    local predicate = function(_, opts)
        return type(opts) == 'table' and opts.is_router == true
    end
    t.assert_not_equals(g.topology:get_instances_it():all(predicate))
    t.assert_items_include(g.topology:get_instances_it():totable(), {
        instance_1_name,
        instance_2_name,
        instance_3_name,
    })
    local instances = g.topology:get_instances_it():tomap()
    t.assert_not_equals(instances, nil)
    t.assert_equals(instances[instance_1_name].is_router, true)
    t.assert_not_equals(instances[instance_1_name], nil)
    t.assert_not_equals(instances[instance_2_name], nil)
    t.assert_not_equals(instances[instance_3_name], nil)
end

-- }}} get_instances_it

-- {{{ get_replicasets_it

g.test_get_replicasets_it = function()
    -- Create instances.
    local replicaset_1_name = helpers.gen_string()
    local replicaset_2_name = helpers.gen_string()
    local replicaset_3_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_1_name)
    g.topology:new_replicaset(replicaset_2_name)
    g.topology:new_replicaset(replicaset_3_name)

    t.assert_equals(g.topology:get_replicasets_it():length(), 3)
    t.assert_equals(g.topology:get_replicasets_it():is_null(), false)
    local predicate = function(_, opts)
        return type(opts) == 'table' and opts.cluster_uuid ~= nil
    end
    t.assert_not_equals(g.topology:get_replicasets_it():all(predicate))
    local replicasets = g.topology:get_replicasets_it():tomap()
    t.assert_not_equals(replicasets, nil)
    t.assert_not_equals(replicasets[replicaset_1_name], nil)
    t.assert_not_equals(replicasets[replicaset_2_name], nil)
    t.assert_not_equals(replicasets[replicaset_3_name], nil)
    t.assert_items_include(g.topology:get_replicasets_it():totable(), {
        replicaset_1_name,
        replicaset_2_name,
        replicaset_3_name,
    })
end

-- }}} get_replicasets_it
