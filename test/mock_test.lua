local t = require('luatest')
local mock_client_lib = require('driver.mock')
local topology = require('topology.topology')

local g = t.group()

-- {{{ Data generators

local kv_next = 1

local function gen_prefix()
    local res = 'prefix_' .. tostring(kv_next) .. '.'
    kv_next = kv_next + 1
    return res
end

local function gen_key()
    local res = 'key_' .. tostring(kv_next)
    kv_next = kv_next + 1
    return res
end

local function gen_value()
    local res = 'value_' .. tostring(kv_next)
    kv_next = kv_next + 1
    return res
end

-- }}} Data generators

-- {{{ Setup / teardown

g.before_all(function()
    -- Create a client.
    g.client = mock_client_lib.new({})
end)

g.after_all(function()
    -- Drop the client.
    g.client = nil
end)

-- }}} Setup / teardown

-- {{{ put

-- Just put and get it back.
g.test_put_basic = function()
    local key = gen_key()
    local value = gen_value()

    -- Put a key-value.
    local response = g.client:put(key, value)
    -- assert_put_response(response)

    -- Get it back.
    local response = g.client:range(key)
    --assert_range_response(response, {exp_kvs = {{key, value}}})
end

-- Put without a value associates the default string value (an
-- empty string) with the key.
g.test_nil_value = function()
    -- Associate some value with a key.
    local key = gen_key()
    local value = gen_value()
    g.client:put(key, value)

    -- Put without a value.
    g.client:put(key)
    -- verify_kv(g, key, '')
end

-- Verify prev_kv.
g.test_put_prev_kv = function()
    local key = gen_key()
    local value_1 = gen_value()
    g.client:put(key, value_1)

    local value_2 = gen_value()
    local response = g.client:put(key, value_2, {prev_kv = true})
    --assert_put_response(response, {key, value_1})
end

-- Basic put test with {ignore_value = true}.
g.test_put_ignore_value = function()
    -- Put some value.
    local key = gen_key()
    local value = gen_value()
    local response_1 = g.client:put(key, value)
    --local revision_1 = response_1.header.revision
    --local kv_1 = get_kv(g, key)

    -- Update the key with ignore_value.
    local response_2 = g.client:put(key, nil, {ignore_value = true})
    --local revision_2 = response_2.header.revision
    --local kv_2 = get_kv(g, key)

    -- Verify that one event was generated in the etcd cluster.
    --t.assert_equals(revision_1 + 1, revision_2)

    -- Verify that 'value' and 'create_revision' are not changed,
    -- but other KeyValue fields are bumped as expected.
    --t.assert_equals(kv_1.key, kv_2.key)
    --t.assert_equals(kv_1.create_revision, kv_2.create_revision)
    --t.assert_equals(kv_1.mod_revision + 1, kv_2.mod_revision)
    --t.assert_equals(kv_1.version + 1, kv_2.version)
    --t.assert_equals(kv_1.value, kv_2.value)
end

-- Attempt to bump a value of a non-exist key with
-- {ignore_value = true}.
g.test_put_ignore_value_without_key = function()
    local key = gen_key()
    local ok, err = pcall(g.client.put, g.client, key, nil,
        {ignore_value = true})
    --t.assert_equals(ok, false)
end

-- Pass ignore_value and value both.
g.test_put_ignore_value_with_value = function()
    -- Put some value.
    local key = gen_key()
    local value_1 = gen_value()
    g.client:put(key, value_1)

    -- Update the key with ignore_value **and value**.
    local value_2 = gen_value()
    local ok, err = pcall(g.client.put, g.client, key, value_2,
        {ignore_value = true})
    --t.assert_equals(ok, false)
end

-- Attempt to bump a value of non-exist key with
-- {ignore_lease = true}.
g.test_put_ignore_lease_without_key = function()
    local key = gen_key()
    local value = gen_value()
    local ok, err = pcall(g.client.put, g.client, key, value,
        {ignore_lease = true})
    --t.assert_equals(ok, false)
end

-- }}} put
