local ffi = require('ffi')
local json = require('json')

--
-- Error messages description.
-- * name -- Key by which an error code can be retrieved from
--   the expoted by the module `code` dictionary.
-- * msg -- Error message which can use `args` using
--   `string.format` notation.
-- * args -- Names of arguments passed while constructing an
--   error. After constructed, an error-object contains provided
--   arguments by the names specified in the field.
--
local error_message_template = {
    [1] = {
        name = 'WRONG_BUCKET',
        msg = 'Cannot perform action with bucket %d, reason: %s',
        args = {'bucket_id', 'reason', 'destination'}
    },
    [2] = {
        name = 'NON_MASTER',
        msg = 'Replica %s is not a master for replicaset %s anymore',
        args = {'replica_uuid', 'replicaset_uuid'}
    },
}

--
-- User-visible error_name -> error_number dictionary.
--
local error_code = {}
for code, err in pairs(error_message_template) do
    assert(type(code) == 'number')
    assert(err.msg, 'msg is required field')
    assert(error_code[err.name] == nil, "Dublicate error name")
    error_code[err.name] = code
end

--
-- There are 2 error types:
-- * box_error - it is created on tarantool errors: client error,
--   oom error, socket error etc. It has type = one of tarantool
--   error types, trace (file, line), message;
-- * vshard_error - it is created on sharding errors like
--   replicaset unavailability, master absense etc. It has type =
--   'ShardingError', one of codes below and optional
--   message.
--

local function box_error(original_error)
    return setmetatable(original_error:unpack(), {__tostring = json.encode})
end

--
-- Construct an vshard error.
-- @param code Number, one of error_code constants.
-- @param ... Arguments from `error_message_template` `args`
--        field. Caller have to pass at least as many arguments
--        as `msg` field requires.
-- @retval ShardingError object.
--
local function vshard_error(code, ...)
    local format = error_message_template[code]
    assert(format, 'Error message format is not found.')
    local args_passed_cnt = select('#', ...)
    local args = format.args or {}
    assert(#args == args_passed_cnt,
           string.format('Wrong number of arguments are passed to %s error',
                         format.name))
    local ret = setmetatable({}, {__tostring = json.encode})
    -- Save error arguments.
    for i = 1, #args do
        ret[args[i]] = select(i, ...)
    end
    ret.message = string.format(format.msg, ...)
    ret.type = 'ShardingError'
    ret.code = code
    ret.name = format.name
    return ret
end

--
-- Convert error object from pcall to lua, box or vshard error
-- object.
--
local function make_error(e)
    if type(e) == 'cdata' and ffi.istype('struct error', e) then
        -- box.error, return unpacked
        return box_error(e)
    elseif type(e) == 'string' then
        local _, err = pcall(box.error, box.error.PROC_LUA, e)
        return box_error(err)
    elseif type(e) == 'table' then
        return setmetatable(e, {__tostring = json.encode})
    else
        return e
    end
end

local function make_alert(code, ...)
    local format = error_message_template[code]
    assert(format)
    local r = {format.name, string.format(format.msg, ...)}
    return setmetatable(r, { __serialize = 'seq' })
end

return {
    code = error_code,
    box = box_error,
    vshard = vshard_error,
    make = make_error,
    alert = make_alert,
}
