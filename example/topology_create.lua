package.path = 'conf/?.lua;conf/?/init.lua;' .. package.path
local conf_lib = require('conf')
package.path = package.path .. ";../?.lua"
local topology = require('topology.topology')
local constants = require('topology.constants')
local log = require('log')

local ETCD_ENDPOINT = 'http://localhost:2379'

-- Create a configuration client.
local urls = { ETCD_ENDPOINT }
local conf_client = conf_lib.new(urls, {driver = 'etcd'})

-- Create a topology.
local topology_name = 'vshard'
local topology_opts = {
    bucket_count = 154,
    rebalancer_disbalance_threshold = 13,
    rebalancer_max_receiving = 4,
    rebalancer_max_sending = 6,
}
local t = topology.new(conf_client, topology_name, topology_opts)
if t == nil then
    log.error('cannot create new topology')
    os.exit(1)
end
t:set_topology_property(topology_opts)

-- Create replicaset.
local opts = {
    master_mode = constants.MASTER_MODE.MODE_AUTO,
    weight = 1
}
local replicaset_1_name = 'replicaset_1'
local replicaset_2_name = 'replicaset_2'
t:new_replicaset(replicaset_1_name, opts)
t:new_replicaset(replicaset_2_name, opts)

-- Create instances.
local instance_1_name = 'storage_1_a'
local instance_2_name = 'storage_1_b'
local instance_3_name = 'storage_2_a'
local instance_4_name = 'storage_2_b'

local instance_1_opts = {
    box_cfg = {},
    advertise_uri = 'storage:storage@127.0.0.1:3301',
    listen_uri = '127.0.0.1:3301',
    is_master = true,
}
local instance_2_opts = {
    box_cfg = {},
    advertise_uri = 'storage:storage@127.0.0.1:3302',
    listen_uri = '127.0.0.1:3302',
    is_master = false,
}
local instance_3_opts = {
    box_cfg = {},
    advertise_uri = 'storage:storage@127.0.0.1:3303',
    listen_uri = '127.0.0.1:3303',
    is_master = false,
}
local instance_4_opts = {
    box_cfg = {},
    advertise_uri = 'storage:storage@127.0.0.1:3304',
    listen_uri = '127.0.0.1:3304',
    is_master = false,
}
t:new_instance(instance_1_name, replicaset_1_name, instance_1_opts)
t:new_instance(instance_2_name, replicaset_1_name, instance_2_opts)

t:new_instance(instance_3_name, replicaset_1_name, instance_3_opts)
t:new_instance(instance_4_name, replicaset_1_name, instance_4_opts)
-- TODO: create instances in two different replicasets
--t:new_instance(instance_3_name, replicaset_2_name, instance_3_opts)
--t:new_instance(instance_4_name, replicaset_2_name, instance_4_opts)
