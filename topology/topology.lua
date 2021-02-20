-- https://github.com/Totktonada/conf

--[[
local DEFAULT_ENDPOINT = 'http://localhost:2379'

client = etcd_client_lib.new({
    endpoints = {DEFAULT_ENDPOINT},
    -- Uncomment for debugging.
    -- http_client = {request = {verbose = true}},
})

conf_obj = conf.init({
    provider = { type = 'etcdv2', { uri = 'localhost:5432', user = 'test', password = 'test'}},
    cluster_name = 'ABC'
})

box.cfg(configuration.get_box_config())

topology = configuration.get_topology()
{
    revision = 3,
    replicasets =  
        ['aaaaaaaa-0000-4000-a000-000000000000'] = {
            replicas = {
                ['aaaaaaaa-0000-4000-a000-000000000011'] = {
                    name = 'moscow-storage',
                    master=true,
                    uri="sharding:pass@127.0.0.1:30011",
                    zone = 'msk'
                },
            }
        }
}

current_topology = topology.get()

topology.get_self()
topology.get_instances({ filter = { uuid = { 'adadas-dasdasdsad-....'}}}) 
topology.get_replicasets({ filter = { uuid = { 'adadas-dasdasdsad-....'}}})

add_instance(parameters, meta)
topology.add_instance({ 
    uri = '...', 
    name = '...', 
    uuid = '???', 
    zone = 'msk', 
    replicaset = 'storages-msk-1'
}, {
    state = 'enabled',
    status = 'healthy',
    alias = '...',
    priority = 5,
    clock_delta = 0.434
})

topology.remove_instance('storage-msk-1-1')
topology.remove_instance({ uuid = 'dadada-adasdasad-sdadsda-sdsds'})

update_instance_meta(instance_name, meta_key, value)
update_instance_meta(instance_name, table_with_meta)
topology.update_instance_meta('storage-msk-1-1', 'status', 'disabled')
topology.update_instance_meta('storage-msk-1-1', { status = 'disabled', priority = 0})
]]

-- @module topology

-- Forward declaration.
local mt

-- {{{ Module functions

--- Module functions.
--
-- @section Functions

--- Create a new etcd client instance.
--
-- @return topology instance.
--
-- @function tolopogy.new
local function new(opts)
    return setmetatable({}, mt)
end

-- }}} Module functions

-- {{{ Instance methods

--- Instance methods.
--
-- @section Methods

--- Put the given key into the key-value storage.
--
-- Creates a key if it does not exist. Increments a revision of
-- the key-value store. Generates one event in the event history.
--
-- @function instance.put
local function put(self, key, value, opts)
    return {}
end

mt = {
    __index = {
        put = put,
        range = range,
    }
}

-- }}} Instance methods

-- {{{ General API notes

--- General API notes.
--
-- }}} General API notes

return {
    new = new,
}
