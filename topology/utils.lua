local random = math.random

math.randomseed(os.time())

local function uuid()
    local template ='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[x]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function sort_table_by_key(table)
    table.sort(table, function(a, b) return a.size > b.size end)
    return table
end

-- This routine is used to check if the UTF-8 string string is a legal
-- unqualified name for a new schema object (table, index, view or
-- trigger). All names are legal except those that begin with the string
-- "sqlite_" (in upper, lower or mixed case).

-- Source code: src/box/sql/alter.c
-- https://github.com/tarantool/tarantool/commit/f9a541d681dea3983e5353fb88193a05c66ef605
local function validate_identifier(string)
    print(string)
    return true
end

return {
    sort_table_by_key = sort_table_by_key,
    validate_identifier = validate_identifier,
    uuid = uuid,
}
