-- Based on validation performed by vshard
-- vshard/cfg.lua

local log = require('log')
local luri = require('uri')
local consts = require('topology.client.consts')

local function check_uri(uri)
    if not luri.parse(uri) then
        error('Invalid URI: ' .. uri)
    end
end

local function check_master(master, ctx)
    if master then
        if ctx.master then
            error('Only one master is allowed per replicaset')
        else
            ctx.master = master
        end
    end
end

local function is_number(v)
    return type(v) == 'number' and v == v
end

local function is_non_negative_number(v)
    return is_number(v) and v >= 0
end

local function is_positive_number(v)
    return is_number(v) and v > 0
end

local function is_non_negative_integer(v)
    return is_non_negative_number(v) and math.floor(v) == v
end

local function is_positive_integer(v)
    return is_positive_number(v) and math.floor(v) == v
end

local type_validate = {
    ['string'] = function(v) return type(v) == 'string' end,
    ['non-empty string'] = function(v)
        return type(v) == 'string' and #v > 0
    end,
    ['boolean'] = function(v) return type(v) == 'boolean' end,
    ['number'] = is_number,
    ['non-negative number'] = is_non_negative_number,
    ['positive number'] = is_positive_number,
    ['non-negative integer'] = is_non_negative_integer,
    ['positive integer'] = is_positive_integer,
    ['table'] = function(v) return type(v) == 'table' end,
}

local function validate_config(config, schema, check_arg)
    for key, schema_value in pairs(schema) do
        local value = config[key]
        local name = schema_value.name
        local expected_type = schema_value.type
        if value == nil then
            if not schema_value.is_optional then
                error(string.format('%s must be specified', name))
            else
                config[key] = schema_value.default
            end
        else
            if type(expected_type) == 'string' then
                if not type_validate[expected_type](value) then
                    error(string.format('%s must be %s', name, expected_type))
                end
                local max = schema_value.max
                if max and value > max then
                    error(string.format('%s must not be greater than %s', name,
                                        max))
                end
            else
                local is_valid_type_found = false
                for _, t in pairs(expected_type) do
                    if type_validate[t](value) then
                        is_valid_type_found = true
                        break
                    end
                end
                if not is_valid_type_found then
                    local types = table.concat(expected_type, ', ')
                    error(string.format('%s must be one of the following '..
                                        'types: %s', name, types))
                end
            end
            if schema_value.check then
                schema_value.check(value, check_arg)
            end
        end
    end
end

local vshard_replica_schema = {
    uri = {type = 'non-empty string', name = 'URI', check = check_uri},
    name = {type = 'string', name = "Name", is_optional = true},
    zone = {type = {'string', 'number'}, name = "Zone", is_optional = true},
    master = {
        type = 'boolean', name = "Master", is_optional = true, default = false,
        check = check_master
    },
}

local function check_replicas(replicas)
    local ctx = {master = false}
    for _, replica in pairs(replicas) do
        validate_config(replica, vshard_replica_schema, ctx)
    end
end

local vshard_replicaset_schema = {
    replicas = {type = 'table', name = 'Replicas', check = check_replicas},
    weight = {
        type = 'non-negative number', name = 'Weight', is_optional = true,
        default = 1,
    },
    lock = {type = 'boolean', name = 'Lock', is_optional = true},
}

--
-- Check weights map on correctness.
--
local function cfg_check_weights(weights)
    for zone1, v in pairs(weights) do
        if type(zone1) ~= 'number' and type(zone1) ~= 'string' then
            -- Zone1 can be not number or string, if an user made
            -- this: weights = {[{1}] = ...}. In such a case
            -- {1} is the unaccassible key of a lua table, which
            -- is available only via pairs.
            error('Zone identifier must be either string or number')
        end
        if type(v) ~= 'table' then
            error('Zone must be map of relative weights of other zones')
        end
        for zone2, weight in pairs(v) do
            if type(zone2) ~= 'number' and type(zone2) ~= 'string' then
                error('Zone identifier must be either string or number')
            end
            if type(weight) ~= 'number' or weight < 0 then
                error('Zone weight must be either nil or non-negative number')
            end
            if zone2 == zone1 and weight ~= 0 then
                error('Weight of own zone must be either nil or 0')
            end
        end
    end
end

local function check_sharding(sharding)
    local uuids = {}
    local uris = {}
    local names = {}
    local is_all_weights_zero = true
    for replicaset_uuid, replicaset in pairs(sharding) do
        if uuids[replicaset_uuid] then
            error(string.format('Duplicate uuid %s', replicaset_uuid))
        end
        uuids[replicaset_uuid] = true
        if type(replicaset) ~= 'table' then
            error('Replicaset must be a table')
        end
        local w = replicaset.weight
        if w == math.huge or w == -math.huge then
            error('Replicaset weight can not be Inf')
        end
        validate_config(replicaset, vshard_replicaset_schema)
        for replica_uuid, replica in pairs(replicaset.replicas) do
            if uris[replica.uri] then
                error(string.format('Duplicate uri %s', replica.uri))
            end
            uris[replica.uri] = true
            if uuids[replica_uuid] then
                error(string.format('Duplicate uuid %s', replica_uuid))
            end
            uuids[replica_uuid] = true
            -- Log warning in case replica.name duplicate is
            -- found. Message appears once for each unique
            -- duplicate.
            local name = replica.name
            if name then
                if names[name] == nil then
                    names[name] = 1
                elseif names[name] == 1 then
                    log.warn('Duplicate replica.name is found: %s', name)
                    -- Next duplicates should not be reported.
                    names[name] = 2
                end
            end
        end
        is_all_weights_zero = is_all_weights_zero and replicaset.weight == 0
    end
    if next(sharding) and is_all_weights_zero then
        error('At least one replicaset weight should be > 0')
    end
end

local vshard_cfg_schema = {
    sharding = {type = 'table', name = 'Sharding', check = check_sharding},
    weights = {
        type = 'table', name = 'Weight matrix', is_optional = true,
        check = cfg_check_weights
    },
    shard_index = {
        type = {'non-empty string', 'non-negative integer'},
        name = 'Shard index', is_optional = true, default = 'bucket_id',
    },
    zone = {
        type = {'string', 'number'}, name = 'Zone identifier',
        is_optional = true
    },
    bucket_count = {
        type = 'positive integer', name = 'Bucket count', is_optional = true,
        default = consts.DEFAULT_BUCKET_COUNT
    },
    rebalancer_disbalance_threshold = {
        type = 'non-negative number', name = 'Rebalancer disbalance threshold',
        is_optional = true,
        default = consts.DEFAULT_REBALANCER_DISBALANCE_THRESHOLD
    },
    rebalancer_max_receiving = {
        type = 'positive integer',
        name = 'Rebalancer max receiving bucket count', is_optional = true,
        default = consts.DEFAULT_REBALANCER_MAX_RECEIVING
    },
    rebalancer_max_sending = {
        type = 'positive integer',
        name = 'Rebalancer max sending bucket count',
        is_optional = true,
        default = consts.DEFAULT_REBALANCER_MAX_SENDING,
        max = consts.REBALANCER_MAX_SENDING_MAX
    },
    collect_bucket_garbage_interval = {
        type = 'positive number', name = 'Garbage bucket collect interval',
        is_optional = true,
        default = consts.DEFAULT_COLLECT_BUCKET_GARBAGE_INTERVAL
    },
    collect_lua_garbage = {
        type = 'boolean', name = 'Garbage Lua collect necessity',
        is_optional = true, default = false
    },
    sync_timeout = {
        type = 'non-negative number', name = 'Sync timeout', is_optional = true,
        default = consts.DEFAULT_SYNC_TIMEOUT
    },
    connection_outdate_delay = {
        type = 'non-negative number', name = 'Object outdate timeout',
        is_optional = true
    },
    failover_ping_timeout = {
        type = 'positive number', name = 'Failover ping timeout',
        is_optional = true, default = consts.DEFAULT_FAILOVER_PING_TIMEOUT
    },
}

--
-- Names of options which cannot be changed during reconfigure.
--
local vshard_non_dynamic_options = {
    'bucket_count', 'shard_index'
}

--
-- Check sharding config on correctness. Check types, name and uri
-- uniqueness, master count (in each replicaset must be <= 1).
--
local function vshard_cfg_check(shard_cfg, old_cfg)
    if type(shard_cfg) ~= 'table' then
        error('Сonfig must be map of options')
    end
    shard_cfg = table.deepcopy(shard_cfg)
    validate_config(shard_cfg, vshard_cfg_schema)
    if not old_cfg then
        return shard_cfg
    end
    -- Check non-dynamic after default values are added.
    for _, f_name in pairs(vshard_non_dynamic_options) do
        -- New option may be added in new vshard version.
        if shard_cfg[f_name] ~= old_cfg[f_name] then
           error(string.format('Non-dynamic option %s ' ..
                               'cannot be reconfigured', f_name))
        end
    end

    return shard_cfg
end

local topology_opts_schema = {
    --sharding = {type = 'table', name = 'Sharding', check = check_sharding},
    weights = {
        type = 'table', name = 'Weight matrix', is_optional = true,
        check = cfg_check_weights
    },
    shard_index = {
        type = {'non-empty string', 'non-negative integer'},
        name = 'Shard index', is_optional = true, default = 'bucket_id',
    },
    zone = {
        type = {'string', 'number'}, name = 'Zone identifier',
        is_optional = true
    },
    bucket_count = {
        type = 'positive integer', name = 'Bucket count', is_optional = true,
        default = consts.DEFAULT_BUCKET_COUNT
    },
    rebalancer_disbalance_threshold = {
        type = 'non-negative number', name = 'Rebalancer disbalance threshold',
        is_optional = true,
        default = consts.DEFAULT_REBALANCER_DISBALANCE_THRESHOLD
    },
    rebalancer_max_receiving = {
        type = 'positive integer',
        name = 'Rebalancer max receiving bucket count', is_optional = true,
        default = consts.DEFAULT_REBALANCER_MAX_RECEIVING
    },
    rebalancer_max_sending = {
        type = 'positive integer',
        name = 'Rebalancer max sending bucket count',
        is_optional = true,
        default = consts.DEFAULT_REBALANCER_MAX_SENDING,
        max = consts.REBALANCER_MAX_SENDING_MAX
    },
    collect_bucket_garbage_interval = {
        type = 'positive number', name = 'Garbage bucket collect interval',
        is_optional = true,
        default = consts.DEFAULT_COLLECT_BUCKET_GARBAGE_INTERVAL
    },
    collect_lua_garbage = {
        type = 'boolean', name = 'Garbage Lua collect necessity',
        is_optional = true, default = false
    },
    sync_timeout = {
        type = 'non-negative number', name = 'Sync timeout', is_optional = true,
        default = consts.DEFAULT_SYNC_TIMEOUT
    },
    connection_outdate_delay = {
        type = 'non-negative number', name = 'Object outdate timeout',
        is_optional = true
    },
    -- TODO: add to method that create new topology
    failover_ping_timeout = {
        type = 'positive number', name = 'Failover ping timeout',
        is_optional = true, default = consts.DEFAULT_FAILOVER_PING_TIMEOUT
    },
    -- TODO
    -- @boolean[opt] opts.is_bootstrapped
    --     Set to true when cluster is bootstrapped. Some topology options
    --     cannot be changed once cluster is bootstrapped. For example bucket_count.
    -- @string[opt] opts.discovery_mode
    --     A mode of a bucket discovery fiber: on/off/once.
    --     See [Sharding Configuration reference][1].
}

local replicaset_opts_schema = {
    master_mode = {
        type = 'string', name = 'Master mode', is_optional = true,
    },
    failover_priority = {
        type = 'table', name = 'Failover priority', is_optional = true,
    },
    weights = {
        type = 'positive number', name = 'Weight value', is_optional = true,
    },
}

local function check_box_cfg(opts)
    -- TODO: check all options are supported by Tarantool
    print(opts)
end

local instance_opts_schema = {
    box_cfg = {
        type = 'table', name = 'box.cfg', is_optional = true,
        check = check_box_cfg
    },
    distance = {
        type = 'positive number', name = 'Distance', is_optional = true,
    },
    advertise_uri = {
        type = 'string', name = 'Advertise URI', is_optional = true,
        check = check_uri
    },
    zone = {
        type = {'string', 'number'}, name = 'Zone identifier', is_optional = true
    },
    is_master = {
        type = 'boolean', name = 'Master capability', is_optional = true
    },
    is_router = {
        type = 'boolean', name = 'Router capability', is_optional = true
    },
    is_storage = {
        type = 'boolean', name = 'Storage capability', is_optional = true
    },
}

local function check_topology_opts(opts)
    validate_config(opts, topology_opts_schema)
end

local function check_replicaset_opts(opts)
    validate_config(opts, replicaset_opts_schema)
end

local function check_instance_opts(opts)
    validate_config(opts, instance_opts_schema)
end

return {
    check_uri = check_uri,
    check_topology_opts = check_topology_opts,
    check_replicaset_opts = check_replicaset_opts,
    check_instance_opts = check_instance_opts,
    check_box_cfg = check_box_cfg,

    vshard_check = vshard_cfg_check,
}
