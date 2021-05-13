local function sort_table_by_key(t)
    if next(t) == nil then
        return t
    end

    return t
    -- return table.sort(t, function(a, b) return a[1] < b[1] end)
end

local function remove_table_key(t, key)
    local d = {}
    for k, v in pairs(t) do
        if not k == key then
            d[k] = v
        end
    end

    return d
end

return {
    sort_table_by_key = sort_table_by_key,
    remove_table_key = remove_table_key,
}
