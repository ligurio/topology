#!/usr/bin/env tarantool

require('strict').on()

-- Get instance name
local fio = require('fio')
local NAME = fio.basename(arg[0], '.lua')
local DEFAULT_ENDPOINT = 'http://localhost:2379'
local TOPOLOGY_NAME = 'vshard'
local fiber = require('fiber')

-- Start the database with sharding
package.path = 'conf/?.lua;conf/?/init.lua;' .. package.path
local conf_lib = require('conf')
package.path = '../?.lua;../?/init.lua;' .. package.path
local topology = require('topology')
local vshard = require('vshard')

local conf_client = conf_lib.new({DEFAULT_ENDPOINT}, {driver = 'etcd'})
local t = topology.new(conf_client, TOPOLOGY_NAME)
local cfg = t:get_vshard_config()
local uuid = t:get_instance_conf(NAME).instance_uuid
vshard.storage.cfg(cfg, uuid)

box.once("testapp:schema:1", function()
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
    box.schema.func.create('raise_luajit_error')
    box.schema.role.grant('public', 'execute', 'function', 'raise_luajit_error')
    box.schema.func.create('raise_client_error')
    box.schema.role.grant('public', 'execute', 'function', 'raise_client_error')
end)

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

-- luacheck: ignore
local function raise_luajit_error()
    assert(1 == 2)
end

-- luacheck: ignore
local function raise_client_error()
    box.error(box.error.UNKNOWN)
end
