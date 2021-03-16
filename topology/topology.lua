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
-- @table[opt]   opts
--     topology client options.
-- @string[opt]  opts.name
--     An unique topology name.
-- @string[opt]  opts.backend_name
--     A backend type that will used to store topology.
--
-- TODO: Describe supported backend names.
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
local function new(opts)
    local cluster_name = opts.cluster_name or ''
    local backend_type = opts.backend_name or ''
    local backend = opts.backend or {}
    if not opts.name or not backend_type or not backend then
        return nil
    end

    -- TODO: switch to common API
    client = etcd_client_lib.new({
        endpoints = {backend.endpoints},
        user = backend.user,
        password = backend.password,
        http_client = backend.http_client,
    })

    -- TODO: create an empty topology if there is no topology
    -- with name <name> or do nothing if it already exists.

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
-- @integer[opt] opts.weight
--     Weight value.
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
-- @string[opt] opts.replicaset_name
--     Replicaset name.
-- @integer[opt] opts.weight
--     Weight value.
-- @array[opt] opts.failover_priority
--     Array of names specifying Tarantool instances failover priority.
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

--- Delete replicaset from a topology.
--
-- Deletes a replicaset.
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
-- Creates a key if it does not exist. Increments a revision of
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
-- TODO: Cделать инстанс недоступным для использования. Он не участвует в репликации,
-- к нему не поступают клиентские запросы, если он был в роли router и т.д.
--
-- @param self
--     topology instance.
-- @table[opt]   opts
--     topology options.
-- @integer[opt]  opts.rebalancer_disbalance_threshold
--     Maximal bucket count that can be received in parallel by single replicaset.
--     This count must be limited, because else, when a new replicaset is
--     added to a cluster, the rebalancer would send to it very big amount of buckets
--     from existing replicasets - it produces heavy load on a new replicaset to apply
--     all these buckets.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#rebalancer
-- @integer[opt]  opts.rebalancer_max_receiving
--     maximal bucket disbalance percents. Disbalance for each replicaset is
--     calculated by formula:
--     |etalon_bucket_count - real_bucket_count| / etalon_bucket_count * 100.
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#rebalancer
-- @integer[opt]  opts.bucket_count
--     Total bucket count in a cluster. It can not be changed after bootstrap!
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
-- TODO: Cделать инстанс недоступным для использования. Он не участвует в репликации,
-- к нему не поступают клиентские запросы, если он был в роли router и т.д.
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
-- Get storages in topology.
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
    local opts = opts or {}
    return nil
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
