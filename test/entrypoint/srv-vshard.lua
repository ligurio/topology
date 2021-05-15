#!/usr/bin/env tarantool

local fio = require('fio')
local log = require('log')
local inspect = require('inspect')
local os = require('os')
local conf_lib = require('conf')
local topology = require('topology')
local vshard = require('vshard')

local workdir = os.getenv('TARANTOOL_WORKDIR')
local conf_storage_endpoint = os.getenv('TARANTOOL_CONF_STORAGE_URL')
local topology_name = os.getenv('TARANTOOL_TOPOLOGY_NAME')
local router_role = os.getenv('TARANTOOL_ROUTER_ROLE')
local storage_role = os.getenv('TARANTOOL_STORAGE_ROLE')
local instance_id = fio.basename(arg[0], '.lua')

-- Get instance configuration from Tarantool topology
local conf_client = conf_lib.new({driver = 'etcd', endpoints = { conf_storage_endpoint }})
assert(conf_client ~= nil)
local t = topology.new(conf_client, topology_name)
assert(t ~= nil)
local cfg = t:get_vshard_config()
assert(cfg ~= nil)

-- Fix box.cfg.work_dir on instance 'instance_id'
for _, replicaset in pairs(cfg.sharding) do
    for _, replica in pairs(replicaset.replicas) do
        if replica.name == instance_id then
            replica.work_dir = workdir
        end
    end
end

log.info(inspect.inspect(cfg))
local uuid = t:get_instance_conf(instance_id).instance_uuid
assert(uuid ~= nil)

if storage_role then
    log.info(string.format('Bootstrap storage on instance "%s":', instance_id))
    vshard.storage.cfg(cfg, uuid)
    box.once("testapp:schema:1", function()
        box.schema.user.create('storage', {password = 'storage'})
        box.schema.user.grant('storage', 'replication') -- grant replication role
        box.schema.user.grant('guest', 'read,write,execute,create,drop', 'universe')
        log.info('box.once() executed on ' .. instance_id)
        local customer = box.schema.space.create('customer')
        customer:format({
            {'customer_id', 'unsigned'},
            {'bucket_id', 'unsigned'},
            {'name', 'string'},
        })
        customer:create_index('customer_id', {parts = {'customer_id'}})
        customer:create_index('bucket_id', {parts = {'bucket_id'}, unique = false})

        local account = box.schema.space.create('account')
        account:format({
            {'account_id', 'unsigned'},
            {'customer_id', 'unsigned'},
            {'bucket_id', 'unsigned'},
            {'balance', 'unsigned'},
            {'name', 'string'},
        })
        account:create_index('account_id', {parts = {'account_id'}})
        account:create_index('customer_id', {parts = {'customer_id'}, unique = false})
        account:create_index('bucket_id', {parts = {'bucket_id'}, unique = false})
        box.snapshot()

        box.schema.func.create('customer_lookup')
        box.schema.role.grant('public', 'execute', 'function', 'customer_lookup')
        box.schema.func.create('customer_add')
        box.schema.role.grant('public', 'execute', 'function', 'customer_add')
        box.schema.func.create('echo')
        box.schema.role.grant('public', 'execute', 'function', 'echo')
        box.schema.func.create('sleep')
        box.schema.role.grant('public', 'execute', 'function', 'sleep')
    end)
end

if router_role then
    log.info(string.format('Bootstrap router on instance "%s":', instance_id))
    vshard.router.cfg(cfg)
    vshard.router.bootstrap()
    box.once("testapp:schema:1", function()
        box.schema.user.create('storage', {password = 'storage'})
        box.schema.user.grant('storage', 'replication') -- grant replication role
        box.schema.user.grant('guest', 'read,write,execute,create,drop', 'universe')
    end)
end

-- luacheck: ignore
function customer_add(customer)
    box.begin()
    box.space.customer:insert({customer.customer_id, customer.bucket_id,
                               customer.name})
    for _, account in ipairs(customer.accounts) do
        box.space.account:insert({
            account.account_id,
            customer.customer_id,
            customer.bucket_id,
            0,
            account.name
        })
    end
    box.commit()
    return true
end

-- luacheck: ignore
function customer_lookup(customer_id)
    if type(customer_id) ~= 'number' then
        error('Usage: customer_lookup(customer_id)')
    end

    local customer = box.space.customer:get(customer_id)
    if customer == nil then
        return nil
    end
    customer = {
        customer_id = customer.customer_id;
        name = customer.name;
    }
    local accounts = {}
    for _, account in box.space.account.index.customer_id:pairs(customer_id) do
        table.insert(accounts, {
            account_id = account.account_id;
            name = account.name;
            balance = account.balance;
        })
    end
    customer.accounts = accounts;
    return customer
end

-- luacheck: ignore
local function echo(...)
    return ...
end

-- luacheck: ignore
local function sleep(time)
    fiber.sleep(time)
    return true
end
