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

    --[[
    local conf_lib = nil
    if backend_type == 'etcd' then
        conf_lib = require('conf.driver.etcd')
    end
    ]]

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

local function new_instance(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

local function new_replicaset(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

local function delete_instance(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

local function delete_replicaset(self, opts)
    local name = rawget(self, 'name')
    local opts = opts or {}
    return nil
end

mt = {
    __index = {
        new_instance = new_instance,
        new_replicaset = new_replicaset,
        delete_instance = delete_instance,
        delete_replicaset = delete_replicaset,
        --delete = delete,
        --set_instance_property = set_instance_property,
        --set_instance_reachable = set_instance_reachable,
        --set_instance_unreachable = set_instance_unreachable,
        --set_topology_property = set_topology_property,
        --get_routers = get_routers,
        --get_storages = get_storages,
        --get_instance_conf = get_instance_conf,
        --new_instance_link = new_instance_link,
        --delete_instance_link = delete_instance_link,
    }
}

-- }}} Instance methods

return {
    new = new,
}
