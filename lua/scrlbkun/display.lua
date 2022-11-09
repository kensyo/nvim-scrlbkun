local api = vim.api
local fn = vim.fn
local states = require('scrlbkun.states')
local uv = vim.loop

local M = {}

local function form_buffer(window_id)
    if not states.states[window_id] then
        states.states[window_id] = states.new_state()
    end
    local s = states.states[window_id]

    if s.display_buffer_number then
        api.nvim_buf_set_lines(s.display_buffer_number, 0, -1, false, {})
    else
        s.display_buffer_number = api.nvim_create_buf(false, true)
        api.nvim_buf_set_option(s.display_buffer_number, "undolevels", -1)
    end

    local lines = {}

    local ok, winbar_setting = pcall(api.nvim_get_option, "winbar")
    if ok and winbar_setting ~= "" then
        s.number_of_lines_in_display_buffer = api.nvim_win_get_height(window_id) - 1
    else
        s.number_of_lines_in_display_buffer = api.nvim_win_get_height(window_id)
    end

    local config = require('scrlbkun.config').get()
    local inserted_spaces = ""
    for _ = 1, config.width - 1 do
        inserted_spaces = inserted_spaces .. " "
    end

    for _ = 1, s.number_of_lines_in_display_buffer do
        table.insert(lines, inserted_spaces)
    end

    api.nvim_buf_set_lines(s.display_buffer_number, 0, -1, true, lines)

    return s.display_buffer_number
end

local function form_window(window_id)
    if not states.states[window_id] then
        states.states[window_id] = states.new_state()
    end
    local s = states.states[window_id]

    local number_of_lines_in_display_buffer = s.number_of_lines_in_display_buffer
    s.horizontal_offset_of_display_window = api.nvim_win_get_width(window_id)

    local config = require('scrlbkun.config').get()

    local window_config = {
        style = "minimal",
        relative = "win",
        win = window_id,
        width = config.width,
        height = number_of_lines_in_display_buffer,
        row = 0,
        col = s.horizontal_offset_of_display_window - config.width,
        focusable = false,
        zindex = config.zindex,
    }

    if s.display_window_id then
        api.nvim_win_set_config(s.display_window_id, window_config)
    else
        s.display_window_id = api.nvim_open_win(s.display_buffer_number, false, window_config)
        -- TODO: make the color configurable
        api.nvim_win_set_option(s.display_window_id, 'winhl', 'Normal:Normal')
        api.nvim_win_set_option(s.display_window_id, "winblend", config.winblend)
    end

    return s.display_window_id
end

local function should_form(window_id)
    local window_height = api.nvim_win_get_height(window_id)
    local window_width = api.nvim_win_get_width(window_id)

    local s = states.states[window_id]

    if not s then
        return true
    end

    return (window_height ~= s.number_of_lines_in_display_buffer
            or window_width ~= s.horizontal_offset_of_display_window)
end

local function should_form_window(window_id)
    local window_height = api.nvim_win_get_height(window_id)
    local window_width = api.nvim_win_get_width(window_id)

    local s = states.states[window_id]

    return s
        and (window_height == s.number_of_lines_in_display_buffer
            and window_width ~= s.horizontal_offset_of_display_window)
end

local function form(window_id)
    form_buffer(window_id)
    form_window(window_id)
end

local function hide(window_id)
    local s = states.states[window_id]
    if not s then
        return
    end

    if s.display_window_id then
        local ok, err = pcall(api.nvim_win_close, s.display_window_id, false)
        if not ok then
            -- if err doesn't start with E11, which is about window operations in the cmdline window
            if not string.find(err, "E11") then
                error(string.format('%s, %s, %s, %s', "scrlbkun", "delete", "nvim_win_close", err))
            end
        end
    end

    s.display_window_id = nil
    s.horizontal_offset_of_display_window = nil

    s:clear_timer()
end

local function delete(window_id)
    local s = states.states[window_id]
    if not s then
        return
    end

    for _, component in pairs(require('scrlbkun.components').enabled_components) do
        component:clear(window_id)
    end

    if s.display_window_id then
        local ok, err = pcall(api.nvim_win_close, s.display_window_id, false)
        if not ok then
            -- if err doesn't start with E11, which is about window operations in the cmdline window
            if not string.find(err, "E11") then
                error(string.format('%s, %s, %s, %s', "scrlbkun", "delete", "nvim_win_close", err))
            end
        end
    end

    if s.display_buffer_number then
        api.nvim_buf_delete(s.display_buffer_number, {})
    end

    -- s.display_buffer_number = nil
    -- s.line_number_of_display_buffer = nil
    -- s.display_window_id = nil
    -- s.horizontal_offset_of_display_window = nil

    s:clear_timer()

    states.states[window_id] = nil
end

local function is_window_to_draw(window_id)
    -- Ignore cmdline windows
    if vim.tbl_contains({'/', '?', ':'}, fn.getcmdwintype()) then
        return false
    end

    local window_config = api.nvim_win_get_config(window_id)

    -- Ignore floating windows
    if window_config.relative ~= "" then
        return false
    end

    local config = require('scrlbkun.config').get()

    local excluded_filetypes = config.excluded_filetypes
    local filetype = api.nvim_buf_get_option(api.nvim_win_get_buf(window_id), "filetype")
    if vim.tbl_contains(excluded_filetypes, filetype) then
        return false
    end

    local buffer_number = api.nvim_win_get_buf(window_id)
    local excluded_buftypes = config.excluded_buftypes
    local buftype = api.nvim_buf_get_option(buffer_number, "buftype")
    if vim.tbl_contains(excluded_buftypes, buftype) then
        return false
    end

    -- Ignore unloaded buffers
    if api.nvim_buf_line_count(buffer_number) == 0 then
        return false
    end

    if config.single_window and window_id ~= api.nvim_get_current_win() then
        return false
    end

    local top_line_number = fn.line("w0", window_id)
    local bottom_line_number = fn.line("w$", window_id)
    if bottom_line_number - top_line_number  + 1 == api.nvim_buf_line_count(api.nvim_win_get_buf(window_id)) then
        return false
    end

    return true
end

local function calculate_winblend_rate_in_fading_out(count, total_count)
    -- TODO: make the basepoint configurable
    local basepoint = 0.0 -- between 0 and 1
    local base = count - total_count * basepoint

    local rate = (base <= 0.0) and 0.0 or base / (total_count * (1 - basepoint))

    return rate
end

local function fadeout(window_id)
    local s = states.states[window_id]
    if s.timer then
        s.timer:stop()
    else
        s.timer = uv.new_timer()
    end

    local config = require('scrlbkun.config').get()

    local total_count = math.floor(config.fadeout_time / 100)
    local interval = config.fadeout_time / math.max(total_count, 1)

    local count = 0
    s.timer:start(interval, interval, vim.schedule_wrap(function()
        if count == total_count then
            hide(window_id)
        else
            local s2 = states.states[window_id]
            -- Because of vim.schedule_wrap(), the callback may be called even after executing timer:stop() and timer:close()
            -- in display.hide() or display.delete(). In that case, s.display_window_id does not exist, so the callback
            -- exits without doing anything.
            if (not s2) or not s2.display_window_id then
                return
            end
            api.nvim_win_set_option(
                s.display_window_id,
                "winblend",
                math.floor(config.winblend + (100 - config.winblend) * calculate_winblend_rate_in_fading_out(count, total_count))
            )
            count = count + 1
        end
    end))
end

local function should_fadeout()
    local config = require('scrlbkun.config').get()
    if config.fadeout_time > 0 then
        return true
    end

    return false
end


M.form = form
M.form_window = form_window
M.hide = hide
M.delete = delete
M.should_form = should_form
M.should_form_window = should_form_window
M.is_window_to_draw = is_window_to_draw
M.fadeout = fadeout
M.should_fadeout = should_fadeout

return M
