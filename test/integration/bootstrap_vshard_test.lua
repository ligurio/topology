local fio = require('fio')
local log = require('log')
local t = require('luatest')
local Process = require('luatest.process')
local Server = t.Server
local helpers = require('test.helper')
local conf_lib = require('conf')
local topology_lib = require('topology')

local g = t.group()

local ETCD_ENDPOINT = 'http://127.0.0.1:2379'
local topology_name = 'vshard_integration_test'

local function split(s, delimiter)
    local result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end

    return result;
end

-- {{{ Setup / teardown

g.before_all(function()
    -- Show logs from the etcd transport.
    -- note: log.cfg() is not available on tarantool 1.10
    pcall(log.cfg, {level = 4})
    g.datadir = fio.tempdir('/tmp')

    -- Setup etcd.
    local etcd_path = tostring(os.getenv("ETCD_PATH")) .. '/etcd'
    if not fio.path.exists(etcd_path) then
        etcd_path = '/usr/bin/etcd'
        t.skip_if(not fio.path.exists(etcd_path), 'etcd missing, set ETCD_PATH')
    end
    g.etcd_process = helpers.Etcd:new({
        workdir = fio.pathjoin(g.datadir, fio.tempdir('/tmp')),
        etcd_path = etcd_path,
        peer_url = 'http://127.0.0.1:17001',
        client_url = ETCD_ENDPOINT,
    })
    g.etcd_process:start()

    -- Create topology in configuration storage
    local topology_conf = require('test.integration.topology_vshard')
    topology_conf.create(topology_name, {ETCD_ENDPOINT}, g.datadir)

    -- Get instance configuration from Tarantool topology
    local conf_client = conf_lib.new({
        driver = 'etcd',
        endpoints = {
            ETCD_ENDPOINT
        },
    })
    assert(conf_client ~= nil)
    local conf = topology_lib.new(conf_client, topology_name)
    assert(conf ~= nil)

    g.processes = {}
    -- luacheck: ignore
    local root = fio.dirname(fio.dirname(fio.abspath(package.search('test.helper'))))
    local storages = conf:get_storages()
    t.assert_not_equals(storages, nil)
    for instance_name, instance_opts in pairs(storages) do
        local port = split(instance_opts.box_cfg.listen, ':')[2]
        local entrypoint = fio.pathjoin(root, 'test', 'entrypoint', instance_name .. '.lua')
        assert(fio.path.exists(entrypoint), true)
        local proc = Server:new({
            command = entrypoint,
            workdir = instance_opts.box_cfg.work_dir, -- TARANTOOL_WORKDIR
            env = {
                TARANTOOL_CONF_STORAGE_URL = ETCD_ENDPOINT,
                TARANTOOL_TOPOLOGY_NAME = topology_name,
                TARANTOOL_STORAGE_ROLE = 1,
            },
            alias = instance_name,
            net_box_port = tonumber(port),
        })
        g.processes[instance_name] = proc
    end

    local routers = conf:get_routers()
    t.assert_not_equals(routers, nil)
    for instance_name, instance_opts in pairs(routers) do
        local port = split(instance_opts.box_cfg.listen, ':')[2]
        local entrypoint = fio.pathjoin(root, 'test', 'entrypoint', instance_name .. '.lua')
        assert(fio.path.exists(entrypoint), true)
        local proc = Server:new({
            command = entrypoint,
            workdir = instance_opts.box_cfg.work_dir, -- TARANTOOL_WORKDIR
            env = {
                TARANTOOL_CONF_STORAGE_URL = ETCD_ENDPOINT,
                TARANTOOL_TOPOLOGY_NAME = topology_name,
                TARANTOOL_ROUTER_ROLE = 1,
            },
            alias = instance_name,
            net_box_port = tonumber(port),
        })
        g.processes[instance_name] = proc
    end

    -- Run Tarantools
    for _, proc in pairs(g.processes) do
        fio.mktree(proc.workdir)
        proc:start()
    end
    t.helpers.retrying({timeout = 15}, function()
	t.assert(Process.is_pid_alive(g.processes.router.process.pid))
	g.processes.router:connect_net_box()
	t.assert(Process.is_pid_alive(g.processes.storage_1_a.process.pid))
	g.processes.storage_1_a:connect_net_box()
	t.assert(Process.is_pid_alive(g.processes.storage_1_b.process.pid))
	g.processes.storage_1_b:connect_net_box()
	t.assert(Process.is_pid_alive(g.processes.storage_1_c.process.pid))
	g.processes.storage_1_c:connect_net_box()
    end)

    -- FIXME: bootstrap router once storages bootstrapped.
    -- Otherwise router failed to discover buckets ob storages.

    t.helpers.retrying({timeout = 15}, function()
	g.processes.router:connect_net_box()
        local router_info = g.processes.router.net_box:eval('return vshard.router.info()')
        t.assert_items_equals(router_info.alerts, {})
        t.assert_equals(router_info.bucket.available_rw, 10000)
        g.processes.router.net_box:close()
    end)
end)

g.after_all(function()
    -- Teardown etcd.
    if g.etcd_process.process then
        g.etcd_process:stop()
    end

    -- Teardown Tarantools.
    for _, proc in pairs(g.processes) do
        if proc.process then
            proc:stop()
        end
    end

    -- Cleanup.
    fio.rmtree(g.datadir)
end)

-- }}} Setup / teardown

-- {{{ simple_storage_check

g.test_simple_storage_check = function()
    local storage_obj = g.processes.storage_1_a
    storage_obj:connect_net_box()
    local buckets_count = storage_obj.net_box:eval('return vshard.storage.buckets_count()')
    t.assert_not_equals(tonumber(buckets_count), 0)
    storage_obj.net_box:close()
end

-- }}} simple_storage_check

-- {{{ simple_router_check

g.test_simple_router_check = function()
    local router_obj = g.processes.router
    router_obj:connect_net_box()
    local router_info = router_obj.net_box:eval('return vshard.router.info()')
    t.assert_equals(router_info.bucket.available_rw, 10000)
    router_obj.net_box:close()
end

-- }}} simple_router_check
