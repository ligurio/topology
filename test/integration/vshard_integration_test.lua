local fio = require('fio')
local log = require('log')
local t = require('luatest')
local Process = require('luatest.process')
local Server = t.Server
local helpers = require('test.helper')

local g = t.group()

local ETCD_ENDPOINT = 'http://127.0.0.1:2379'
local topology_name = 'vshard'

-- luacheck: ignore
local root = fio.dirname(fio.dirname(fio.abspath(package.search('test.helper'))))
g.datadir = fio.tempdir('/tmp')
local storage_1_a = Server:new({
    command = fio.pathjoin(root, 'test', 'entrypoint', 'storage_1_a.lua'),
    workdir = fio.pathjoin(g.datadir, 'storage_1_a_workdir'),
    env = {
	TARANTOOL_CONF_STORAGE_URL = ETCD_ENDPOINT,
	TARANTOOL_TOPOLOGY_NAME = topology_name,
	TARANTOOL_ROUTER_ROLE = 1,
    },
    alias = 'storage_1_a',
    net_box_port = 3301,
})

local storage_1_b = Server:new({
    command = fio.pathjoin(root, 'test', 'entrypoint', 'storage_1_b.lua'),
    workdir = fio.pathjoin(g.datadir, 'storage_1_b_workdir'),
    env = {
	TARANTOOL_CONF_STORAGE_URL = ETCD_ENDPOINT,
	TARANTOOL_TOPOLOGY_NAME = topology_name,
	TARANTOOL_STORAGE_ROLE = 1,
    },
    alias = 'storage_1_b',
    net_box_port = 3302,
})

local storage_2_a = Server:new({
    command = fio.pathjoin(root, 'test', 'entrypoint', 'storage_2_a.lua'),
    workdir = fio.pathjoin(g.datadir, 'storage_2_a_workdir'),
    env = {
	TARANTOOL_CONF_STORAGE_URL = ETCD_ENDPOINT,
	TARANTOOL_TOPOLOGY_NAME = topology_name,
	TARANTOOL_STORAGE_ROLE = 1,
    },
    alias = 'storage_2_a',
    net_box_port = 3303,
})

local storage_2_b = Server:new({
    command = fio.pathjoin(root, 'test', 'entrypoint', 'storage_2_b.lua'),
    workdir = fio.pathjoin(g.datadir, 'storage_2_b_workdir'),
    env = {
	TARANTOOL_CONF_STORAGE_URL = ETCD_ENDPOINT,
	TARANTOOL_TOPOLOGY_NAME = topology_name,
	TARANTOOL_STORAGE_ROLE = 1,
    },
    alias = 'storage_2_b',
    net_box_port = 3304,
})

-- {{{ Setup / teardown

g.before_all(function()
    -- Show logs from the etcd transport.
    -- note: log.cfg() is not available on tarantool 1.10
    pcall(log.cfg, {level = 6})

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
    topology_conf.create(topology_name, {ETCD_ENDPOINT})

    -- Run Tarantools
    fio.mktree(storage_1_a.workdir)
    storage_1_a:start()
    fio.mktree(storage_1_b.workdir)
    storage_1_b:start()
    fio.mktree(storage_2_a.workdir)
    storage_2_a:start()
    fio.mktree(storage_2_b.workdir)
    storage_2_b:start()
    t.helpers.retrying({timeout = 20}, function()
	t.assert(Process.is_pid_alive(storage_1_a.process.pid))
	storage_1_a:connect_net_box()
	t.assert(Process.is_pid_alive(storage_1_b.process.pid))
	storage_1_b:connect_net_box()
	t.assert(Process.is_pid_alive(storage_2_a.process.pid))
	storage_2_a:connect_net_box()
	t.assert(Process.is_pid_alive(storage_2_b.process.pid))
	storage_2_b:connect_net_box()
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
    if storage_1_a.process then
        storage_1_a:stop()
    end
    if storage_1_b.process then
        storage_1_b:stop()
    end
    if storage_2_a.process then
        storage_2_a:stop()
    end
    if storage_2_b.process then
        storage_2_b:stop()
    end

    -- Cleanup.
    fio.rmtree(g.datadir)
end)

-- }}} Setup / teardown

-- {{{ setup_cluster

g.test_setup_cluster = function()
    storage_1_a:connect_net_box()
    t.assert_equals(storage_1_a.net_box:eval('return os.getenv("TARANTOOL_LISTEN")'), '3301')
    storage_1_a.net_box:close()
    t.assert_equals(storage_1_a.net_box.state, 'closed')
end

-- }}} setup_cluster
