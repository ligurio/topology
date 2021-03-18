local log = require('log')
package.path = package.path .. ";conf/?.lua"
local etcd_client_lib = require('conf.driver.etcd')

-- @module topology

-- Forward declaration.
local mt

-- {{{ Module functions

--- Module functions.
--
-- @section Functions

--- Create a new topology.
--
-- @string[opt]  name
--     A topology name.
-- @table[opt]   opts
--     topology client options.
-- @string[opt]  opts.backend_type
--     A backend type that will used to store topology.
--
-- TODO: Describe supported backend types.
--
-- @table[opt]   opts.backend
--     Backend options.
--
-- XXX: Do we need to duplicate documentation of conf module?
--
-- @array[string] opts.backend.endpoints
--     Endpoint URLs.
-- @string[opt]  opts.backend.user
--     A user ID to authenticate with the server.
-- @string[opt]  opts.backend.password
--     A password to authenticate with given User ID.
--
-- TODO: Add support of a custom http client.
--
-- @raise See 'General API notes'.
--
-- @return topology client instance.
--
-- @function topology.topology.new
local function new(name, opts)
    local backend_type = opts.backend_type or ''
    local backend = opts.backend or {}
    assert(name ~= nil)
    assert(opts.backend ~= {})
    assert(opts.backend_type ~= nil)

    -- TODO: switch to common API
    client = etcd_client_lib.new({
        endpoints = backend.endpoints,
        user = backend.user,
        password = backend.password,
        http_client = backend.http_client,
    })

    local response = client:range(name)
    if response.status == 404 then
        client:put(name, nil)
    end
    log.info("new topology created on %s", backend_type)

    return setmetatable({
        client = client,
        name = name,
    }, mt)
end

-- }}} Module functions

-- {{{ Instance methods

--- Instance methods.
--
-- @section Methods

--- Add a new server to a topology.
--
-- Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
--
-- @param self
--     topology instance.
-- @string name
--     FQDN server name to add.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.new_server
local function new_server(self, name)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Add a new Tarantool instance to a topology.
--
-- Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
-- Default state of added instance is disabled.
--
-- @param self
--     topology instance.
-- @string name
--     Tarantool instance name to add. Name must be unique.
-- @table[opt]   opts
--     instance options.
-- @string[opt]  opts.box_cfg
--     Instance box.cfg options.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_cfg/
-- @string[opt] opts.replicaset_name
--     Replicaset name.
-- @integer[opt] opts.distance
--     Distance value.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-weights
-- @string[opt] opts.advertise_uri
--     URI that will be used by clients to connect to this instance.
-- @string[opt]  opts.zone
--     Availability zone.
-- @boolean[opt]  opts.is_master
--     True if an instance is a master in replication cluster.
--     See https://www.tarantool.io/en/doc/latest/book/replication/repl_architecture/
-- @boolean[opt]  opts.is_storage
--     True if an instance is a storage.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#structure
-- @boolean[opt]  opts.is_router
--     True if an instance is a router.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#structure
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.new_instance
local function new_instance(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Add new replicaset to a topology.
--
-- Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
-- Default state of added instance is disabled.
--
-- @param self
--     topology instance.
-- @string name
--     Name of replicaset to add. Name must be unique.
-- @array[opt]   instances
--     Array of instances names to include to a new replicaset.
-- @table[opt]   opts
--     replicaset options.
-- @string[opt]  opts.master_mode
--     Mode that describes how master instance should be assigned.
--     Possible values:
--       - multimaster - it is allowed to have several instances with master role
--         in a replication cluster, all of them should be assigned manually.
--       - single - it is allowed to have only a single master in replication
--         cluster that should me assigned manually.
--       - auto - master role will be assigned automatically. Auto mode
--         requires specifying advisory roles (leader, follower, or candidate)
--         in Tarantool instance options (box.cfg).
--     See https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_info/election/
-- @array[opt] opts.failover_priority
--     Array of names specifying Tarantool instances failover priority.
-- @array[opt] opts.weight
--     The weight of a replica set defines the capacity of the replica set:
--     the larger the weight, the more buckets the replica set can store.
--     The total size of all sharded spaces in the replica set is also its capacity metric.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-set-weights
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.new_replicaset
local function new_replicaset(self, name, instances, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Delete instance from a topology.
--
-- Deletes an instance. Deleted instance still exists in a topology,
-- but got a status expelled and it cannot be used.
--
-- @param self
--     topology instance.
-- @string name
--     Name of an instance to delete.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.delete_instance
local function delete_instance(self, name)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Delete a replicaset.
--
-- Deletes replicaset from a topology.
--
-- @param self
--     topology instance.
-- @string name
--     Name of a replicaset to delete.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.delete_replicaset
local function delete_replicaset(self, name)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Set parameters of existed Tarantool instance in a topology.
--
-- TODO: Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
-- Default state of added instance is disabled.
--
-- @param self
--     topology instance.
-- @string name
--     Tarantool instance name.
-- @table[opt]   opts
--     @{topology.new_instance|Instance options}.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.set_instance_property
local function set_instance_property(self, name, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Set parameters of a replicaset in a topology.
--
-- TODO: Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
-- Default state of added instance is disabled.
--
-- @param self
--     topology instance.
-- @string name
--     Name of replicaset to add. Name must be unique.
-- @table[opt]   opts
--     @{topology.new_replicaset|Replicaset options}.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.set_replicaset_property
local function set_replicaset_property(self, name, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Switch state of Tarantool instance to a reachable.
--
-- Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
-- Default state of added instance is disabled.
--
-- @param self
--     topology instance.
-- @string name
--     Tarantool instance name.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.set_instance_reachable
local function set_instance_reachable(self, name)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Switch state of Tarantool instance to a unreachable.
--
-- Cделать инстанс недоступным для использования. Он не участвует в репликации,
-- к нему не поступают клиентские запросы, если он был в роли router и т.д.
--
-- @param self
--     topology instance.
-- @string name
--     Tarantool instance name.
--
--     Returns the INVALID_ARGUMENT error if the key does not
--     exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.set_instance_unreachable
local function set_instance_unreachable(self, name)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Set topology property.
--
-- Set topology property.
--
-- @param self
--     topology instance.
-- @table[opt]   opts
--     topology options.
-- @integer[opt]  opts.bucket_count
--     Total bucket count in a cluster. It can not be changed after bootstrap!
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-bucket_count
-- @integer[opt]  opts.rebalancer_disbalance_threshold
--     Maximal bucket count that can be received in parallel by single replicaset.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_disbalance_threshold
-- @integer[opt]  opts.rebalancer_max_receiving
--     The maximum number of buckets that can be received in parallel by a
--     single replica set.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_max_receiving
-- @integer[opt]  opts.rebalancer_max_sending
--     The degree of parallelism for parallel rebalancing.
--     Works for storages only, ignored for routers.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_max_sending
-- @string[opt]  opts.discovery_mode
--     A mode of a bucket discovery fiber: on/off/once.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-discovery_mode
-- @integer[opt]  opts.sync_timeout
--     Timeout to wait for synchronization of the old master with replicas
--     before demotion. Used when switching a master or when manually calling the
--     sync() function.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-sync_timeout
-- @boolean[opt]  opts.collect_lua_garbage
--     If set to true, the Lua collectgarbage() function is called periodically.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-collect_lua_garbage
-- @integer[opt]  opts.collect_bucket_garbage_interval
--     The interval between garbage collector actions, in seconds.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-collect_bucket_garbage_interval
-- @table[opt]  opts.weights
--     A field defining the configuration of relative weights for each zone
--     pair in a replica set.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-weights
-- @string[opt]  opts.shard_index
--     Name or id of a TREE index over the bucket id.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-shard_index
--
--     Returns the INVALID_ARGUMENT error if the key does not exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.set_topology_property
local function set_topology_property(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Get routers.
--
-- Get a table with routers in a topology.
--
-- @param self
--     topology instance.
--
--     Returns the INVALID_ARGUMENT error if the key does not exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
--
-- TODO: routers: (array) Таблица со структурами для каждого инстанса, каждый
-- из которых имеет роль router. Структура должна как минимум иметь: uri, name, is_master,
-- replicaset_name.
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.get_routers
local function get_routers(self)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Get storages.
--
-- Get a table with storages in a topology.
--
-- @param self
--     topology instance.
--
--     Returns the INVALID_ARGUMENT error if the key does not exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
--
-- TODO: (array) Таблица со структурами для каждого инстанса, каждый
-- из которых имеет роль storage. Структура должна как минимум иметь: uri, name, is_master,
-- replicaset_name.
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @see ResponseHeader
-- @see KeyValue
--
-- @function instance.get_storages
local function get_storages(self)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

--- Get instance configuration.
--
-- Get instance configuration.
--
-- @param self
--     topology instance.
--
--     Returns the INVALID_ARGUMENT error if the key does not exist.
--
-- @raise See 'General API notes'.
--
-- @return Response of the following structure:
--
-- ```
-- {
--     header = ResponseHeader,
--     prev_kv = KeyValue (if prev_kv is set),
-- }
-- ```
--
-- @function instance.get_instance_conf
local function get_instance_conf(self, name)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

local function new_instance_link(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

local function delete_instance_link(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

local function delete(self)
    local name = rawget(self, 'name')
    local client = rawget(self, 'client')
    client:put(name, nil)
    client = nil
end

mt = {
    __index = {
        new_server = new_server,
        new_instance = new_instance,
        new_instance_link = new_instance_link,
        new_replicaset = new_replicaset,

        delete = delete,
        delete_instance = delete_instance,
        delete_instance_link = delete_instance_link,
        delete_replicaset = delete_replicaset,

        set_instance_property = set_instance_property,
        set_instance_reachable = set_instance_reachable,
        set_instance_unreachable = set_instance_unreachable,
        set_replicaset_property = set_replicaset_property,
        set_topology_property = set_topology_property,

        get_routers = get_routers,
        get_storages = get_storages,
        get_instance_conf = get_instance_conf,
    }
}

-- }}} Instance methods

return {
    new = new,
}
