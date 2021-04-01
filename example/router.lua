#!/usr/bin/env tarantool

require('strict').on()

--[[
local replicasets = {
    'cbf06940-0790-498b-948d-042b62cf3d29',
    'ac522f65-aa94-4134-9f64-51ee384f1a54'
}
]]

-- Call a configuration provider
local cfg = require('localcfg')
cfg.listen = 3300

-- Start the database with sharding
local vshard = require('vshard')
vshard.router.cfg(cfg)
