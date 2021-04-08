--- topology module
-- @module topology.topology

local log = require('log')
local uuid = require('uuid')
local utils = require('topology.client.utils')

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
-- @table conf_client
--     A configuration client object. See [Configuration storage module][1].
--     [1]: https://github.com/Totktonada/conf/
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
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-discovery_mode
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
-- @usage
--
-- local conf = require('conf')
-- local topology = require('topology')
--
-- local urls = {
--     'http://localhost:2379',
--     'http://localhost:2381',
--     'http://localhost:2383',
-- }
-- local conf_client = conf.new(urls, {driver = 'etcd'})
-- local t = topology.new(conf_client, 'topology_name')
--
-- @function topology.topology.new
local function new(conf_client, topology_name, opts)
    if not utils.validate_identifier(topology_name) then
        log.error('topology_name is invalid')
        return
    end
    assert(conf_client ~= nil, 'configuration client is not specified')
    local opts = opts or {}
    local topology = conf_client:get(topology_name).data
    if topology == nil or next(topology) == nil then
        topology = {options = opts, replicasets = {}, weights = {}, instance_map = {}}
    end
    conf_client:set(topology_name, topology)

    return setmetatable({
        client = conf_client,
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
--     Note: to specify URIs you must use advertise_uri and listen_uri parameters, see below.
--     Note: instance uuid will be generated automatically.
--     See [Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#box-cfg-params
--     [2]: https://www.tarantool.io/en/doc/latest/reference/configuration/#confval-instance_uuid
--
-- @integer[opt] opts.distance
--     Distance value. See [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-weights
-- @string[opt] opts.advertise_uri
--     URI that will be used by clients to connect to this instance.
--     TODO: describe advertise_uri and listen_uri and it's meanings.
-- @string[opt] opts.listen_uri
--     Address and port that will be used by Tarantool instance to accept connections.
--     TODO: describe advertise_uri and listen_uri and it's meanings.
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
    assert(utils.validate_identifier(instance_name) == true)
    assert(utils.validate_identifier(replicaset_name) == true)
    local opts = opts or {}
    if opts.box_cfg == nil then
        opts.box_cfg = {}
    end
    opts.box_cfg.instance_uuid = uuid.str()
    assert(opts.box_cfg.instance_uuid)
    -- TODO: validate uri and advertise_uri parameters
    -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/uri/#uri-parse
    -- TODO: show warning when listen parameter is present in box_cfg.

    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    -- Get replicaset.
    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local instance_path = string.format('%s.replicas.%s', replicaset_path, instance_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        self:new_replicaset(replicaset_name)
        client:set(instance_path, opts)
    end
    -- Get instance.
    local instance = client:get(instance_path).data
    if instance ~= nil then
        log.error('instance with name "%s" already exists in replicaset "%s"',
                    instance_name, replicaset_name)
    end
    client:set(instance_path, opts)

    -- Add new instance to map 'instance - replicaset'
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    client:set(instance_map_path, replicaset_name)
end

--- Add new replicaset to a topology.
--
-- Adds a new replicaset to a topology.
--
-- Note: cluster uuid will be generated automatically.
-- See [Configuration reference][1].
-- [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#confval-replicaset_uuid
--
-- @param self
--     Topology instance.
-- @string replicaset_name
--     Name of replicaset to add. Name must be globally unique
--     and conform to naming rules (TODO).
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
-- @function instance.new_replicaset
local function new_replicaset(self, replicaset_name, opts)
    if not utils.validate_identifier(replicaset_name) then
        log.error('replicaset_name is invalid')
        return
    end
    -- TODO: check existance of every instance passed in failover_priority
    local opts = opts or {}
    opts.cluster_uuid = uuid.str()
    assert(opts.cluster_uuid ~= nil)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(path).data
    if replicaset ~= nil then
        log.error('replicaset with name "%s" already exists', replicaset_name)
        return
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
--
-- @raise See 'General API notes'.
--
-- @function instance.delete_instance
local function delete_instance(self, instance_name)
    assert(utils.validate_identifier(instance_name), true)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')

    -- Find replicaset name.
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    local replicaset_name = client:get(instance_map_path).data
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
    end
    local instance_path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    client:del(instance_path)

    -- Delete instance from map 'instance - replicaset'
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    client:del(instance_map_path)
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
    assert(utils.validate_identifier(replicaset_name) == true)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    client:del(path)
end

--- Delete a server.
--
-- Deletes server from a topology.
--
-- @param self
--     Topology instance.
-- @string replicaset_name
--     Server name to delete.
--
-- @raise See 'General API notes'.
--
-- @function instance.delete_server
local function delete_server(self, server_name)
    assert(utils.validate_identifier(server_name) == true)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local server_path = string.format('%s.servers.%s', topology_name, server_name)
    client:del(server_path)
end


--- Set parameters of existed Tarantool instance.
--
-- Set parameters of existed Tarantool instance.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
-- @table[opt]   opts
--     @{topology.new_instance|Instance options}.
--
-- @raise See 'General API notes'.
--
-- @function instance.set_instance_property
local function set_instance_property(self, instance_name, opts)
    assert(utils.validate_identifier(instance_name), true)
    assert(type(opts) == 'table')
    -- TODO: validate uri and advertise_uri parameters
    -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/uri/#uri-parse
    -- TODO: show warning when listen parameter is present in box_cfg.
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    -- Find replicaset name.
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    local replicaset_name = client:get(instance_map_path).data
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
    end
    local instance_path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance = client:get(instance_path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
        return
    end

    -- Merge options.
    for k, v in pairs(opts) do
        instance[k] = v
    end
    client:set(instance_path, instance)
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
    assert(utils.validate_identifier(replicaset_name), true)
    assert(type(opts) == 'table')

    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(path).data
    if replicaset == nil then
        log.error('replicaset "%s" does not exist', replicaset_name)
        return
    end

    -- Merge options
    local replicaset_opts = replicaset.options
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
    assert(utils.validate_identifier(instance_name), true)
    local opts = { is_reachable = true }
    self:set_instance_property(instance_name, opts)
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
    assert(utils.validate_identifier(instance_name) == true)
    local opts = { is_reachable = false }
    self:set_instance_property(instance_name, opts)
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
    -- local is_bootstrapped = topology_opts.is_bootstrapped or false
    for k, v in pairs(opts) do
        --[[
        TODO: validate parameters that can be changed
        if k == 'is_bootstrapped' and v then
            log.warn('cluster is bootstrapped, it is not allowed to change option is_bootstrapped')
        end
        if k == 'bucket_count' and is_bootstrapped then
            log.warn('cluster is bootstrapped, it is not allowed to change option bucket_count')
        end
        ]]
        topology_opts[k] = v
    end
    client:set(path, topology_opts)
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
local function get_instance_conf(self, instance_name)
    assert(utils.validate_identifier(instance_name) == true)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')

    -- Find replicaset name.
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    local replicaset_name = client:get(instance_map_path).data
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
    end
    -- Get replicaset.
    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        log.error('replicaset "%s" does not exist', replicaset_name)
        return
    end
    -- Get instance.
    local instance_path = string.format('%s.replicas.%s', replicaset_path, instance_name)
    local instance = client:get(instance_path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
        return
    end

    local box_cfg = instance.box_cfg
    box_cfg['listen'] = instance.listen_uri
    box_cfg['read_only'] = not instance.is_master == true
    box_cfg['replicaset_uuid'] = replicaset.options.cluster_uuid
    box_cfg['replication'] = {}
    -- FIXME: vshard requires 'uri'
    box_cfg['uri'] = instance.advertise_uri
    for name, replica in pairs(replicaset.replicas) do
        -- TODO: take into account links between instances and master_mode in replicaset
        if name ~= instance_name and replica.advertise_uri ~= nil then
            table.insert(box_cfg['replication'], replica.advertise_uri)
        end
    end
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
    assert(utils.validate_identifier(replicaset_name), true)
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')

    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        log.error('replicaset "%s" does not exist', replicaset_name)
        return
    end

    -- Add a table with instance names to response.
    if type(replicaset.options) ~= 'table' or replicaset.options == nil then
        replicaset.options = {}
    end
    local response = replicaset.options
    response.replicas = {}
    if replicaset.replicas == nil then
        return response
    end
    for instance_name in pairs(replicaset.replicas) do
        table.insert(response.replicas, instance_name)
    end

    return utils.sort_table_by_key(response)
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

    if type(topology.options) ~= 'table' or topology.options == nil then
        topology.options = {}
    end
    local response = topology.options

    -- Add a table with replicaset names to response.
    response.replicasets = {}
    if topology.replicasets == nil then
        return response
    end
    for replicaset_name in pairs(topology.replicasets) do
        table.insert(response.replicasets, replicaset_name)
    end

    return utils.sort_table_by_key(response)
end

--- Get vshard configuration.
--
-- Method prepares a vshard configuration structure.
-- vshard configuration structure and possible parameters are described in [1].
-- [1]: https://github.com/tarantool/vshard/blob/master/vshard/replicaset.lua
--
-- @raise See 'General API notes'.
--
-- @return TODO
--
-- @function instance.get_vshard_config
local function get_vshard_config(self)
    local vshard_cfg = self:get_topology_options()
    local replicasets = vshard_cfg.replicasets
    -- note: options in cfg are passed to tarantool
    -- so it should not contain options unsupported by it
    vshard_cfg = utils.remove_table_key(vshard_cfg, 'replicasets')
    vshard_cfg['sharding'] = {}
    local master_uuid = nil
    for _, r in pairs(replicasets) do
        local replicaset_options = self:get_replicaset_options(r)
        local replicas = {}
        if next(replicaset_options.replicas) == nil then
            log.error('no replicas in replicaset "%s"', r)
        end
        for _, v in pairs(replicaset_options.replicas) do
            local instance_cfg = self:get_instance_conf(v)
            if not instance_cfg.read_only then
                master_uuid = instance_cfg.instance_uuid
            end
            instance_cfg.name = v
            replicas[instance_cfg.instance_uuid] = instance_cfg
        end
        local cluster_uuid = replicaset_options.cluster_uuid
        vshard_cfg['sharding'][cluster_uuid] = { replicas = replicas, master = master_uuid }
    end

    -- TODO: set is_bootstrapped to true

    return vshard_cfg
end

--- New an instance link.
--
-- Creates a link between instances.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instances names. Specified instances are downstreams.
-- @array instances
--     Tarantool instance names. These instances will be used
--     as upstream in replication by specified instance.
--
-- @raise See 'General API notes'.
--
-- @function instance.new_instance_link
local function new_instance_link(self, instance_name, instances)
    if not utils.validate_identifier(instance_name) then
        log.error('instance_name is invalid')
        return
    end
    assert(instances ~= nil and type(instances) == 'table', 'incorrect instances table')
    -- TODO: check existance of replicaset and every passed instance
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    -- Find replicaset name.
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    local replicaset_name = client:get(instance_map_path).data
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
    end
    local instance_path  = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance = client:get(instance_path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
	return
    end
    -- TODO: set links
    client:set(instance_path, instance)
end

--- Delete an instance link.
--
-- Deletes a link between instances.
--
-- @param self
--     Topology instance.
-- @string instance_name
--     Tarantool instance name.
-- @array instances
--     Tarantool instance names. These instances will not be used
--     as upstream in replication by specified instance.
--
-- @function instance.delete_instance_link
local function delete_instance_link(self, instance_name, instances)
    assert(utils.validate_identifier(instance_name), true)
    assert(instances ~= nil and type(instances) == 'table', 'incorrect instances table')
    -- TODO: check existance of replicaset and every passed instance
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    -- Find replicaset name.
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    local replicaset_name = client:get(instance_map_path).data
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
    end
    local instance_path = string.format('%s.replicasets.%s.replicas.%s', topology_name, replicaset_name, instance_name)
    local instance = client:get(instance_path).data
    if instance == nil then
        log.error('instance "%s" does not exist', instance_name)
	return
    end
    -- TODO: delete links
    client:set(instance_path, instance)
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
        delete_server = delete_server,

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

        get_vshard_config = get_vshard_config,
    }
}

-- }}} Instance methods

return {
    new = new,
}
