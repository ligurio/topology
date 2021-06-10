--- topology module
-- @module topology.topology

local checks = require('checks')
local log = require('log')
local uuid = require('uuid')
local cfg_correctness = require('topology.client.cfg_correctness')

local topology_opts_types = {
    bucket_count = '?number',
    collect_bucket_garbage_interval = '?number',
    collect_lua_garbage = '?boolean',
    discovery_mode = '?string',
    is_bootstrapped = '?boolean',
    rebalancer_disbalance_threshold = '?number',
    rebalancer_max_receiving = '?number',
    rebalancer_max_sending = '?number',
    shard_index = '?string',
    sync_timeout = '?number',
    vshard_groups = '?table',
    weights = '?table',
    zone = '?string',
}

local replicaset_opts_types = {
    master_mode = '?string',
    failover_priority = '?table',
    weight = '?table',
}

local instance_opts_types = {
    advertise_uri = '?string',
    box_cfg = '?table',
    distance = '?number',
    is_master = '?boolean',
    is_router = '?boolean',
    is_storage = '?boolean',
    vshard_group = '?string',
    zone = '?string',
    status = '?string',
}

-- @module topology

-- Forward declaration.
local mt

-- {{{ Module functions

--- Module functions.
--
-- @section Functions

--- Create a new topology.
--
-- @table conf_client
--     A configuration client object. See [Configuration storage module][1].
--     [1]: https://github.com/tarantool/conf/
-- @string name
--     A topology name.
-- @table[opt] autocommit
--     Enable mode of operation of a configuration storage connection. Each
--     individual configuration storage interaction submitted through the
--     configuration storage connection in autocommit mode will be executed in its own
--     transaction that is implicitly committed. Enabled by default.
-- @table[opt] opts
--     Topology options.
-- @boolean[opt] opts.is_bootstrapped
--     Set to true when cluster is bootstrapped. Some topology options
--     cannot be changed once cluster is bootstrapped. For example bucket_count.
-- @integer[opt] opts.bucket_count
--     Total bucket count in a cluster. It can not be changed after cluster bootstrap!
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-bucket_count
-- @integer[opt] opts.rebalancer_disbalance_threshold
--     Maximal bucket count that can be received in parallel by single replicaset.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_disbalance_threshold
-- @integer[opt] opts.rebalancer_max_receiving
--     The maximum number of buckets that can be received in parallel by a
--     single replica set. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_max_receiving
-- @integer[opt] opts.rebalancer_max_sending
--     The degree of parallelism for parallel rebalancing.
--     Works for storages only, ignored for routers.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-rebalancer_max_sending
-- @string[opt] opts.discovery_mode
--     A mode of a bucket discovery fiber: on/off/once.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-discovery_mode
-- @integer[opt] opts.sync_timeout
--     Timeout to wait for synchronization of the old master with replicas
--     before demotion. Used when switching a master or when manually calling the
--     sync() function. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-sync_timeout
-- @boolean[opt] opts.collect_lua_garbage
--     If set to true, the Lua collectgarbage() function is called periodically.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-collect_lua_garbage
-- @integer[opt] opts.collect_bucket_garbage_interval
--     The interval between garbage collector actions, in seconds.
--     See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-collect_bucket_garbage_interval
-- @table[opt] opts.weights
--     A field defining the configuration of relative weights for each zone
--     pair in a replica set. See [Sharding Configuration reference][1] and
--     [Sharding Administration][2].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-weights
--     [2]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#vshard-replica-set-weights
-- @table[opt] opts.vshard_groups
--     List of supported vshard storage groups.
-- @string[opt] opts.shard_index
--     Name or id of a TREE index over the bucket id. See [Sharding Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-shard_index
-- @string[opt] opts.zone
--     Replica zone (see weighted routing in the section 'Replicas weight configuration').
--
-- @return topology object
--
-- @usage
--
-- local conf = require('conf')
-- local topology = require('topology')
--
-- local urls = {
--     'http://localhost:2380',
--     'http://localhost:2381',
--     'http://localhost:2382',
-- }
-- local conf_client = conf.new({ driver = 'etcd', endpoints = urls })
-- local t = topology.new(conf_client, 'topology_name')
--
-- @function topology.new
local function new(conf_client, topology_name, autocommit, opts)
    checks('table', 'string', '?boolean', '?table')
    local opts = opts or {}
    cfg_correctness.check_topology_opts(opts)
    local topology_cache = conf_client:get(topology_name).data
    if topology_cache == nil then
        topology_cache = {
            instance_map = {},
            options = opts,
            replicasets = {},
            weights = {},
        }
    end
    if autocommit then
        conf_client:set(topology_name, topology_cache)
    end

    return setmetatable({
        autocommit = autocommit,
        cache = topology_cache,
        client = conf_client,
        name = topology_name,
    }, mt)
end

--- Add a new Tarantool instance to a topology.
--
-- Add a new Tarantool instance to a topology.
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name to add. Name must be globally unique.
-- @string replicaset_name
--     Replicaset name. Name must be globally unique.
--     It will be created if it does not exist.
-- @table[opt] opts
--     instance options.
-- @table[opt] opts.box_cfg
--     Instance box.cfg options. box.cfg options should contain at least Uniform Resource Identifier
--     of remote instance with **required** login and password. See [Configuration parameters][1].
--     Note: instance uuid will be generated automatically.
--     See [Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#box-cfg-params
--     [2]: https://www.tarantool.io/en/doc/latest/reference/configuration/#confval-instance_uuid
-- @integer[opt] opts.distance
--     Distance value. See [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-weights
-- @string[opt] opts.advertise_uri
--     URI that will be used by clients to connect to this instance.
--     A "URI" is a "Uniform Resource Identifier" and it's format is described in [Module uri][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_lua/uri/#uri-parse
-- @string[opt] opts.zone
--     Availability zone.
-- @string[opt] opts.status
--     Instance status, can be managed by:
--
--       - @{topology.new_instance|self.new_instance()} set to status `reachable` by default
--       - @{topology.set_instance_reachable|self.set_instance_reachable()} set to status `reachable`
--       - @{topology.set_instance_unreachable|self.set_instance_unreachable()} set to status `unreachable`
--       - @{topology.set_instance_options|self.set_instance_options()}
--       - @{topology.delete_instance|self.delete_instance()} set to status `expelled`
-- @string[opt] opts.vshard_group
--     Name of vshard storage group. Instance that has a `vshard-storage`
--     role can belong to different vshard storage groups. For example,
--     `hot` or `cold` groups meant to independently process hot and cold data.
--     With multiple groups enabled, every replica set with a vshard-storage
--     role enabled must be assigned to a particular group. The assignment can never
--     be changed.
--     See more about vshard storage groups in [Tarantool Cartridge Developers Guide][1].
--     [1]: https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_dev/#using-multiple-vshard-storage-groups
-- @boolean[opt] opts.is_master
--     True if an instance is a master in replication cluster. See [Replication architecture][1].
--     You can define 0 or 1 masters for each replicaset. It accepts all write requests.
--     [1]: https://www.tarantool.io/en/doc/latest/book/replication/repl_architecture/
-- @boolean[opt] opts.is_storage
--     True if an instance is a storage. See [Sharding Architecture][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#structure
-- @boolean[opt] opts.is_router
--     True if an instance is a router. See [Sharding Architecture][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_architecture/#structure
--
-- @return None
--
-- @function instance.new_instance
local function new_instance(self, instance_name, replicaset_name, opts)
    checks('table', 'string', 'string', instance_opts_types)
    local opts = opts or {}
    cfg_correctness.check_instance_opts(opts)
    if opts.box_cfg == nil then
        opts.box_cfg = {}
    end
    if opts.advertise_uri ~= nil then
        cfg_correctness.check_uri(opts.advertise_uri)
    end
    if opts.box_cfg.listen ~= nil then
        cfg_correctness.check_uri(opts.box_cfg.listen)
    end
    opts.box_cfg.instance_uuid = uuid.str()

    opts.status = opts.status or 'reachable'

    -- One cannot set status 'expelled' directly.
    assert(opts.status ~= 'expelled')

    local topology_cache = rawget(self, 'cache')
    -- Add replicaset.
    local replicaset = topology_cache.replicasets[replicaset_name]
    if replicaset == nil or next(replicaset) == nil then
        self:new_replicaset(replicaset_name)
    end
    -- Add instance.
    local replicaset = topology_cache.replicasets[replicaset_name]
    local instance_opt = replicaset.replicas[instance_name]
    if instance_opt ~= nil then
        log.error('instance with name "%s" already exists in replicaset "%s"',
                  instance_name, replicaset_name)
        return
    end
    topology_cache.replicasets[replicaset_name].replicas[instance_name] = opts
    -- Add new instance to map 'instance - replicaset'
    topology_cache.instance_map[instance_name] = replicaset_name
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
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
--     Topology object.
-- @string replicaset_name
--     Name of replicaset to add. Name must be globally unique.
-- @table[opt] opts
--     replicaset options.
-- @string[opt] opts.master_mode
--     Mode that describes how master instance should be assigned.
--     Possible values:
--
--       - single - it is allowed to have only a single master in replication
--         cluster that should me assigned manually.
--
--       - multimaster - it is allowed to have several instances with master role
--         in a replication cluster, all of them should be assigned manually.
--
--       - auto - master role will be assigned automatically. Auto mode
--         requires specifying advisory roles (leader, follower, or candidate)
--         in Tarantool instance options (`box.cfg`). See [Submodule box.info][1].
--
-- [1]: https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_info/election/
--
-- @array[opt] opts.failover_priority
--     Table with names specifying Tarantool instances failover priorities.
-- @array[opt] opts.weight
--     The weight of a replica set defines the capacity of the replica set:
--     the larger the weight, the more buckets the replica set can store.
--     The total size of all sharded spaces in the replica set is also its capacity metric.
--     See [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-set-weights
--
-- @return None
--
-- @function instance.new_replicaset
local function new_replicaset(self, replicaset_name, opts)
    checks('table', 'string', replicaset_opts_types)
    local opts = opts or {
        failover_priority = {},
    }
    -- TODO: check existance of every instance passed in failover_priority
    cfg_correctness.check_replicaset_opts(opts)
    opts.cluster_uuid = uuid.str()
    assert(opts.cluster_uuid ~= nil)
    local topology_cache = rawget(self, 'cache')
    if topology_cache.replicasets[replicaset_name] ~= nil then
        log.error('replicaset with name "%s" already exists', replicaset_name)
        return
    end
    topology_cache.replicasets[replicaset_name] = {
        options = opts,
        replicas = {},
    }
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Delete instance from a topology.
--
-- Deletes an instance. Deleted instance still exists in a topology,
-- but has a status `expelled` and it cannot be used anymore.
--
-- @param self
--     Topology object.
-- @string instance_name
--     Name of an instance to delete.
--
-- @return None
--
-- @function instance.delete_instance
local function delete_instance(self, instance_name)
    checks('table', 'string')
    local topology_cache = rawget(self, 'cache')
    -- Find replicaset name.
    local replicaset_name = topology_cache.instance_map[instance_name]
    if  replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
        return
    end
    local instance = topology_cache.replicasets[replicaset_name].replicas[instance_name]
    if instance == nil then
        log.error('instance "%s" not found', instance_name)
	return
    end
    -- Remove instance.
    topology_cache.replicasets[replicaset_name].replicas[instance_name] =
        { status = 'expelled' }
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Delete a replicaset.
--
-- Deletes replicaset from a topology.
--
-- @param self
--     Topology object.
-- @string replicaset_name
--     Name of a replicaset to delete.
--
-- @return None
--
-- @function instance.delete_replicaset
local function delete_replicaset(self, replicaset_name)
    checks('table', 'string')
    local topology_cache = rawget(self, 'cache')
    -- TODO: Probably it should't be possible to remove a replicaset
    -- with existed instances.
    topology_cache.replicasets[replicaset_name] = nil
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Set parameters of existed Tarantool instance.
--
-- Set parameters of existed Tarantool instance.
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name.
-- @table opts
--     @{topology.new_instance|Instance options}.
--
-- @return None
--
-- @function instance.set_instance_options
local function set_instance_options(self, instance_name, opts)
    checks('table', 'string', instance_opts_types)
    local opts = opts or {}
    cfg_correctness.check_instance_opts(opts)
    if opts.advertise_uri ~= nil then
	cfg_correctness.check_uri(opts.advertise_uri)
    end
    if opts.box_cfg ~= nil and opts.box_cfg.listen ~= nil then
	cfg_correctness.check_uri(opts.box_cfg.listen)
    end
    local topology_cache = rawget(self, 'cache')

    -- One cannot set status 'expelled' directly.
    assert(opts.status ~= 'expelled')

    -- Find replicaset name.
    local replicaset_name = topology_cache.instance_map[instance_name]
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
        return
    end
    local instance = topology_cache.replicasets[replicaset_name].replicas[instance_name]
    if instance == nil then
        log.error('instance "%s" not found', instance_name)
        return
    end

    if instance.status == 'expelled' then
        log.error('instance "%s" is expelled', instance_name)
        return
    end

    -- Merge options.
    for k, v in pairs(opts) do
        instance[k] = v
    end

    topology_cache.replicasets[replicaset_name].replicas[instance_name] = instance
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Set parameters of an existed replicaset in a topology.
--
-- Set parameters of a replicaset in a topology.
--
-- @param self
--     Topology object.
-- @string replicaset_name
--     Replicaset name.
-- @table opts
--     See description of options in @{topology.new_replicaset|Replicaset options}.
--
-- @return None
--
-- @function instance.set_replicaset_options
local function set_replicaset_options(self, replicaset_name, opts)
    checks('table', 'string', replicaset_opts_types)
    local opts = opts or {
	failover_priority = {},
    }
    cfg_correctness.check_replicaset_opts(opts)
    local topology_cache = rawget(self, 'cache')
    local replicaset = topology_cache.replicasets[replicaset_name]
    if replicaset == nil then
        log.error('replicaset "%s" not found', replicaset_name)
        return
    end

    -- Merge options
    local replicaset_opts = replicaset.options
    for k, v in pairs(opts) do
        replicaset_opts[k] = v
    end
    topology_cache.replicasets[replicaset_name] = { options = replicaset_opts }
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Switch state of Tarantool instance to a reachable.
--
-- Make instance available for clients. It participate
-- in replication and can serve requests.
--
-- XXX: add instance to box.replication
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name.
--
-- @return None
--
-- @function instance.set_instance_reachable
local function set_instance_reachable(self, instance_name)
    checks('table', 'string')
    self.set_instance_options(self, instance_name,
                              { status = 'reachable' })
end

--- Switch state of Tarantool instance to a unreachable.
--
-- Make instance unavailable for clients. It cannot participate
-- in replication, it cannot serve requests.
--
-- XXX: remove instance from box.replication
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name.
--
-- @return None
--
-- @function instance.set_instance_unreachable
local function set_instance_unreachable(self, instance_name)
    checks('table', 'string')
    self.set_instance_options(self, instance_name,
                              { status = 'unreachable' })
end

--- Set topology options.
--
-- Set topology options.
--
-- @param self
--     Topology object.
-- @table opts
--     @{topology.new|Topology options}.
--
-- @return None
--
-- @function instance.set_topology_options
local function set_topology_options(self, opts)
    checks('table', topology_opts_types)
    local opts = opts or {}
    cfg_correctness.check_topology_opts(opts)
    local topology_cache = rawget(self, 'cache')
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
        if k == 'shard_index' and is_bootstrapped then
            log.warn('cluster is bootstrapped, it is not allowed to change option shard_index')
        end
        ]]
        topology_cache.options[k] = v
    end
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Get routers.
--
-- Get a table with routers in a topology.
--
-- @param self
--     Topology object.
--
-- @return Lua table with names of instances that have router role.
--
-- Example of response:
--
-- ```
-- {
--   "router-1",
--   "router-2"
-- }
-- ```
--
-- @function instance.get_routers
local function get_routers(self)
    checks('table')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local replicasets_path = string.format('%s.replicasets', topology_name)
    local replicasets = client:get(replicasets_path).data
    local routers = {}
    if replicasets == nil or next(replicasets) == nil then
        table.sort(routers)
        return routers
    end
    for _, replicaset_opts in pairs(replicasets) do
        local replicas = replicaset_opts.replicas or {}
        if next(replicas) ~= nil then
            for instance_name, instance_opts in pairs(replicas) do
                if instance_opts.is_router then
                    table.insert(routers, instance_name)
                end
            end
        end
    end

    table.sort(routers)
    return routers
end

--- Get storages.
--
-- Get a table with storages in a topology.
--
-- @param self
--     Topology object.
-- @string[opt] vshard_group
--     Name of vshard storage group. See more about vshard storage groups in
--     [Tarantool Cartridge Developers Guide][1].
--     [1]: https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_dev/#using-multiple-vshard-storage-groups
--
-- @return Lua table with names of instances that have storage role.
--
-- Example of response:
--
-- ```
-- {
--   "storage-1",
--   "storage-2"
-- }
-- ```
--
-- @function instance.get_storages
local function get_storages(self, vshard_group)
    checks('table', '?string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local replicasets_path = string.format('%s.replicasets', topology_name)
    local replicasets = client:get(replicasets_path).data
    local storages = {}
    if replicasets == nil or next(replicasets) == nil then
        return storages
    end
    for _, replicaset_opts in pairs(replicasets) do
        if vshard_group == nil or
           replicaset_opts.vshard_group == vshard_group then
            local replicas = replicaset_opts.replicas or {}
            if next(replicas) ~= nil then
                for instance_name, instance_opts in pairs(replicas) do
                    if instance_opts.is_storage then
                        table.insert(storages, instance_name)
                    end
                end
            end
        end
    end

    table.sort(storages)
    return storages
end

--- Get instance options.
--
-- Get instance options.
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name.
--
-- @return Lua table with instance options described in @{instance.new_instance|Create a new instance}.
-- and key `box_cfg` with table that contains [Tarantool configuration parameters][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#box-cfg-params
--
-- Example of response:
--
-- ```
-- {
--   box_cfg = {
--     feedback_enabled = true,
--     memtx_memory = 268435456,
--     instance_uuid = "79a116a2-a88a-4e6c-9f83-9621127e9aeb",
--     read_only = true,
--     replicaset_uuid = "2ad6d727-1b19-4241-bde7-301f15575f69",
--     replication = {},
--     replication_sync_timeout = 6,
--     wal_mode = "write"
--   },
--   is_master = false,
--   is_storage = true
-- }
-- ```
--
-- @function instance.get_instance_options
local function get_instance_options(self, instance_name)
    checks('table', 'string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')

    -- Find replicaset name.
    local instance_map_path = string.format('%s.instance_map.%s', topology_name, instance_name)
    local replicaset_name = client:get(instance_map_path).data
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
        return
    end
    -- Get replicaset.
    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        log.error('replicaset "%s" not found', replicaset_name)
        return
    end
    -- Get instance.
    local instance_path = string.format('%s.replicas.%s', replicaset_path, instance_name)
    local instance_opts = client:get(instance_path).data
    if instance_opts == nil then
        log.error('instance "%s" not found', instance_name)
        return
    end
    if instance_opts.status == 'expelled' then
        log.error('instance "%s" is expelled', instance_name)
        return
    end

    instance_opts.box_cfg['read_only'] = not instance_opts.is_master == true
    instance_opts.box_cfg['replicaset_uuid'] = replicaset.options.cluster_uuid
    instance_opts.box_cfg['replication'] = {}
    -- build replication table in box.cfg
    for _, replica in pairs(replicaset.replicas) do
        -- TODO: take into account links between instances and master_mode in replicaset
        if replica.advertise_uri ~= nil then
            table.insert(instance_opts.box_cfg['replication'], replica.advertise_uri)
        end
    end
    -- TODO: merge with topology-specific and replicaset-specific box.cfg options

    table.sort(instance_opts)
    return instance_opts
end

--- Get replicaset options.
--
-- Get replicaset options.
--
-- @param self
--     Topology object.
-- @string replicaset_name
--     Replicaset name.
--
-- @return Lua table where keys are replicaset options,
-- see @{topology.new_replicaset|Replicaset options} and `replicas`
-- with names of instances added to that replicaset.
--
-- Example of response:
--
-- ```
-- {
--   cluster_uuid = "2bff7d87-697f-42f5-b7c7-33f40a8db1ea",
--   master_mode = "auto",
--   replicas = { "instance-name-1", "instance_name-2", "instance_name-3" }
-- }
-- ```
--
-- @function instance.get_replicaset_options
local function get_replicaset_options(self, replicaset_name)
    checks('table', 'string')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local replicaset_path = string.format('%s.replicasets.%s', topology_name, replicaset_name)
    local replicaset = client:get(replicaset_path).data
    if replicaset == nil then
        log.error('replicaset "%s" not found', replicaset_name)
        return
    end

    -- Add a table with instance names to response.
    if type(replicaset.options) ~= 'table' or replicaset.options == nil then
        replicaset.options = {}
    end
    local response = replicaset.options
    response.replicas = {}
    if replicaset.replicas == nil then
        table.sort(response)
        return response
    end
    for instance_name in pairs(replicaset.replicas) do
        table.insert(response.replicas, instance_name)
    end

    table.sort(response)
    return response
end

--- Get topology options.
--
-- Get topology options.
--
-- @param self
--     Topology object.
--
-- @return Lua table where keys are topology options,
--         see @{topology.new|Create a new topology}, and `replicasets`
--         with names of replicasets added to topology..
--
-- Example of response:
--
-- ```
-- {
--   bucket_count = 3000,
--   collect_bucket_garbage_interval = 0.5,
--   collect_lua_garbage = false,
--   failover_ping_timeout = 5,
--   rebalancer_disbalance_threshold = 1,
--   rebalancer_max_receiving = 100,
--   rebalancer_max_sending = 1,
--   replicasets = { "replicaset_name-1", "replicaset_name-2" },
--   shard_index = "bucket_id",
--   sync_timeout = 1
-- }
-- ```
--
-- @function instance.get_topology_options
local function get_topology_options(self)
    checks('table')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local topology = client:get(topology_name).data
    if topology == nil then
        log.error('topology "%s" not found', topology_name)
        return
    end
    if type(topology.options) ~= 'table' or not topology.options then
        topology.options = {}
    end
    local response = topology.options

    -- Add a table with replicaset names to response.
    response.replicasets = {}
    if topology.replicasets == nil then
        table.sort(response)
        return response
    end
    for replicaset_name in pairs(topology.replicasets) do
        table.insert(response.replicasets, replicaset_name)
    end

    table.sort(response)
    return response
end

--- Get vshard configuration.
--
-- Method prepares a configuration suitable for vshard bootstrap.
-- See [Sharding quick start guide][1].
--     [1]: https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_dev/#using-multiple-vshard-storage-groups
--
-- @param self
--     Topology object.
-- @string[opt] vshard_group
--     Name of vshard storage group.
--     See more about vshard storage groups in [Tarantool Cartridge Developers Guide][1]
--     and [Ansible Cartridge Documentation][2].
--     [1]: https://github.com/tarantool/vshard/blob/master/vshard/replicaset.lua
--     [2]: https://github.com/tarantool/ansible-cartridge/blob/master/doc/topology.md
--
-- @return Returns a table whose format and possible parameters are defined
-- by vshard module and described in [Sharding quick start guide][1] and
-- description of basic parameters in [Sharding configuration reference][2].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_quick/
--     [2]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#vshard-config-reference
--
-- Example of response:
--
-- ```
-- {
--     memtx_memory = 100 * 1024 * 1024,
--     bucket_count = 10000,
--     rebalancer_disbalance_threshold = 10,
--     rebalancer_max_receiving = 100,
--     sharding = {
--         ['cbf06940-0790-498b-948d-042b62cf3d29'] = { -- replicaset #1
--             replicas = {
--                 ['8a274925-a26d-47fc-9e1b-af88ce939412'] = {
--                     uri = 'storage:storage@127.0.0.1:3301',
--                     name = 'storage_1_a',
--                     master = true
--                 },
--                 ['3de2e3e1-9ebe-4d0d-abb1-26d301b84633'] = {
--                     uri = 'storage:storage@127.0.0.1:3302',
--                     name = 'storage_1_b'
--                 }
--             },
--         }, -- replicaset #1
--         ['ac522f65-aa94-4134-9f64-51ee384f1a54'] = { -- replicaset #2
--             replicas = {
--                 ['1e02ae8a-afc0-4e91-ba34-843a356b8ed7'] = {
--                     uri = 'storage:storage@127.0.0.1:3303',
--                     name = 'storage_2_a',
--                     master = true
--                 },
--                 ['001688c3-66f8-4a31-8e19-036c17d489c2'] = {
--                     uri = 'storage:storage@127.0.0.1:3304',
--                     name = 'storage_2_b'
--                 }
--             },
--         }, -- replicaset #2
--     }, -- sharding
--     weights = ...
-- }
-- ```
--
-- @function instance.get_vshard_config
local function get_vshard_config(self, vshard_group)
    checks('table', '?string')
    local vshard_cfg = self:get_topology_options()
    if vshard_cfg == nil then
        return {}
    end
    local replicasets = vshard_cfg.replicasets
    -- note: options in cfg are passed to tarantool
    -- so it should not contain options unsupported by it
    vshard_cfg.replicasets = nil
    vshard_cfg['sharding'] = {}
    local master_uuid = nil
    for _, replicaset_name in pairs(replicasets) do
        local replicaset_options = self:get_replicaset_options(replicaset_name)
        local replicas = {}
        if next(replicaset_options.replicas) == nil then
            log.error('no replicas in replicaset "%s"', replicaset_name)
            return {}
        end
        for _, replica_name in pairs(replicaset_options.replicas) do
            local instance_opts = self:get_instance_options(replica_name)
            if vshard_group == nil or
               instance_opts.vshard_group == vshard_group then
                if not instance_opts.box_cfg.read_only then
                    master_uuid = instance_opts.box_cfg.instance_uuid
                    instance_opts.box_cfg.master = true
                end
                instance_opts.box_cfg.name = replica_name
                instance_opts.box_cfg.uri = instance_opts.advertise_uri
                replicas[instance_opts.box_cfg.instance_uuid] = instance_opts.box_cfg
            end
        end
        local cluster_uuid = replicaset_options.cluster_uuid
        vshard_cfg['sharding'][cluster_uuid] = {
            replicas = replicas,
            master = master_uuid
        }
    end

    -- TODO: set is_bootstrapped to true
    cfg_correctness.vshard_check(vshard_cfg)

    table.sort(vshard_cfg)
    return vshard_cfg
end

--- Add a new instance link.
--
-- Creates a link between instances.
--
-- XXX: Method is untested.
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instances names. Specified instances are downstreams.
-- @array instances
--     Tarantool instance names. These instances will be used
--     as upstream in replication by specified instance.
--
-- @return None
--
-- @function instance.new_instance_link
-- luacheck: ignore
local function new_instance_link(self, instance_name, instances)
    checks('table', 'string', 'table')
    -- TODO: check existance of replicaset and every passed instance
    local topology_cache = rawget(self, 'cache')
    -- Find replicaset name.
    local replicaset_name = topology_cache.instance_map[instance_name]
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
        return
    end
    -- Find instance.
    local instance = topology_cache.replicasets[replicaset_name].replicas[instance_name]
    if instance == nil then
        log.error('instance "%s" not found', instance_name)
	return
    end
    -- TODO: set links
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Delete an instance link.
--
-- Deletes a link between instances.
--
-- XXX: Method is untested.
--
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name.
-- @array instances
--     Tarantool instance names. These instances will not be used
--     as upstream in replication by specified instance.
--
-- @return None
--
-- @function instance.delete_instance_link
local function delete_instance_link(self, instance_name, instances)
    checks('table', 'string', 'table')
    -- TODO: check existance of replicaset and every passed instance
    local topology_cache = rawget(self, 'cache')
    -- Find replicaset name.
    local replicaset_name = topology_cache.instance_map[instance_name]
    if replicaset_name == nil then
        log.error('replicaset with instance "%s" not found', instance_name)
        return
    end
    local instance = topology_cache.replicasets[replicaset_name].replicas[instance_name]
    if instance == nil then
        log.error('instance "%s" not found', instance_name)
	return
    end
    -- TODO: delete links
    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Delete topology.
--
-- Deletes a topology.
--
-- @param self
--     Topology object.
--
-- @return None
--
-- @function topology_obj.delete
local function delete(self)
    checks('table')
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    client:del(topology_name)
    rawset(self, 'autocommit', nil)
    rawset(self, 'cache', nil)
    rawset(self, 'client', nil)
    rawset(self, 'topology_name', nil)
end

--- Send local changes to remote configuration storage.
--
-- Send topology changes made offline to remote configuration storage.
-- Method is applicable with disabled option `autocommit`, with enabled
-- `autocommit` option does nothing.
-- See @{topology.new|Create a new topology}.
--
-- @param self
--     Topology object.
--
-- @return None
--
-- @function topology_obj.commit
local function commit(self)
    checks('table')
    local client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = rawget(self, 'cache')
    -- TODO: check version and reject update if a value
    -- in configuration storage is newer than ours
    -- Requires support in a Configuration module API.
    client:set(topology_name, topology_cache)
end

mt = {
    __index = {
        commit = commit,

        new_instance = new_instance,
        new_instance_link = new_instance_link,
        new_replicaset = new_replicaset,

        delete = delete,
        delete_instance = delete_instance,
        delete_instance_link = delete_instance_link,
        delete_replicaset = delete_replicaset,

        set_instance_options = set_instance_options,
        set_instance_reachable = set_instance_reachable,
        set_instance_unreachable = set_instance_unreachable,
        set_replicaset_options = set_replicaset_options,
        set_topology_options = set_topology_options,

        get_routers = get_routers,
        get_storages = get_storages,
        get_instance_options = get_instance_options,
        get_replicaset_options = get_replicaset_options,
        get_topology_options = get_topology_options,

        get_vshard_config = get_vshard_config,
    }
}

-- }}} Instance methods

return {
    new = new,
}
