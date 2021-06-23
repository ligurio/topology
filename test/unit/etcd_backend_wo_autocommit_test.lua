local consts = require('topology.client.consts')
local conf_lib = require('conf')
local fio = require('fio')
local log = require('log')
local t = require('luatest')
local topology_lib = require('topology')
local helpers = require('test.helper')

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
    local ok, conf_client = pcall(conf_lib.new, {
        driver = 'etcd',
	endpoints = urls,
    })
    t.assert_not_equals(ok, false)
    t.assert_not_equals(conf_client, nil)
    local autocommit = false
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
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    local instance_opts = g.topology:get_instance_options(instance_name)
    -- No changes in configuration storage without commit.
    t.assert_equals(instance_opts, nil)
    -- Commit changes.
    g.topology:commit()
    instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_not_equals(instance_opts.box_cfg.instance_uuid, nil)
end

-- }}} new_instance

-- {{{ new_replicaset

g.test_new_replicaset = function()
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    -- No changes expected in configuration storage without commit.
    t.assert_equals(replicaset_opts, nil)
    -- Commit changes.
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
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    g.topology:commit()
    local topology_opt = g.topology:get_topology_options()
    t.assert_items_include(topology_opt.replicasets, { replicaset_name })
    local replicaset_opt = g.topology:get_replicaset_options(replicaset_name)
    t.assert_not_equals(replicaset_opt, nil)

    -- No changes expected in configuration storage without commit.
    g.topology:delete_replicaset(replicaset_name)
    topology_opt = g.topology:get_topology_options()
    t.assert_items_include(topology_opt.replicasets, { })
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_not_equals(replicaset_opts, nil)

    -- Commit changes.
    g.topology:commit()
    topology_opt = g.topology:get_topology_options()
    t.assert_equals(next(topology_opt.replicasets), nil)
    replicaset_opt = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opt, nil)
end

-- }}} delete_replicaset

-- {{{ delete_instance

g.test_delete_instance = function()
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    g.topology:commit()
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_items_include(replicaset_opts.replicas, { instance_name })
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_not_equals(instance_opts, nil)

    -- No changes expected in configuration storage without commit.
    g.topology:delete_instance(instance_name)
    instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'reachable')

    -- Commit changes.
    g.topology:commit()
    instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'expelled')
end

-- }}} delete_instance

-- {{{ delete_instance_link

g.test_delete_instance_link = function()
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
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    g.topology:commit()

    -- Make sure instance has been added.
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_not_equals(instance_opts, nil)
    t.assert_equals(instance_opts.box_cfg.readahead, nil)

    local opts = {
        box_cfg = {
            readahead = 232333232,
        },
    }
    -- No changes in configuration storage wo commit.
    g.topology:set_instance_options(instance_name, opts)
    instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.box_cfg.readahead, nil)

    -- Commit changes.
    g.topology:commit()
    instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.box_cfg.readahead, 232333232)
end

-- }}} set_instance_options

-- {{{ set_instance_reachable

g.test_set_instance_reachable = function()
    local instance_name = helpers.gen_string()
    local replicaset_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    g.topology:set_instance_reachable(instance_name)
    g.topology:commit()
    local instance_opts = g.topology:get_instance_options(instance_name)
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
    g.topology:set_instance_unreachable(instance_name)
    g.topology:commit()
    local instance_opts = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_opts.status, 'unreachable')
end

-- }}} set_instance_unreachable

-- {{{ set_replicaset_options

g.test_set_replicaset_options = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instance.
    local instance_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        replicaset = replicaset_name,
    })
    g.topology:commit()
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_items_include(replicaset_opts.replicas, { instance_name })
    t.assert_equals(replicaset_opts.master_mode, nil)
    local opts = {
        master_mode = consts.MASTER_MODE.AUTO,
    }
    -- No changes in configuration storage without commit.
    g.topology:set_replicaset_options(replicaset_name, opts)
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.master_mode, nil)

    -- Commit changes.
    g.topology:commit()
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.master_mode, consts.MASTER_MODE.AUTO)
end

-- }}} set_replicaset_options


-- {{{ set_topology_options

g.test_set_topology_options = function()
    local topology_opts = g.topology:get_topology_options()
    t.assert_equals(topology_opts, nil)

    local opts = {
        vshard_groups = {
	    ['superb'] = {
	        bucket_count = 1000,
	    },
        },
    }
    -- No changes in configuration storage without commit.
    g.topology:set_topology_options(opts)
    topology_opts = g.topology:get_topology_options()
    t.assert_equals(topology_opts, nil)

    -- Commit changes.
    g.topology:commit()
    topology_opts = g.topology:get_topology_options()
    t.assert_not_equals(next(topology_opts), nil)
    t.assert_equals(topology_opts.vshard_groups.superb.bucket_count, 1000)
end

-- }}} set_topology_options

-- {{{ get_routers

g.test_get_routers = function()
    -- No routers are expected.
    local routers = g.topology:get_routers()
    t.assert_equals(routers, nil)

    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instance.
    local instance_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        is_router = true,
        replicaset = replicaset_name,
    })
    -- Still no routers are expected.
    routers = g.topology:get_routers()
    t.assert_equals(routers, nil)

    -- Commit changes and make sure we have one router.
    g.topology:commit()
    routers = g.topology:get_routers()
    t.assert_items_include(routers, { instance_name })
end

-- }}} get_routers

-- {{{ get_storages

g.test_get_storages = function()
    -- No storages are expected.
    local storages = g.topology:get_storages()
    t.assert_equals(storages, nil)

    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instance.
    local instance_name = helpers.gen_string()
    g.topology:new_instance(instance_name, {
        is_storage = true,
	replicaset = replicaset_name,
    })
    -- Still no storages are expected.
    storages = g.topology:get_storages()
    t.assert_equals(storages, nil)

    -- Commit changes and make sure we have one storage.
    g.topology:commit()
    storages = g.topology:get_storages()
    t.assert_items_include(storages, { instance_name })
end

-- }}} get_storages

-- {{{ get_replicaset_options

g.test_get_replicaset_options = function()
    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    local instance_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    g.topology:new_instance(instance_name, {
	replicaset = replicaset_name,
    })
    g.topology:commit()
    local replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    -- Replicaset is in configuration storage and failover_priority is not set.
    t.assert_not_equals(replicaset_opts, nil)
    t.assert_equals(next(replicaset_opts.failover_priority), nil)

    -- Failover_priority is not set without commit.
    local opts = {
	failover_priority = {
	    instance_name,
	}
    }
    g.topology:set_replicaset_options(replicaset_name, opts)
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(next(replicaset_opts.failover_priority), nil)

    -- Commit changes and failover_priority is set to true as expected.
    g.topology:commit()
    replicaset_opts = g.topology:get_replicaset_options(replicaset_name)
    t.assert_equals(replicaset_opts.failover_priority, {instance_name})
end

-- }}} get_replicaset_options

-- {{{ get_instance_options

g.test_get_instance_options = function()
    local replicaset_name = helpers.gen_string()
    local instance_name = helpers.gen_string()

    local instance_cfg = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_cfg, nil)

    -- Create replicaset.
    g.topology:new_replicaset(replicaset_name)
    -- Create instance.
    g.topology:new_instance(instance_name, {
	replicaset = replicaset_name,
    })
    -- No changes in configuration storage.
    instance_cfg = g.topology:get_instance_options(instance_name)
    t.assert_equals(instance_cfg, nil)

    -- Commit changes and make sure changes are there.
    g.topology:commit()
    instance_cfg = g.topology:get_instance_options(instance_name)
    t.assert_not_equals(instance_cfg, nil)
end

-- }}} get_instance_options

-- {{{ get_topology_options

g.test_get_topology_options = function()
    -- No topology options without enable autocommit option.
    local topology_opts = g.topology:get_topology_options()
    t.assert_equals(topology_opts, nil)
    -- Commit and topology becomes available in configuration storage.
    g.topology:commit()
    local topology_opts = g.topology:get_topology_options()
    t.assert_not_equals(next(topology_opts), nil)
end

-- }}} get_topology_options

-- {{{ get_vshard_config

g.test_get_vshard_config = function()
    local vshard_cfg = g.topology:get_vshard_config()
    t.assert_equals(vshard_cfg, nil)

    -- Create replicaset.
    local replicaset_name = helpers.gen_string()
    g.topology:new_replicaset(replicaset_name)
    -- Create instances.
    local instance_1_name = helpers.gen_string()
    local instance_2_name = helpers.gen_string()
    g.topology:new_instance(instance_1_name, {
        replicaset = replicaset_name,
        advertise_uri = 'storage:storage@127.0.0.1:3301',
    })
    g.topology:new_instance(instance_2_name, {
        advertise_uri = 'storage:storage@127.0.0.1:3302',
        replicaset = replicaset_name,
    })
    -- Commit changes to configuration storage.
    g.topology:commit()
    local vshard_cfg = g.topology:get_vshard_config()
    t.assert_not_equals(vshard_cfg.sharding, nil)
end

-- }}} get_vshard_config

-- {{{ delete

g.test_delete = function()
    -- Create a topology.
    local topology_name = helpers.gen_string()
    local urls = { g.etcd_process.client_url }
    local ok, conf_client = pcall(conf_lib.new, {driver = 'etcd', endpoints = urls})
    t.assert_equals(ok, true)
    t.assert_not_equals(conf_client, nil)
    local topology_conf = topology_lib.new(conf_client, topology_name, false)
    t.assert_not_equals(topology_conf, nil)

    -- Remove the topology.
    topology_conf:delete()
    --topology_conf:commit()

    -- Make sure topology has been removed.
    local data = conf_client:get(topology_name)
    data = data.data
    t.assert_equals(data, nil)
end

-- }}} delete
