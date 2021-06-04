#!/usr/bin/env tarantool

local fio = require('fio')
local log = require('log')
local inspect = require('inspect')
local os = require('os')
local conf_lib = require('conf')
local topology = require('topology')

local workdir = os.getenv('TARANTOOL_WORKDIR')
local conf_storage_endpoint = os.getenv('TARANTOOL_CONF_STORAGE_URL')
local topology_name = os.getenv('TARANTOOL_TOPOLOGY_NAME')
local instance_id = fio.basename(arg[0], '.lua')

-- Get instance configuration from Tarantool topology
local conf_client = conf_lib.new({driver = 'etcd', endpoints = { conf_storage_endpoint }})
assert(conf_client ~= nil)
local t = topology.new(conf_client, topology_name)
assert(t ~= nil)
local instance_opts = t:get_instance_options(instance_id)
assert(instance_opts ~= nil)
instance_opts.box_cfg.uri = nil
instance_opts.box_cfg.work_dir = workdir
log.info(string.format('Configuration of instance "%s":', instance_id))
log.info(inspect.inspect(instance_opts))

-- Bootstrap instance
box.cfg(instance_opts.box_cfg)
box.once('schema', function()
    box.schema.user.create('storage', {password = 'storage'})
    box.schema.user.grant('storage', 'replication') -- grant replication role
    box.schema.user.grant('guest', 'read,write,execute,create,drop', 'universe')
    log.info('box.once() executed on ' .. instance_id)
end)
