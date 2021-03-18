local random = math.random

math.randomseed(os.time())

local function uuid()
    local template ='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[x]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

return {
    uuid = uuid,
}
