local fio = require('fio')
local conf_lib = require('conf')
local topology_lib = require('topology')

local function create(topology_name, endpoints, datadir)
    -- Create a configuration client.
    local conf_client = conf_lib.new({driver = 'etcd', endpoints = endpoints})
    assert(conf_client ~= nil)

    local vshard_groups = {
        ['vshard_test'] = {
            bucket_count = 10000,
            collect_lua_garbage = true,
            connection_outdate_delay = 0.5,
            failover_ping_timeout = 0.3,
            rebalancer_disbalance_threshold = 2,
            rebalancer_max_receiving = 120,
            rebalancer_max_sending = 2,
            replication_connect_quorum = 1,
            shard_index = 'v',
            sync_timeout = 1.5,
        }
    }

    -- Create a topology.
    local t = topology_lib.new(conf_client, topology_name, true)
    assert(t ~= nil)
    t:set_topology_options({
        vshard_groups = vshard_groups,
    })

    -- Create replicasets.
    local replicaset_1_name = 'replicaset_1'
    local ok
    -- Create instances.
    local work_dir
    work_dir = fio.pathjoin(datadir, 'router_workdir')
    ok = t:new_instance('router', {
        box_cfg = {
            listen = '127.0.0.1:3300',
            pid_file = fio.pathjoin(work_dir, 'router.pid'),
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3300',
        is_router = true,
        zone = 1,
        replicaset = replicaset_1_name,
    })
    assert(ok == true)
    work_dir = fio.pathjoin(datadir, 'storage_1_a_workdir')
    ok = t:new_instance('storage_1_a', {
        box_cfg = {
            listen = '127.0.0.1:3301',
            pid_file = fio.pathjoin(work_dir, 'storage_1_a.pid'),
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3301',
        is_master = true,
        is_storage = true,
        zone = 1,
        replicaset = replicaset_1_name,
        vshard_groups = { 'vshard_test' },
    })
    assert(ok == true)
    work_dir = fio.pathjoin(datadir, 'storage_1_b_workdir')
    ok = t:new_instance('storage_1_b', {
        box_cfg = {
            listen = '127.0.0.1:3302',
            pid_file = fio.pathjoin(work_dir, 'storage_1_b.pid'),
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3302',
        is_storage = true,
        zone = 1,
        replicaset = replicaset_1_name,
        vshard_groups = { 'vshard_test' },
    })
    assert(ok == true)
    --[[
    work_dir = fio.pathjoin(datadir, 'storage_1_c_workdir')
    ok = t:new_instance('storage_1_c', {
        box_cfg = {
            listen = '127.0.0.1:3304',
            pid_file = fio.pathjoin(work_dir, 'storage_1_c.pid'),
            work_dir = work_dir,
            wal_dir = work_dir,
            memtx_dir = work_dir,
            vinyl_dir = work_dir,
        },
        advertise_uri = 'storage:storage@127.0.0.1:3304',
        is_storage = true,
        zone = 1,
        replicaset = replicaset_1_name,
        vshard_groups = { 'vshard_test' },
    })
    assert(ok == true)
    ]]
end

return {
    create = create,
}
