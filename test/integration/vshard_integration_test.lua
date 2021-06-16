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
local topology_name = 'vshard'

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
    pcall(log.cfg, {level = 6})
    g.datadir = fio.tempdir('/tmp')

    -- Setup etcd.
    local etcd_path = tostring(os.getenv("ETCD_PATH")) .. '/etcd'
    if not fio.path.exists(etcd_path) then
        etcd_path = '/usr/bin/etcd'
        t.skip_if(not fio.path.exists(etcd_path), 'etcd missing')
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
    local conf_client = conf_lib.new({driver = 'etcd', endpoints = { ETCD_ENDPOINT }})
    assert(conf_client ~= nil)
    local conf = topology_lib.new(conf_client, topology_name)
    assert(conf ~= nil)

    g.processes = {}
    -- luacheck: ignore
    local root = fio.dirname(fio.dirname(fio.abspath(package.search('test.helper'))))
    local storages = conf:get_storages()
    assert(storages ~= nil)
    for _, instance_name in pairs(storages) do
        local instance_opts = conf:get_instance_options(instance_name)
        local port = split(instance_opts.box_cfg.listen, ':')[2]
        local entrypoint = fio.pathjoin(root, 'test', 'entrypoint', instance_name .. '.lua')
        assert(fio.path.exists(entrypoint), true)
        local proc = Server:new({
            command = entrypoint,
            -- passed as TARANTOOL_WORKDIR
            workdir = instance_opts.box_cfg.work_dir,
            --chdir = instance_opts.box_cfg.work_dir,
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
    assert(routers ~= nil)
    for _, instance_name in pairs(routers) do
        local instance_opts = conf:get_instance_options(instance_name)
        local port = split(instance_opts.box_cfg.listen, ':')[2]
        local entrypoint = fio.pathjoin(root, 'test', 'entrypoint', instance_name .. '.lua')
        assert(fio.path.exists(entrypoint), true)
        local proc = Server:new({
            command = entrypoint,
            -- passed as TARANTOOL_WORKDIR
            workdir = instance_opts.box_cfg.work_dir,
            --chdir = instance_opts.box_cfg.work_dir,
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

    t.skip('fixture failed to setup cluster, to be fixed')
    -- Run Tarantools
    for _, proc in pairs(g.processes) do
        fio.mktree(proc.workdir)
        assert(fio.path.exists(proc.workdir), true)
        proc:start()
    end
    t.helpers.retrying({timeout = 30}, function()
        for _, proc in pairs(g.processes) do
            t.assert(Process.is_pid_alive(proc.process.pid), proc.alias)
            proc:connect_net_box()
        end
    end)
    -- Wait a master.
    --[[
    local replicaset = {
        storage_1_a = storage_1_a,
        storage_1_b = storage_1_b,
        storage_2_a = storage_1_a,
        storage_2_b = storage_1_b,
    }
    t.helpers.wait_master(replicaset, 'storage_1_a')
    ]]
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

-- {{{ setup_cluster

g.test_setup_cluster = function()
    assert(false)
    --[[
    storage_1_a:connect_net_box()
    t.assert_equals(storage_1_a.net_box:eval('return os.getenv("TARANTOOL_LISTEN")'), '3301')
    local router_info = storage_1_a.net_box:eval('return vshard.router.info")')
    t.assert_not_equals(router_info, {})
    -- FIXME: add testcases https://github.com/tarantool/vshard
    storage_1_a.net_box:close()
    t.assert_equals(storage_1_a.net_box.state, 'closed')
    ]]

	--[[
    unix/:./data/router_1.control> vshard.router.info()
    ---
    - replicasets:
      - master:
	  state: active
	  uri: storage:storage@127.0.0.1:3301
	  uuid: 2ec29309-17b6-43df-ab07-b528e1243a79
      - master:
	  state: active
	  uri: storage:storage@127.0.0.1:3303
	  uuid: 810d85ef-4ce4-4066-9896-3c352fec9e64
    ...

unix/:./data/router_1.control> vshard.router.info()
---
- replicasets:
    ac522f65-aa94-4134-9f64-51ee384f1a54:
      replica: &0
        network_timeout: 0.5
        status: available
        uri: storage@127.0.0.1:3303
        uuid: 1e02ae8a-afc0-4e91-ba34-843a356b8ed7
      uuid: ac522f65-aa94-4134-9f64-51ee384f1a54
      master: *0
    cbf06940-0790-498b-948d-042b62cf3d29:
      replica: &1
        network_timeout: 0.5
        status: available
        uri: storage@127.0.0.1:3301
        uuid: 8a274925-a26d-47fc-9e1b-af88ce939412
      uuid: cbf06940-0790-498b-948d-042b62cf3d29
      master: *1
  bucket:
    unreachable: 0
    available_ro: 0
    unknown: 0
    available_rw: 3000
  status: 0
  alerts: []
...
	]]
end

-- }}} setup_cluster
