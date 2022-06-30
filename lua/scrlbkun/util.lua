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

M.deep_contains = deep_contains
M.set_timeout = set_timeout
M.execute_on_all_windows_in_current_tab = execute_on_all_windows_in_current_tab

return M
