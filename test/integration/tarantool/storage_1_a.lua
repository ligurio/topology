#!/usr/bin/env tarantool

require('strict').on()

-- Get instance name
local fio = require('fio')
local NAME = fio.basename(arg[0], '.lua')
local fiber = require('fiber')
local conf_lib = require('conf')
local os = require('os')

-- Check if we are running under test-run
if os.getenv('ADMIN') then
    test_run = require('test_run').new()
    require('console').listen(os.getenv('ADMIN'))
end

-- require in-repo version of topology/ sources despite current working directory
local cur_dir = fio.abspath(debug.getinfo(1).source:match("@?(.*/)")
    :gsub('/./', '/'):gsub('/+$', ''))
package.path =
    cur_dir .. '/../../../../?/init.lua' .. ';' ..
    cur_dir .. '/../../../../?.lua' .. ';' ..
    package.path
local topology = require('topology')

print(os.environ())

--[[
box.cfg({
    listen              = os.getenv("LISTEN"),
    memtx_memory        = 107374182,
})
]]

print('NAME ' .. NAME)

-- Start the database with sharding
local DEFAULT_ENDPOINT = 'http://localhost:2379'
local conf_client = conf_lib.new({driver = 'etcd', endpoints = { DEFAULT_ENDPOINT }})
local t = topology.new(conf_client, 'tarantool_topology')
local instance_conf = t:get_instance_conf(NAME)

-- get instance name from filename (master_quorum1.lua => master_quorum1)
local INSTANCE_ID = string.match(arg[0], "%d")

local SOCKET_DIR = require('fio').cwd()

local TIMEOUT = tonumber(arg[1])

local function instance_uri(instance_id)
    --return 'localhost:'..(3310 + instance_id)
    return SOCKET_DIR..'/master_quorum'..instance_id..'.sock';
end

log = require('log')
instance_conf.uri = nil
--instance_conf.listen = os.getenv("LISTEN")
--instance_conf.replication = nil
local inspect = require('inspect')
print(inspect.inspect(instance_conf))
box.cfg(instance_conf)
--box.cfg{log_level=3}
--log.info('LISTEN' .. os.getenv("LISTEN"))

box.once("schema", function()
   box.schema.user.create('storage', {password = 'storage'})
   box.schema.user.grant('storage', 'storage') -- grant replication role
   box.schema.space.create("test")
   box.space.test:create_index("primary")
   print('box.once executed on ' .. NAME)
end)

--[[
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
]]

require('console').listen(os.getenv('ADMIN'))
