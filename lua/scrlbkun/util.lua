local uv = vim.loop
local api = vim.api

local M = {}

local function deep_contains(table, value)
    for _, table_value in pairs(table) do
        if vim.deep_equal(table_value, value) then
            return true
        end
    end

    return false
end

local function set_timeout(timeout, callback)
    local timer = uv.new_timer()
    timer:start(timeout, 0, function ()
        timer:stop()
        timer:close()
        callback()
    end)
    return timer
end

local function execute_on_all_windows_in_current_tab(callback)
    local window_ids = api.nvim_tabpage_list_wins(0)

    for _, window_id in ipairs(window_ids) do
        callback(window_id)
    end
end

local function create_autocmd_wrapped(group, events, callback)
    if not (events and #events > 0) then
        return
    end

    for _, event in ipairs(events) do
        local event_name, pattern
        if type(event) == "table" then
            event_name, pattern = event[1], event[2]
        elseif type(event) == "string" then
            event_name = event
        else
            error("invalid event format")
        end
        api.nvim_create_autocmd(event_name, {
            group = group,
            callback = callback,
            pattern = pattern
        })
    end
end


M.deep_contains = deep_contains
M.set_timeout = set_timeout
M.execute_on_all_windows_in_current_tab = execute_on_all_windows_in_current_tab
M.create_autocmd_wrapped = create_autocmd_wrapped

return M
