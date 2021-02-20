--- mock driver.
-- @module conf.driver.mock

-- Forward declaration.
local mt

local function next_key(key)
    return ''
end

local NEXT = next_key
local ALL = '\0'

local function new(opts)
    return setmetatable({}, mt)
end

local function put(self, key, value, opts)
    return {}
end

local function range(self, key, range_end, opts)
    return {}
end

mt = {
    __index = {
        put = put,
        range = range,
        NEXT = NEXT,
        ALL = ALL,
    }
}

return {
    new = new,
    NEXT = NEXT,
    ALL = ALL,
}
