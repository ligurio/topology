#!/usr/bin/env tarantool

local test_run = require('test_run')
local tap = require('tap')
local test = tap.test('cluster')
local inspector = test_run.new()
local fio = require('fio')
local os = require('os')
local http_client_lib = require('http.client')
local topology_conf = require('topology_create')

-- require in-repo version of topology/ sources despite current working directory
local cur_dir = fio.abspath(debug.getinfo(1).source:match("@?(.*/)")
    :gsub('/./', '/'):gsub('/+$', ''))
package.path =
    cur_dir .. '/../../../?/init.lua' .. ';' ..
    cur_dir .. '/../../../?.lua' .. ';' ..
    package.path
--local topology = require('topology')
--local constants = require('topology.client.constants')

local DEFAULT_ENDPOINT = 'http://localhost:2379'

-- setup etcd
local etcd_bin = tostring(os.getenv("ETCD_PATH")) .. '/etcd'
if not fio.path.exists(etcd_bin) then
    etcd_bin = '/usr/bin/etcd'
    assert(fio.path.exists(etcd_bin), true)
end
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
topology_conf.create()

test:plan(3)

local _
test:is(
    inspector:cmd('create server replica with rpl_master=default, script="tarantool/replica.lua"'),
    true, 'instance created')
test:is(
    inspector:cmd('start server replica with wait=True, wait_load=True'),
    true, 'instance started')

box.cfg{}
_ = box.schema.create_space('test')
_ = _:create_index('pk')
box.space.test:insert{1}
box.space.test:select{}
box.space.test:drop()

test:is(
    inspector:cmd('delete server replica'),
    true, 'instance delete'
)

-- teardown etcd
etcd_process:kill()
fio.rmtree(etcd_datadir)

-- cleanup
test:check()
os.exit(0)
