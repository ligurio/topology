package.path = package.path .. ";../?.lua"
local topology = require('topology.topology')
local log = require('log')
local inspect = require('inspect')

--[[
Module prepares vshard configuration using Topology module.
vshard configuration described in [1].

1. https://github.com/tarantool/vshard/blob/master/vshard/replicaset.lua
]]

local ETCD_ENDPOINT = 'http://localhost:2379'
local replicaset_1_name = 'replicaset_1'
-- TODO: local replicaset_2_name = 'replicaset_2'

local function remove_key(t, key)
    local d = {}
    for k, v in pairs(t) do
        if not k == key then
            d[k] = v
        end
    end

    return d
end

-- Create configuration suitable for vshard
local function vshard_config(topology_name, instance_name)
    local backend_opts = {
        endpoints = {ETCD_ENDPOINT},
        driver = 'etcd'
    }
    local cfg = {}
    local t = topology.new(topology_name, backend_opts)
    if t == nil then
        log.error('cannot create new topology')
        return cfg
    end
    cfg = t:get_topology_options()
    -- options in cfg are passed to tarantool
    -- so it should not be there keys unsupported by it
    cfg = remove_key(cfg, 'replicasets')
    cfg['sharding'] = {}
    local master_uuid = nil
    -- TODO: for _, r in pairs({ replicaset_1_name, replicaset_2_name }) do
    for _, r in pairs({ replicaset_1_name }) do
        local replicaset_options = t:get_replicaset_options(r)
        local replicas = {}
        for _, v in pairs(replicaset_options.replicas) do
            local instance_cfg = t:get_instance_conf(v, r)
            if not instance_cfg.read_only then
                instance_cfg.master = true
                master_uuid = instance_cfg.instance_uuid
            end
            instance_cfg.name = v
            replicas[instance_cfg.instance_uuid] = instance_cfg
        end
        local cluster_uuid = replicaset_options.cluster_uuid
        cfg['sharding'][cluster_uuid] = { replicas = replicas, master = master_uuid }
    end

    local uuid = nil
    if instance_name then
        -- TODO: support get_instance_conf() wo replicaset argument
        local instance_cfg = t:get_instance_conf(instance_name, replicaset_1_name)
        uuid = instance_cfg.instance_uuid
    end

    log.info(inspect(cfg))

    return cfg, uuid
end

return {
    vshard_config = vshard_config
}
