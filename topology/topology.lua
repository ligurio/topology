local log = require('log')
local utils = require('topology.utils')
local constants = require('topology.constants')
package.path = package.path .. ";conf/?.lua"
local conf_lib = require('conf.conf')

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
-- @table backend_opts
--     A configuration client options.
--
-- XXX: Do we need to duplicate documentation of conf module?
--
-- @string driver
--     Driver name. Only 'etcd' is supported now.
-- @array[string] backend_opts.endpoints
--     Endpoint URLs.
-- @string[opt]  backend_opts.user
--     A user ID to authenticate with the server.
-- @string[opt]  backend_opts.password
--     A password to authenticate with given User ID.
--
-- TODO: Add support of a custom http client.
--
-- @table[opt] opts
--     Topology options.
-- @boolean[opt]  opts.is_bootstrapped
--     Set to true when cluster is bootstrapped. Some topology options
--     cannot be changed once cluster is bootstrapped. For example bucket_count.
-- @integer[opt]  opts.bucket_count
--     Total bucket count in a cluster. It can not be changed after cluster bootstrap!
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-bucket_count
-- @integer[opt]  opts.rebalancer_disbalance_threshold
--     Maximal bucket count that can be received in parallel by single replicaset.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_disbalance_threshold
-- @integer[opt]  opts.rebalancer_max_receiving
--     The maximum number of buckets that can be received in parallel by a
--     single replica set. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_max_receiving
-- @integer[opt]  opts.rebalancer_max_sending
--     The degree of parallelism for parallel rebalancing.
--     Works for storages only, ignored for routers.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_max_sending
-- @string[opt]  opts.discovery_mode
--     A mode of a bucket discovery fiber: on/off/once.
--     See [Sharding Configuration reference][1].
--     See https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-discovery_mode
-- @integer[opt]  opts.sync_timeout
--     Timeout to wait for synchronization of the old master with replicas
--     before demotion. Used when switching a master or when manually calling the
--     sync() function. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-sync_timeout
-- @boolean[opt]  opts.collect_lua_garbage
--     If set to true, the Lua collectgarbage() function is called periodically.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-collect_lua_garbage
-- @integer[opt]  opts.collect_bucket_garbage_interval
--     The interval between garbage collector actions, in seconds.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-collect_bucket_garbage_interval
-- @table[opt]  opts.weights
--     A field defining the configuration of relative weights for each zone
--     pair in a replica set. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-weights
-- @string[opt]  opts.shard_index
--     Name or id of a TREE index over the bucket id. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-shard_index
-- @string[opt]  opts.zone
--     Replica zone (see weighted routing in the section 'Replicas weight configuration').
--
-- @raise See 'General API notes'.
--
-- @return topology client instance.
--
-- @function topology.topology.new
local function new(topology_name, backend_opts, opts)
    assert(backend_opts ~= nil and type(backend_opts) == 'table')
    assert(topology_name ~= nil and type(topology_name) == 'string')
    assert(backend_opts['driver'] ~= nil)
    assert(#backend_opts['endpoints'] > 0)
    local opts = opts or {}

    local client = conf_lib.new(backend_opts.endpoints, backend_opts)
    local topology = client:get(topology_name).data
    if topology ~= nil then
        log.error("topology with name '%s' already exists", topology_name)
        return
    end
    client:set(topology_name, {options = opts, replicasets = {}, weights = {}})

    return setmetatable({
        client = client,
        name = topology_name,
    }, mt)
end

-- }}} Module functions

-- {{{ Instance methods

--- Instance methods.
--
-- @section Methods

--- Add a new server to a topology.
--
-- Add a new server to a topology.
--
-- @param self
--     Topology instance.
-- @string name
--     FQDN server name to add. Name must be globally unique and conform
--     to naming rules.
--
-- @raise See 'General API notes'.
--
-- @function instance.new_server
local function new_server(self, server_name)
    assert(server_name ~= nil and type(server_name) == 'string')
    assert(utils.validate_identifier(server_name), true)
end

--- Add a new Tarantool instance to a topology.
--
-- Add a new Tarantool instance to a topology.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name to add. Name must be globally unique and
--     conform to naming rules (TODO).
-- @string replicaset_name
--     Replicaset name. Name must be globally unique and conform
--     to naming rules (TODO). It will be created if it does not exist.
-- @table[opt]  opts
--     instance options.
-- @table[opt]  opts.box_cfg
--     Instance box.cfg options. box.cfg options should contain at least Uniform Resource Identifier
--     of remote instance with **required** login and password. See [Configuration parameters][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#box-cfg-params
-- @integer[opt] opts.distance
--     Distance value. See [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-weights
-- @string[opt] opts.advertise_uri
--     URI that will be used by clients to connect to this instance.
-- @string[opt]  opts.zone
--     Availability zone.
-- @boolean[opt]  opts.is_master
--     True if an instance is a master in replication cluster. See [Replication architecture][1].
--     You can define 0 or 1 masters for each replicaset. It accepts all write requests.
--     [1]: https://www.tarantool.io/en/doc/latest/book/replication/repl_architecture/
-- @boolean[opt]  opts.is_storage
--     True if an instance is a storage. See [Sharding Architecture][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#structure
-- @boolean[opt]  opts.is_router
--     True if an instance is a router. See [Sharding Architecture][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#structure
--
-- @raise See 'General API notes'.
--
-- @function instance.new_instance
local function new_instance(self, instance_name, replicaset_name, opts)
    assert(instance_name ~= nil and type(instance_name) == 'string')
    assert(utils.validate_identifier(instance_name), true)
    assert(utils.validate_identifier(replicaset_name), true)
    local opts = opts or {}
    if opts.box_cfg == nil then
        opts.box_cfg = { uuid = utils.uuid() }
    end

    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance = client:get(path).data
    if instance ~= nil then
        log.error("instance with name '%s' already exists", instance_name)
        return
    end
    client:set(path, opts)
end

--- Add new replicaset to a topology.
--
-- Adds a new replicaset to a topology.
--
-- @param self
--     Topology instance.
-- @string replicaset_name
--     Name of replicaset to add. Name must be globally unique
--     and conform to naming rules (TODO).
-- @array instances
--     Array of instances names to include to a new replicaset.
--     Instances whose names are specified should be already exist in a topology.
-- @table[opt]   opts
--     replicaset options.
-- @string[opt]  opts.master_mode
--     Mode that describes how master instance should be assigned.
--     Possible values:
--       - single - it is allowed to have only a single master in replication
--         cluster that should me assigned manually.
--       - multimaster - it is allowed to have several instances with master role
--         in a replication cluster, all of them should be assigned manually.
--       - auto - master role will be assigned automatically. Auto mode
--         requires specifying advisory roles (leader, follower, or candidate)
--         in Tarantool instance options (box.cfg). See [box.info.election][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_info/election/
-- @array[opt] opts.failover_priority
--     Array of names specifying Tarantool instances failover priority.
-- @array[opt] opts.weight
--     The weight of a replica set defines the capacity of the replica set:
--     the larger the weight, the more buckets the replica set can store.
--     The total size of all sharded spaces in the replica set is also its capacity metric.
--     See [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-set-weights
--
-- @raise See 'General API notes'.
--
-- @function instance.new_replicaset
local function new_replicaset(self, replicaset_name, opts)
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    assert(utils.validate_identifier(replicaset_name), true)
    -- TODO: check existance instances passed in failover_priority
    local opts = opts or {}
    opts.uuid = utils.uuid()
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(path)
    if replicaset ~= nil then
        log.error("replicaset with name '%s' already exists", replicaset_name)
    end
    client:set(path, { options = opts })
end

--- Delete instance from a topology.
--
-- Deletes an instance. Deleted instance still exists in a topology,
-- but got a status expelled and it cannot be used.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Name of an instance to delete.
-- @string instance_name
--     Name of a replicaset to delete.
--
-- @raise See 'General API notes'.
--
-- @function instance.delete_instance
local function delete_instance(self, instance_name, replicaset_name)
    assert(instance_name ~= nil and type(instance_name) == 'string')
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    client:del(path)
end

--- Delete a replicaset.
--
-- Deletes replicaset from a topology.
--
-- @param self
--     Topology instance.
-- @string replicaset_name
--     Name of a replicaset to delete.
--
-- @raise See 'General API notes'.
--
-- @function instance.delete_replicaset
local function delete_replicaset(self, replicaset_name)
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    client:del(path)
end

--- Set parameters of existed Tarantool instance.
--
-- Set parameters of existed Tarantool instance.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
-- @string replicaset_name
--     Replicaset name.
-- @table[opt]   opts
--     @{topology.new_instance|Instance options}.
--
-- @raise See 'General API notes'.
--
-- @function instance.set_instance_property
local function set_instance_property(self, instance_name, replicaset_name, opts)
    assert(instance_name ~= nil and type(instance_name) == 'string')
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    assert(type(opts) == 'table')

    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance_opts = client:get(path).data
    if instance_opts == nil then
        log.error('instance "%s" does not exist', instance_name)
        return
    end

    -- Merge options.
    for k, v in pairs(opts) do
        instance_opts[k] = v
    end
    client:set(path, instance_opts)
end

--- Set parameters of an existed replicaset in a topology.
--
-- Set parameters of a replicaset in a topology.
--
-- @param self
--     Topology instance.
-- @string replicaset_name
--     Replicaset name.
-- @table[opt]   opts
--     @{topology.new_replicaset|Replicaset options}.
--
-- @raise See 'General API notes'.
--
-- @function instance.set_replicaset_property
local function set_replicaset_property(self, replicaset_name, opts)
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    assert(type(opts) == 'table')

    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset_opts = client:get(path).data
    if replicaset_opts == nil then
        log.error('replicaset "%s" does not exist', replicaset_name)
        return
    end

    -- Merge options
    for k, v in pairs(opts) do
        replicaset_opts[k] = v
    end
    client:set(path, { options = replicaset_opts })
end

--- Switch state of Tarantool instance to a reachable.
--
-- Switch state of Tarantool instance to a reachable.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
--
-- @raise See 'General API notes'.
--
-- @function instance.set_instance_reachable
local function set_instance_reachable(self, instance_name)
    local topology_name = rawget(self, 'name')
end

--- Switch state of Tarantool instance to a unreachable.
--
-- Cделать инстанс недоступным для использования. Он не участвует в репликации,
-- к нему не поступают клиентские запросы, если он был в роли router и т.д.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
--
-- @raise See 'General API notes'.
--
-- @function instance.set_instance_unreachable
local function set_instance_unreachable(self, instance_name)
    local topology_name = rawget(self, 'name')
end

--- Set topology property.
--
-- Set topology property.
--
-- @param self
--     Topology instance.
-- @table[opt]   opts
--     @{topology.topology.new|Topology options}.
--
-- @raise See 'General API notes'.
--
-- @function instance.set_topology_property
local function set_topology_property(self, opts)
    assert(type(opts) == 'table')

    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.options', topology_name)
    local topology_opts = client:get(path).data
    if topology_opts == nil then
        log.error('topology "%s" does not exist', topology_name)
        return
    end

    -- Merge options
    local is_bootstrapped = topology_opts.is_bootstrapped or false
    for k, v in pairs(opts) do
        if not (k == 'is_bootstrapped' and is_bootstrapped) then
            topology_opts[k] = v
        else
            log.info('cluster is bootstrapped, it is not allowed to change option is_bootstrapped')
        end
        if k == 'bucket_count' and is_bootstrapped then
            log.info('cluster is bootstrapped, it is not allowed to change option bucket_count')
        end
    end
    client:set(path .. 'options', topology_opts)
end

--- Get routers.
--
-- Get a table with routers in a topology.
--
-- @param self
--     Topology instance.
--
-- @raise See 'General API notes'.
--
-- @return Array with instances names.
--
-- @function instance.get_routers
local function get_routers(self)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets', topology_name)
    local replicasets = client:get(path).data
    local routers = {}
    if replicasets == nil then
        return routers
    end

    for _, replicaset_opts in pairs(replicasets) do
        local replicas = replicaset_opts.replicas or {}
        for instance_name, instance_opts in pairs(replicas) do
            if instance_opts.is_router then
                table.insert(routers, instance_name)
            end
        end
    end

    return routers
end

--- Get storages.
--
-- Get a table with storages in a topology.
--
-- @param self
--     Topology instance.
--
-- @raise See 'General API notes'.
--
-- @return Array with instances names.
--
-- @function instance.get_storages
local function get_storages(self)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets', topology_name)
    local replicasets = client:get(path).data
    local storages = {}
    if replicasets == nil then
        return storages
    end

    for _, replicaset_opts in pairs(replicasets) do
        local replicas = replicaset_opts.replicas or {}
        for instance_name, instance_opts in pairs(replicas) do
            if instance_opts.is_storage then
                table.insert(storages, instance_name)
            end
        end
    end

    assert(#storages, 1)
    return storages
end

--- Get instance configuration.
--
-- Get instance configuration.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
-- @string replicaset_name
--     Replicaset name.
--
-- @raise See 'General API notes'.
--
-- @return Returns a table where keys are [Tarantool configuration parameters][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#box-cfg-params
--
-- @function instance.get_instance_conf
local function get_instance_conf(self, instance_name, replicaset_name)
    assert(instance_name ~= nil and type(instance_name) == 'string')
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')

    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local instance_path = string.format('%s.replicas.%s', replicaset_path, instance_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        log.error('replicaset "%s" does not exist', replicaset_name)
        return
    end
    local instance = client:get(instance_path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
        return
    end
    local box_cfg = instance.box_cfg
    box_cfg['cluster_uuid'] = replicaset.cluster_uuid
    -- TODO: build box.cfg.replication using advertise_uri and replication graph
    -- TODO: merge with topology-specific and replicaset-specific box.cfg options

    return utils.sort_table_by_key(box_cfg)
end

--- Get replicaset options.
--
-- Get replicaset options.
--
-- @param self
--     Topology instance.
-- @string replicaset_name
--     Replicaset name.
--
-- @raise See 'General API notes'.
--
-- @return
--
-- @function instance.get_replicaset_options
local function get_replicaset_options(self, replicaset_name)
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')

    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        log.error('replicaset "%s" does not exist', replicaset_name)
        return
    end

    --TODO: return utils.sort_table_by_key(replicaset.options)
    return replicaset.options
end

--- Get topology options.
--
-- Get topology options.
--
-- @param self
--     Topology instance.
--
-- @raise See 'General API notes'.
--
-- @return
--
-- @function instance.get_topology_options
local function get_topology_options(self)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local topology = client:get(topology_name).data
    if topology == nil then
        log.error('topology "%s" does not exist', topology_name)
    end

    -- TODO: return utils.sort_table_by_key(topology.options)
    return topology.options
end

--- New an instance link.
--
-- Creates a link between instances.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instances names. Specified instances are downstreams.
-- @string replicaset_name
--     Replicaset name.
-- @array instances
--     Tarantool instance names. These instances will be used
--     as upstream in replication by specified instance.
--
-- @raise See 'General API notes'.
--
-- @function instance.new_instance_link
local function new_instance_link(self, instance_name, replicaset_name, instances)
    assert(instance_name ~= nil and type(instance_name) == 'string')
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    assert(instances ~= nil and type(instances) == 'table')
    -- TODO: check existance of replicaset and every passed instance
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance = client:get(path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
	return
    end
    -- TODO: set links
    client:set(path, instance)
end

--- Delete an instance link.
--
-- Deletes a link between instances.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
-- @string replicaset_name
--     Replicaset name.
-- @array instances
--     Tarantool instance names. These instances will not be used
--     as upstream in replication by specified instance.
--
-- @function instance.delete_instance_link
local function delete_instance_link(self, instance_name, replicaset_name, instances)
    assert(instance_name ~= nil and type(instance_name) == 'string')
    assert(replicaset_name ~= nil and type(replicaset_name) == 'string')
    assert(instances ~= nil and type(instances) == 'table')
    -- TODO: check existance of replicaset and every passed instance
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance = client:get(path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
	return
    end
    -- TODO: delete links
    client:set(path, instance)
end

--- Delete topology.
--
-- Deletes a topology.
--
-- @param self
--     Topology instance.
--
-- @function instance.delete
local function delete(self)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    client:del(topology_name)
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
        get_topology_options = get_topology_options,
        get_replicaset_options = get_replicaset_options,
    }
}

-- }}} Instance methods

return {
    new = new,
}
