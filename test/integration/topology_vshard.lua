local fio = require('fio')
local conf_lib = require('conf')
local topology = require('topology')
local consts = require('topology.client.consts')

local function create(topology_name, endpoints, datadir)
    -- Create a configuration client.
    local conf_client = conf_lib.new({driver = 'etcd', endpoints = endpoints})
    assert(conf_client ~= nil)

    -- Create a topology.
    local t = topology.new(conf_client, topology_name, true, {
        bucket_count = 10000,
        collect_bucket_garbage_interval = 0.8,
        collect_lua_garbage = true,
        connection_outdate_delay = 0.5,
        failover_ping_timeout = 0.3,
        memtx_memory = 100 * 1024 * 1024,
        rebalancer_disbalance_threshold = 2,
        rebalancer_max_receiving = 120,
        rebalancer_max_sending = 2,
        replication_connect_quorum = 1,
        shard_index = 'v',
        sync_timeout = 1.5,
    })
    assert(t ~= nil)

    -- Create replicasets.
    local replicaset_1_name = 'replicaset_1'
    local replicaset_2_name = 'replicaset_2'
    t:new_replicaset(replicaset_1_name, {
        master_mode = consts.MASTER_MODE.MODE_AUTO,
        weight = 100,
    })
    t:new_replicaset(replicaset_2_name, {
        master_mode = consts.MASTER_MODE.MODE_AUTO,
        weight = 100,
    })
    -- Create instances.
    local work_dir
    work_dir = fio.pathjoin(datadir, 'storage_1_a_workdir')
    t:new_instance('storage_1_a', replicaset_1_name, {
        box_cfg = {
            listen = '127.0.0.1:3301',
            pid_file = work_dir,
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3301',
        is_master = true,
        is_router = true,
        zone = 1,
    })
    work_dir = fio.pathjoin(datadir, 'storage_1_b_workdir')
    t:new_instance('storage_1_b', replicaset_1_name, {
        box_cfg = {
            listen = '127.0.0.1:3302',
            pid_file = work_dir,
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3302',
        is_storage = true,
        zone = 1,
    })
    work_dir = fio.pathjoin(datadir, 'storage_2_a_workdir')
    t:new_instance('storage_2_a', replicaset_2_name, {
        box_cfg = {
            listen = '127.0.0.1:3303',
            pid_file = work_dir,
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3303',
        is_master = true,
        zone = 1,
    })
    work_dir = fio.pathjoin(datadir, 'storage_2_b_workdir')
    t:new_instance('storage_2_b', replicaset_2_name, {
        box_cfg = {
            listen = '127.0.0.1:3304',
            pid_file = work_dir,
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3304',
        is_storage = true,
        zone = 1,
    })
end

return {
    create = create,
}
