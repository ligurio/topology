--- topology module
-- @module topology.topology

local fiber = require('fiber')
local consts = require('topology.client.consts')
local fun = require('fun')
local checks = require('checks')
local log = require('log')
local uuid = require('uuid')
local cfg_correctness = require('topology.client.cfg_correctness')

local function has_value(t, value)
    for _, v in ipairs(t) do
        if value == v then
            return true
        end
    end
    return false
end

--
-- Internal structure of topology:
--
-- topology_cache = {
--     version = 0,
--     options = {}
--     vshard_groups = {
--         'default' = {
-- 	        bucket_count = 1000,
-- 	        collect_lua_garbage = boolean,
--         },
--         'tweedledum' = {
-- 	        bucket_count = 3000,
--         },
--         'tweedledee' = {
-- 	        bucket_count = 500,
--         },
--     },
--     replicasets = {
--         ['replicaset_name-1'] = {
--             replicas = {'instance_1_name', 'instance_2_name'},
--             cluster_uuid = '',
--         },
--         ['replicaset_name-2'] = {
--         },
--     },
--     instances = {
--         ['instance_name-1'] = {
--             replicaset = 'replicaset_name-1',
--             is_master = true,
--             is_storage = true,
--             box_cfg = {},
--         },
--         ['instance_name-2'] = {
--             replicaset = 'replicaset_name-1',
--             is_router = true,
--             box_cfg = {},
--         },
--     },
--     zone_distances = {
--     },
--     failover = nil | boolean | {
--          mode = 'disabled' | 'eventual' | 'stateful',
--          state_provider = nil | 'tarantool' | 'etcd2',
--          failover_timeout = nil | number,
--          tarantool_params = nil | {
--              uri = string,
--              password = string,
--          },
--          etcd2_params = nil | {
--              prefix = nil | string,
--              lock_delay = nil | number,
--              endpoints = nil | {string, ...},
--              username = nil | string,
--              password = nil | string,
--          },
--          fencing_enabled = nil | boolean,
--          fencing_timeout = nil | number,
--          fencing_pause = nil | number,
--     },
-- }

local topology_opts_types = {
    failover = '?table',
    vshard_groups = '?table',
    zone_distances = '?table',
}

local replicaset_opts_types = {
    master_mode = '?string',
    failover_priority = '?table',
    weight = '?number',
}

local instance_opts_types = {
    advertise_uri = '?string',
    box_cfg = '?table',
    is_master = '?boolean',
    is_router = '?boolean',
    is_storage = '?boolean',
    vshard_groups = '?table',
    zone = '?string|number',
    status = '?string',
    replicaset = '?string',
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
--     [1]: https://tarantool.github.io/conf/
-- @string name
--     A topology name.
-- @table[opt] autocommit
--     Enable mode of operation of a configuration storage connection. Each
--     individual configuration storage interaction submitted through the
--     configuration storage connection in autocommit mode will be executed in its own
--     transaction that is implicitly committed. Enabled by default.
-- @table[opt] opts
--     Topology options.
-- @table[opt] opts.vshard_groups
--     Parameters of vshard storage groups. Instance that has a `vshard-storage`
--     role can belong to different vshard storage groups. For example,
--     `hot` or `cold` groups meant to independently process hot and cold data.
--     With multiple groups enabled, every replica set with a vshard-storage
--     role enabled must be assigned to a particular group. The assignment can never
--     be changed. By default there is a single vshard group 'default' and by default
--     instances without vshard group belongs to the 'default' group.
--     Every vshard group contains sharding parameters specific for this group.
--     See more about vshard storage groups in [Tarantool Cartridge Developers Guide][1].
--     Sharding group may contain sharding configuration parameters described in
--     [Sharding Configuration reference][2].
--     [1]: https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_dev/#using-multiple-vshard-storage-groups
--     [2]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/
--
--
--     - `bucket_count` - Total bucket count in a cluster. It can not be changed
--     after cluster bootstrap!
--
--     - `rebalancer_disbalance_threshold` - Maximal bucket count that can be
--     received in parallel by single replicaset.
--
--     - `rebalancer_max_receiving` - The maximum number of buckets that can be
--     received in parallel by a single replica set.
--
--     - `rebalancer_max_sending` - The degree of parallelism for parallel rebalancing.
--     Works for storages only, ignored for routers.
--
--
--     - `discovery_mode` - A mode of a bucket discovery fiber: on/off/once.
--
--     - `sync_timeout` - Timeout to wait for synchronization of the old
--     master with replicas before demotion. Used when switching a master
--     or when manually calling the `sync()` function.
--
--     - `collect_lua_garbage` - If set to true, the Lua `collectgarbage()`
--     function is called periodically.
--
--     - `collect_bucket_garbage_interval` - The interval between garbage
--     collector actions, in seconds.
--
--     - `shard_index` - Name or id of a TREE index over the bucket id.
--
-- @table[opt] opts.zone_distances
--     A field defining the configuration of relative distances for each zone
--     pair in a replica set. See [Sharding Configuration reference][1] and
--     [Sharding Administration][2].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_ref/#confval-weights
--     [2]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#vshard-replica-set-weights
--
-- @table[opt] opts.failover
--     TBD
--     See more about failover configuration in [Tarantool Cartridge Developers Guide][1].
--     [1]: https://www.tarantool.io/en/doc/latest/book/cartridge/cartridge_dev/#failover-architecture
--
--  XXX: `failover` option is untested.
--
-- @return topology object
--
-- @usage
--
-- local conf_lib = require('conf')
-- local topology_lib = require('topology')
--
-- local urls = {
--     'http://localhost:2380',
--     'http://localhost:2381',
--     'http://localhost:2382',
-- }
-- local conf_client = conf_lib.new({ driver = 'etcd', endpoints = urls })
-- local t = topology_lib.new(conf_client, 'tweedledum')
--
-- @function topology.new
local function new(conf_client, topology_name, autocommit, opts)
    checks('table', 'string', '?boolean', topology_opts_types)
    local opts = opts or {}
    if autocommit == nil then
        autocommit = true
    end
    cfg_correctness.check_topology_opts(opts)
    local topology_cache = conf_client:get(topology_name).data
    if topology_cache == nil then
        topology_cache = {
            version = 0,
            options = opts,
            replicasets = {}, -- {['replicaset_name'] = {}}
            instances = {}, -- {['instance_name'] = {}}
            zone_distances = {},
            vshard_groups = {
                ['default'] = {
		    bucket_count = consts.DEFAULT_BUCKET_COUNT,
		    collect_bucket_garbage_interval = consts.DEFAULT_COLLECT_BUCKET_GARBAGE_INTERVAL,
		    rebalancer_max_receiving = consts.DEFAULT_REBALANCER_MAX_RECEIVING,
		    rebalancer_disbalance_threshold = consts.DEFAULT_REBALANCER_DISBALANCE_THRESHOLD,
		    sync_timeout = consts.DEFAULT_SYNC_TIMEOUT,
                }
            },
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
-- @table[opt] opts
--     instance options.
-- @string[opt] replicaset_name
--     Replicaset name. Name must be globally unique.
--     It will be created if it does not exist.
-- @table[opt] opts.box_cfg
--     Instance box.cfg options. box.cfg options should contain at least Uniform Resource Identifier
--     of remote instance with **required** login and password. See [Configuration parameters][1].
--     Note: instance uuid will be generated automatically.
--     See [Configuration reference][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#box-cfg-params
--     [2]: https://www.tarantool.io/en/doc/latest/reference/configuration/#confval-instance_uuid
-- @string[opt] opts.replicaset
--     Replicaset name.
-- @string[opt] opts.advertise_uri
--     URI that will be used by clients to connect to this instance.
--     A "URI" is a "Uniform Resource Identifier" and it's format is described in [Module uri][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_lua/uri/#uri-parse
-- @string[opt] opts.zone
--     The `router` sends all read-write requests to the master instance only.
--     Setting replica zones allows sending read-only requests not only to
--     the master instance, but to any available replica that is the ‘nearest’
--     to the router. Zone can be used, for example, to define the
--     physical distance between the router and each replica in each replica set.
--     In this case read requests are sent to the nearest replica (with the lowest distance).
--     Option used in a table `zone_distances` in @{topology.new|Create a new topology}.
--     See more in [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-weights
-- @string[opt] opts.status
--     Instance status, can be managed by:
--
--       - @{topology.new_instance|self.new_instance()} set to status `reachable` by default
--       - @{topology.set_instance_reachable|self.set_instance_reachable()} set to status `reachable`
--       - @{topology.set_instance_unreachable|self.set_instance_unreachable()} set to status `unreachable`
--       - @{topology.set_instance_options|self.set_instance_options()} set to status `reachable` or `unreachable`
--       - @{topology.delete_instance|self.delete_instance()} set to status `expelled`
-- @table[opt] opts.vshard_groups
--     Names of vshard storage groups. Instance that has a `vshard-storage`
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
local function new_instance(self, instance_name, opts)
    checks('TopologyConfig', 'string', instance_opts_types)
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
    if opts.status == 'expelled' then
        log.error('use delete_instance() to delete instance')
        return
    end
    opts.status = opts.status or 'reachable'
    opts.vshard_groups = opts.vshard_groups or {'default'}

    -- Make sure no conflicts in box.cfg.read_only and is_master.
    if opts.box_cfg.read_only ~= nil and
       opts.is_master ~= nil then
        assert(not opts.box_cfg.read_only == opts.is_master)
    end

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    -- Add replicaset.
    if opts.replicaset ~= nil and
       topology_cache.replicasets[opts.replicaset] == nil then
        self:new_replicaset(opts.replicaset)
    end

    -- Pull changes
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    if topology_cache.instances[instance_name] ~= nil then
        log.error('instance with name "%s" already exists "%s"', instance_name)
        return
    end
    topology_cache.instances[instance_name] = opts

    rawset(self, 'cache', topology_cache)
    if rawget(self, 'autocommit') then
        self:commit()
    end
end

--- Add new replicaset to a topology.
--
-- Adds a new replicaset to a topology.
--
-- Note: replication cluster UUID will be generated automatically.
-- See [Configuration reference][1]. By default used replication topology
-- is fullmesh. However custom replication topology (see [Replication architecture][2])
-- can be made using methods @{instance.new_instance_link|Create a new instance link} and
-- @{instance.delete_instance_link|Delete an instance link}.
-- [1]: https://www.tarantool.io/en/doc/latest/reference/configuration/#confval-replicaset_uuid
-- [2]: https://www.tarantool.io/en/doc/latest/book/replication/repl_architecture/#replication-topologies-cascade-ring-and-full-mesh
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
--         requires specifying advisory roles (`leader`, `follower`, or `candidate`)
--         in Tarantool instance options (`box.cfg`). See [box.info.election][1].
--
-- [1]: https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_info/election/
--
-- XXX: `master_mode` option is untested.
--
-- @array[opt] opts.failover_priority
--     Table with instance names specifying servers failover priority.
--
-- XXX: `failover_priority` option is untested.
--
-- @array[opt] opts.weight
--     The weight of a replica set defines the capacity of the replica set:
--     the larger the weight, the more buckets the replica set can store.
--     The total size of all sharded spaces in the replica set is also its capacity metric.
--     By default, all weights of all replicasets are equal.
--     See [Sharding Administration][1].
--     [1]: https://www.tarantool.io/en/doc/latest/reference/reference_rock/vshard/vshard_admin/#replica-set-weights
--
-- @return None
--
-- @function instance.new_replicaset
local function new_replicaset(self, replicaset_name, opts)
    checks('TopologyConfig', 'string', replicaset_opts_types)
    -- TODO: check existance of every instance passed in failover_priority
    opts = opts or {
        failover_priority = {},
    }
    cfg_correctness.check_replicaset_opts(opts)
    opts.cluster_uuid = uuid.str()

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    if topology_cache.replicasets[replicaset_name] ~= nil then
        log.error('replicaset with name "%s" already exists', replicaset_name)
        return
    end
    topology_cache.replicasets[replicaset_name] = opts

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
    checks('TopologyConfig', 'string')

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    if topology_cache.instances[instance_name] == nil then
        log.error('instance "%s" not found', instance_name)
	return
    end
    -- Remove instance.
    topology_cache.instances[instance_name] = { status = 'expelled' }

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
    checks('TopologyConfig', 'string')

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    for _, instance_opts in pairs(topology_cache.instances) do
        if instance_opts.replicaset == replicaset_name then
            log.error('replicaset "%s" has more than zero replicas', replicaset_name)
	    return
        end
    end
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
    checks('TopologyConfig', 'string', instance_opts_types)
    local opts = opts or {}
    cfg_correctness.check_instance_opts(opts)
    if opts.status == 'expelled' then
        log.error('instance "%s" is expelled', instance_name)
        return
    end
    if opts.advertise_uri ~= nil then
	cfg_correctness.check_uri(opts.advertise_uri)
    end
    if opts.box_cfg ~= nil and opts.box_cfg.listen ~= nil then
	cfg_correctness.check_uri(opts.box_cfg.listen)
    end

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    local instance_opts = topology_cache.instances[instance_name]
    if instance_opts == nil then
        log.error('instance "%s" not found', instance_name)
	return
    end
    if instance_opts.status == 'expelled' then
        log.error('instance "%s" is expelled', instance_name)
        return
    end

    -- Merge options.
    for k, v in pairs(opts) do
        instance_opts[k] = v
    end

    topology_cache.instances[instance_name] = instance_opts
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
    checks('TopologyConfig', 'string', replicaset_opts_types)
    local opts = opts or {
	failover_priority = {},
    }
    cfg_correctness.check_replicaset_opts(opts)

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    local replicaset_opts = topology_cache.replicasets[replicaset_name]
    if replicaset_opts == nil then
        log.error('replicaset "%s" not found', replicaset_name)
        return
    end

    -- Merge options
    for k, v in pairs(opts) do
        replicaset_opts[k] = v
    end
    topology_cache.replicasets[replicaset_name] = replicaset_opts
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
-- @param self
--     Topology object.
-- @string instance_name
--     Tarantool instance name.
--
-- @return None
--
-- @function instance.set_instance_reachable
local function set_instance_reachable(self, instance_name)
    checks('TopologyConfig', 'string')
    self.set_instance_options(self, instance_name, {
        status = 'reachable',
    })
end

--- Switch state of Tarantool instance to a unreachable.
--
-- Make instance unavailable for clients. It cannot participate
-- in replication, it cannot serve requests.
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
    checks('TopologyConfig', 'string')
    self.set_instance_options(self, instance_name, {
        status = 'unreachable',
    })
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
    checks('TopologyConfig', topology_opts_types)
    local opts = opts or {}
    cfg_correctness.check_topology_opts(opts)

    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    -- Merge options
    for k, v in pairs(opts) do
        -- TODO: Forbid to change static parameters
        -- when sharding bootstrapped.
        if k ~= 'vshard_groups' and k ~= 'failover' then
            topology_cache.options[k] = v
        end
    end
    if opts.vshard_groups ~= nil then
        for vshard_group_name, vshard_group_opts in pairs(opts.vshard_groups) do
            topology_cache.vshard_groups[vshard_group_name] = vshard_group_opts
        end
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
-- @return Table with pairs 'instance_name' and 'instance options' for
--         instances with router role.
--
-- Example of response:
--
-- ```
-- {
--   "router-1" = {
--        is_router = true,
--        ...
--   },
--   "router-2" = {
--        is_router = true,
--        ...
--   },
-- }
-- ```
--
-- @function instance.get_routers
local function get_routers(self)
    checks('TopologyConfig')

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data

    local routers = {}
    if topology_cache == nil or next(topology_cache.instances) == nil then
        return routers
    end
    local function fn_is_router(_, opts)
        return opts.is_router == true
    end
    for _, name, _ in fun.filter(fn_is_router, topology_cache.instances) do
        table.insert(routers, name)
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
--   "storage-1" = {
--        is_storage = true,
--        ...
--   },
--   "storage-2" = {
--        is_storage = true,
--        ...
--   },
-- }
-- ```
--
-- @function instance.get_storages
local function get_storages(self, vshard_group)
    checks('TopologyConfig', '?string')
    vshard_group = vshard_group or 'default'

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data

    local storages = {}
    if topology_cache == nil or next(topology_cache.instances) == nil then
        return storages
    end
    local function fn_is_storage(_, opts)
        return opts.is_storage == true
    end
    for _, name, instance_opts in fun.filter(fn_is_storage, topology_cache.instances) do
        if has_value(instance_opts.vshard_groups, vshard_group) then
            table.insert(storages, name)
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
    checks('TopologyConfig', 'string')

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data

    -- Get instance options.
    if topology_cache == nil then
        return nil
    end
    local instance_opts = topology_cache.instances[instance_name]
    if instance_opts == nil then
        log.error('instance "%s" not found', instance_name)
        return
    end
    local replicaset_name = instance_opts.replicaset
    if replicaset_name == nil then
        table.sort(instance_opts)
        return instance_opts
    end
    instance_opts.box_cfg['read_only'] = not instance_opts.is_master == true
    instance_opts.box_cfg['replicaset_uuid'] = topology_cache.replicasets[replicaset_name].cluster_uuid
    instance_opts.box_cfg['replication'] = {}
    -- build replication table in box.cfg
    local replicaset_opts = self:get_replicaset_options(replicaset_name)
    for _, replica_name in pairs(replicaset_opts.replicas) do
        -- TODO: take into account links between instances and master_mode in replicaset
        local replica_opts = topology_cache.instances[replica_name]
        if replica_opts.advertise_uri ~= nil and
           replica_opts.status == 'reachable' then
            table.insert(instance_opts.box_cfg['replication'], replica_opts.advertise_uri)
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
-- @return Table where keys are replicaset options,
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
    checks('TopologyConfig', 'string')

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data

    if topology_cache == nil then
        return nil
    end
    local replicaset_opts = topology_cache.replicasets[replicaset_name]
    if replicaset_opts == nil then
        log.error('replicaset "%s" not found', replicaset_name)
        return
    end

    -- Add a table with replicas names.
    replicaset_opts.replicas = {}
    for instance_name, instance_opts in pairs(topology_cache.instances) do
        if instance_opts.status ~= 'expelled' then
            table.insert(replicaset_opts.replicas, instance_name)
        end
    end

    table.sort(replicaset_opts)
    return replicaset_opts
end

--- Get topology options.
--
-- Get topology options.
--
-- @param self
--     Topology object.
--
-- @return Table where keys are topology options,
--         see @{topology.new|Create a new topology}, and key `replicasets`
--         contains a table with names of replicasets added to topology.
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
    checks('TopologyConfig')

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data

    if topology_cache == nil then
         return nil
    end
    local response = topology_cache.options
    response.vshard_groups = topology_cache.vshard_groups

    -- Add a table with replicaset names to response.
    response.replicasets = {}
    for replicaset_name in pairs(topology_cache.replicasets) do
        table.insert(response.replicasets, replicaset_name)
    end

    table.sort(response)
    return response
end

--- Get vshard configuration.
--
-- Method prepares a configuration suitable for vshard bootstrap.
-- In sharding participates instances that belongs to specified vshard group
-- or group 'default' if it is not specified, has router role and has a
-- status 'reachable'.
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
    checks('TopologyConfig', '?string')
    local topology_opts = self:get_topology_options()
    vshard_group = vshard_group or 'default'
    if topology_opts == nil then
        return nil
    end
    local vshard_cfg = topology_opts.vshard_groups[vshard_group]
    if vshard_cfg == nil then
        log.error('vshard group "%s" not found', vshard_group)
        return
    end
    -- NOTE: options in cfg are passed to tarantool passthrough
    -- so it should contain only supported options.
    vshard_cfg['sharding'] = {}
    local master_uuid = nil
    for _, replicaset_name in pairs(topology_opts.replicasets) do
        local replicaset_opts = self:get_replicaset_options(replicaset_name)
        local replicas = {}
        if next(replicaset_opts.replicas) == nil then
            log.error('no replicas in replicaset "%s"', replicaset_name)
            return {}
        end
        for _, replica_name in pairs(replicaset_opts.replicas) do
            local instance_opts = self:get_instance_options(replica_name)
            if ((instance_opts.is_storage and
                has_value(instance_opts.vshard_groups, vshard_group)) or
               instance_opts.is_router) and
               instance_opts.status == 'reachable' then
                if not instance_opts.box_cfg.read_only then
                    master_uuid = instance_opts.box_cfg.instance_uuid
                    instance_opts.box_cfg.master = true
                end
                instance_opts.box_cfg.name = replica_name
                instance_opts.box_cfg.uri = instance_opts.advertise_uri
                replicas[instance_opts.box_cfg.instance_uuid] = instance_opts.box_cfg
            end
        end
        local cluster_uuid = replicaset_opts.cluster_uuid
        vshard_cfg['sharding'][cluster_uuid] = {
            replicas = replicas,
            master = master_uuid
        }
    end

    vshard_cfg.weights = vshard_cfg.zone_distances
    vshard_cfg.zone_distances = nil
    -- TODO: set is_bootstrapped to true

    cfg_correctness.vshard_check(vshard_cfg)

    table.sort(vshard_cfg)
    return vshard_cfg
end

--- Get instances iterator.
--
-- Method returns an iterator with pairs 'instance name' and its parameters.
-- Quite useful and powerful with library [luafun][1].
-- [1]: https://luafun.github.io/
--
-- @param self
--     Topology object.
--
-- @return Returns an iterator of pairs with instance name and its options.
--
-- @usage
--
-- local conf_lib = require('conf')
-- local topology_lib = require('topology')
-- local vshard = require('vshard')
--
-- local urls = {
--     'http://localhost:2380',
--     'http://localhost:2381',
--     'http://localhost:2382',
-- }
--
-- local conf_client = conf_lib.new({ driver = 'etcd', endpoints = urls })
-- local t = topology_lib.new(conf_client, 'tweedledum')
-- t:new_instance('tweedledum', {
--     is_router = true,
-- })
-- t:new_instance('tweedledee', {
--     is_storage = true,
-- })
-- t:get_instances_it():length()
-- 2
-- local predicate = function(name, opts)
--     return opts.is_storage == true
-- end
-- t:get_instances_it():remove_if(predicate) -- keep routers only
--
-- @function instance.get_instances_it
local function get_instances_it(self)
    checks('TopologyConfig')

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data
    if topology_cache == nil or next(topology_cache.instances) == nil then
        return nil
    end

    local function fn_get_instance_opts(instance_name, _)
        return self:get_instance_options(instance_name)
    end

    return fun.filter(fn_get_instance_opts, topology_cache.instances)
end

--- Get replicasets iterator.
--
-- Method returns a iterator with pairs 'replicaset name' and its parameters.
-- Quite useful and powerful with library [luafun][1].
-- [1]: https://luafun.github.io/
--
-- @param self
--     Topology object.
--
-- @return Returns a iterator of pairs with replicaset name and its options.
--
-- @function instance.get_replicasets_it
local function get_replicasets_it(self)
    checks('TopologyConfig')

    -- getters uses remote topology
    local conf_client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = conf_client:get(topology_name).data
    if topology_cache == nil or next(topology_cache.replicasets) == nil then
        return nil
    end

    local function fn_get_replicaset_opts(replicaset_name, _)
        return self:get_replicaset_options(replicaset_name)
    end

    return fun.filter(fn_get_replicaset_opts, topology_cache.replicasets)
end

--- Add a new instance link.
--
-- Creates a links between instances.
-- These links constitutes a replication topology.
--
-- XXX: Method is not ready.
--
-- @param self
--     Topology object.
-- @string upstream
--     Name of upstream instance.
-- @array downstreams
--     Table with names of downstream instances. These instances will be used
--     as downstreams of specified instance anymore.
--
-- @return None
--
-- @function instance.new_instance_link
local function new_instance_link(self, upstream, downstreams)
    checks('TopologyConfig', 'string', 'table')
    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end
    -- Make sure all downstreams exists.
    for instance_name in pairs(downstreams) do
        if topology_cache.instances[instance_name] == nil then
	    log.error('instance "%s" not found', instance_name)
	    return
        end
    end
    -- Make sure upstream exists.
    if topology_cache.instances[upstream] == nil then
        log.error('instance "%s" not found', upstream)
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
-- Deletes a links between instances.
-- These links constitutes a replication topology.
--
-- XXX: Method is not ready.
--
-- @param self
--     Topology object.
-- @string upstream
--     Name of upstream instance.
-- @array downstreams
--     Table with names of downstream instances. These instances will not be used
--     as downstreams of specified instance anymore.
--
-- @return None
--
-- @function instance.delete_instance_link
local function delete_instance_link(self, upstream, downstreams)
    checks('TopologyConfig', 'string', 'table')
    local topology_cache
    if rawget(self, 'autocommit') == true then
        local conf_client = rawget(self, 'client')
        local topology_name = rawget(self, 'name')
        topology_cache = conf_client:get(topology_name).data
    else
        topology_cache = rawget(self, 'cache')
    end

    -- Make sure all downstreams exists.
    for instance_name in pairs(downstreams) do
        if topology_cache.instances[instance_name] == nil then
	    log.error('instance "%s" not found', instance_name)
	    return
        end
    end
    -- Make sure upstream exists.
    if topology_cache.instances[upstream] == nil then
        log.error('instance "%s" not found', upstream)
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
    checks('TopologyConfig')
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
    checks('TopologyConfig')
    local client = rawget(self, 'client')
    local topology_name = rawget(self, 'name')
    local topology_cache = rawget(self, 'cache')
    topology_cache.version = topology_cache.version + 1
    -- TODO: check version and reject update if a value
    -- in configuration storage is newer than ours
    -- Requires support in a Configuration module API.
    client:set(topology_name, topology_cache)
end

--- Execute function on changes in remote topology.
--
-- Function polls remote configuration storage every `time interval`
-- for changes in topology and execute a `function callback` once
-- a change happen.
--
-- XXX: Method is untested.
-- XXX: See [autovshard implementation][1].
-- [1]: https://github.com/bofm/tarantool-autovshard/blob/master/autovshard/consul.lua#L192-L300
--
-- @param self
--     Topology object.
-- @string function_cb
--     Callback function that should be executed.
-- @number time_interval
--     Specify a poll interval in seconds. Default interval is 0.1 sec.
--
-- @return None
--
-- @usage
--
-- -- How to update vshard configuration continuously.
--
-- local conf_lib = require('conf')
-- local topology_lib = require('topology')
-- local vshard = require('vshard')
-- local fiber = require('fiber')
--
-- local urls = {
--     'http://localhost:2380',
--     'http://localhost:2381',
--     'http://localhost:2382',
-- }
--
-- local conf_client = conf_lib.new({ driver = 'etcd', endpoints = urls })
-- local t = topology_lib.new(conf_client, 'tweedledum')
--
-- -- on storage instance
-- local vshard_storage_cb = function()
--    local vshard_cfg = t:get_vshard_config()
--    vshard.router.cfg(vshard_cfg)
-- end
-- local instance_uuid = os.getenv('TARANTOOL_UUID')
-- local vshard_cfg = t:get_vshard_config()
-- vshard.storage.cfg(vshard_cfg, instance_uuid)
-- fiber.create(t:on_change, vshard_cfg_cb, 0.5)
--
-- -- on router instance
-- local vshard_router_cb = function()
--    local vshard_cfg = t:get_vshard_config()
--    vshard.router.cfg(vshard_cfg)
-- end
-- vshard.router.cfg(vshard_cfg)
-- vshard.router.bootstrap()
-- fiber.create(t:on_change, vshard_cfg_cb, 0.5)
--
-- @function topology_obj.on_change
local function on_change(self, function_cb, time_interval)
    checks('TopologyConfig', 'function', '?number')
    time_interval = time_interval or consts.DEFAULT_WAIT_INTERVAL
    local topology_name = rawget(self, 'name')
    local client = rawget(self, 'client')
    local topology = client:get(topology_name).data
    local current_v = topology.version
    while true do
        topology = client:get(topology_name).data
        if topology.version > current_v then
            -- TODO: use protected call and handle errors
            pcall(function_cb())
            current_v = topology.version
        end
        fiber.sleep(time_interval)
    end
end

mt = {
    __type = 'TopologyConfig',
    __newindex = function()
        error("TopologyConfig object is immutable", 2)
    end,
    __index = {
        commit = commit,
        on_change = on_change,

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

        get_instances_it = get_instances_it,
        get_replicasets_it = get_replicasets_it,
        get_routers = get_routers,
        get_storages = get_storages,
        get_instance_options = get_instance_options,
        get_replicaset_options = get_replicaset_options,
        get_topology_options = get_topology_options,
        get_vshard_config = get_vshard_config,
    },
}

-- }}} Instance methods

return {
    new = new,
}
