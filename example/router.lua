#!/usr/bin/env tarantool

require('strict').on()

-- Call a configuration provider
local helper = require('topology_helper')
local cfg = helper.vshard_config('vshard')
cfg.listen = 3300

-- Start the database with sharding
local vshard = require('vshard')
vshard.router.cfg(cfg)
