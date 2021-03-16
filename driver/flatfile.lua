--- flat file driver.
-- @module conf.driver.flatfile

local fio = require('fio')

-- Forward declaration.
local mt

local function new(opts)
    local filename = opts.filename

    return setmetatable({
        filename = filename,
    }, mt)
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
    }
}

return {
    new = new,
}
