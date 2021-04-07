#!/usr/bin/env tarantool

package.path = 'conf/?.lua;conf/?/init.lua;' .. package.path
local conf_lib = require('conf')
package.path = '../?.lua;../?/init.lua;' .. package.path
local topology = require('topology')

require('strict').on()

local DEFAULT_ENDPOINT = 'http://localhost:2379'
local TOPOLOGY_NAME = 'vshard'

local conf_client = conf_lib.new({DEFAULT_ENDPOINT}, {driver = 'etcd'})
local t = topology.new(conf_client, TOPOLOGY_NAME)
local cfg = t:get_vshard_config()
cfg.listen = 3300

-- Start the database with sharding
local vshard = require('vshard')
vshard.router.cfg(cfg)
