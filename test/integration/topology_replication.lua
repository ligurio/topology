local conf_lib = require('conf')
local topology_lib = require('topology')

local function create(topology_name, endpoints)
    -- Create a configuration client.
    local conf_client = conf_lib.new({
        driver = 'etcd',
        endpoints = endpoints
    })
    assert(conf_lib ~= nil)

    -- Create a topology.
    local t = topology_lib.new(conf_client, topology_name, true)
    assert(t ~= nil)

    -- Create instances.
    local replicaset_name = 'Tweedledum_and_Tweedledee'
    t:new_instance('replica_1_a', {
        box_cfg = {
            listen = '127.0.0.1:3301',
        },
        advertise_uri = 'storage:storage@127.0.0.1:3301',
        is_master = true,
        replicaset = replicaset_name,
    })
    t:new_instance('replica_1_b', {
        box_cfg = {
            listen = '127.0.0.1:3302',
        },
        advertise_uri = 'storage:storage@127.0.0.1:3302',
        replicaset = replicaset_name,
    })
end

return {
    create = create,
}
