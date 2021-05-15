local conf_lib = require('conf')
local topology = require('topology')
local constants = require('topology.client.constants')

local function create(topology_name, endpoints)
    -- Create a configuration client.
    local conf_client = conf_lib.new({driver = 'etcd', endpoints = endpoints})
    assert(conf_lib ~= nil)

    -- Create a topology.
    local t = topology.new(conf_client, topology_name, true)
    assert(t ~= nil)

    -- Create replicasets.
    local replicaset_1_name = 'replicaset_1'
    local replicaset_2_name = 'replicaset_2'
    t:new_replicaset(replicaset_1_name, {
        master_mode = constants.MASTER_MODE.MODE_AUTO,
        weight = 1
    })
    t:new_replicaset(replicaset_2_name, {
        master_mode = constants.MASTER_MODE.MODE_AUTO,
        weight = 1
    })
    -- Create instances.
    t:new_instance('replica_1_a', replicaset_1_name, {
        box_cfg = {},
        advertise_uri = 'storage:storage@127.0.0.1:3301',
        listen_uri = '127.0.0.1:3301',
        is_master = true,
    })
    t:new_instance('replica_1_b', replicaset_1_name, {
        box_cfg = {},
        advertise_uri = 'storage:storage@127.0.0.1:3302',
        listen_uri = '127.0.0.1:3302',
        is_master = false,
    })
    t:new_instance('replica_2_a', replicaset_2_name, {
        box_cfg = {},
        advertise_uri = 'storage:storage@127.0.0.1:3303',
        listen_uri = '127.0.0.1:3303',
        is_master = true,
    })
    t:new_instance('replica_2_b', replicaset_2_name, {
        box_cfg = {},
        advertise_uri = 'storage:storage@127.0.0.1:3304',
        listen_uri = '127.0.0.1:3304',
        is_master = false,
    })
end

return {
    create = create,
}
