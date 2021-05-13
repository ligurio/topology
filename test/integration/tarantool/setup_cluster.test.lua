#!/usr/bin/env tarantool

local test_run = require('test_run')
local tap = require('tap')
local test = tap.test('cluster')
local inspector = test_run.new()
local fio = require('fio')
local os = require('os')
local http_client_lib = require('http.client')
local conf_lib = require('conf')

-- require in-repo version of topology/ sources despite current working directory
local cur_dir = fio.abspath(debug.getinfo(1).source:match("@?(.*/)")
    :gsub('/./', '/'):gsub('/+$', ''))
package.path =
    cur_dir .. '/../../../?/init.lua' .. ';' ..
    cur_dir .. '/../../../?.lua' .. ';' ..
    package.path
local topo = require('topology')
local constants = require('topology.client.constants')

local DEFAULT_ENDPOINT = 'http://localhost:2379'

-- setup etcd
local etcd_bin = tostring(os.getenv("ETCD_PATH")) .. '/etcd'
if not fio.path.exists(etcd_bin) then
    etcd_bin = '/usr/bin/etcd'
    assert(fio.path.exists(etcd_bin), true)
end
local _
local etcd_datadir = fio.tempdir()
--[[
local popen = require('popen')
local env = os.environ()
env['ETCD_DATA_DIR'] = etcd_datadir
env['ETCD_LISTEN_CLIENT_URLS'] = DEFAULT_ENDPOINT
env['ETCD_ADVERTISE_CLIENT_URLS'] = DEFAULT_ENDPOINT
local ph = popen.new({ etcd_bin }, {
    stdout = popen.opts.PIPE,
    env = env,
})
ph:wait()
local res = ph:read():rstrip()
ph:close()
]]
local Process = require('luatest.process')
local t = require('luatest')
local etcd_process = Process:start(etcd_bin, {}, {
    ETCD_DATA_DIR = etcd_datadir,
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

-- create topology in configuration storage
local topology_conf = require('topology_create')
topology_conf.create()

test:plan(9)

--inspector:cmd('create server storage_1_b with rpl_master=default, script="tarantool/storage_1_b.lua"')
--inspector:cmd('start server storage_1_b with wait=True, wait_load=True')

test_run = require('test_run').new()
netbox = require('net.box')
REPLICASET_1 = { 'storage_1_a', 'storage_1_b' }
--REPLICASET_2 = { 'storage_2_a', 'storage_2_b' }

test_run:create_cluster(REPLICASET_1, 'tarantool')
--test_run:create_cluster(REPLICASET_2, 'storage')
util = require('util')
util.wait_master(test_run, REPLICASET_1, 'storage_1_a')
--util.wait_master(test_run, REPLICASET_2, 'storage_2_a')
--util.map_evals(test_run, {REPLICASET_1, REPLICASET_2}, 'bootstrap_storage(\'%s\')', engine)
--util.push_rs_filters(test_run)

--[[
inspector:cmd("create server storage_1_a with script='tarantool/storage_1_a.lua'")
inspector:cmd("start server storage_1_a with wait=True")
--inspector:switch('storage_1_a')

inspector:cmd("create server storage_1_b with script='tarantool/storage_1_b.lua'")
inspector:cmd("start server storage_1_b with wait=True")

inspector:cmd("create server storage_2_a with script='tarantool/storage_2_a.lua'")
inspector:cmd("start server storage_2_a with wait=True")

inspector:cmd("create server storage_2_b with script='tarantool/storage_2_b.lua'")
inspector:cmd("start server storage_2_b with wait=True")
]]

--print(box.cfg)
--vshard.storage.cfg(cfg, instance_uuid)
inspector:switch('default')
inspector:cmd("cleanup server storage_1_a")

--[[
test:is(
    inspector:cmd('create server storage_1_b with rpl_master=default, script="tarantool/storage_1_b.lua"'),
    true, 'instance storage_1_b created')
test:is(
    inspector:cmd('start server storage_1_b with wait=True, wait_load=True'),
    true, 'instance storage_1_b started')
test:is(
    inspector:cmd('create server storage_2_a with rpl_master=default, script="tarantool/storage_2_a.lua"'),
    true, 'instance storage_2_a created')
test:is(
    inspector:cmd('start server storage_2_a with wait=True, wait_load=True'),
    true, 'instance storage_2_a started')
test:is(
    inspector:cmd('create server storage_2_b with rpl_master=default, script="tarantool/storage_2_b.lua"'),
    true, 'instance storage_2_b created')
test:is(
    inspector:cmd('start server storage_2_b with wait=True, wait_load=True'),
    true, 'instance storage_2_b started')
]]

-- Create a configuration client.
local urls = { DEFAULT_ENDPOINT }
local conf_client = conf_lib.new({driver = 'etcd', endpoints = urls})
local autocommit = true
local topology_name = 'tarantool_topology'
local topology = topo.new(conf_client, topology_name, autocommit)
assert(topology ~= nil)

box.cfg{}
_ = box.schema.create_space('test')
_ = _:create_index('pk')
box.space.test:insert{1}
box.space.test:select{}
box.space.test:drop()

test:is(
    inspector:cmd('delete server storage_1_b'),
    true, 'instance storage_1_b delete'
)
test:is(
    inspector:cmd('delete server storage_2_a'),
    true, 'instance storage_2_a delete'
)
test:is(
    inspector:cmd('delete server storage_2_b'),
    true, 'instance storage_2_b delete'
)

-- teardown etcd
--etcd_process:kill()
fio.rmtree(etcd_datadir)

-- cleanup
test:check()
os.exit(0)
