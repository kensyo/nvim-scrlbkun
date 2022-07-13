local api = vim.api
local fn = vim.fn
local states = require('scrlbkun.states')

local component_name = "bar"

local default_config = {
    enable = true,
    sign = " ",
    draw_columns = {1, 2, 3},
    draw_events = {"WinScrolled", "BufEnter", "FocusGained"},
    draw_events_tab = {"VimResized", "TabEnter"},
    priority = 100,
}

local bar_highlight_name = "ScrlbkunBar"
local highlights = {
    [bar_highlight_name] = {
        default = true,
        bg = '#808080',
        ctermbg = 'Gray'
    }
}

local M = require('scrlbkun.components.base').new(component_name, default_config, highlights)

local function calculate_bar(window_id)
    local s = states.states[window_id]
    local number_of_lines_in_display_buffer = s.number_of_lines_in_display_buffer
    local number_of_lines = api.nvim_buf_line_count(api.nvim_win_get_buf(window_id))
    local top_line_number = fn.line("w0", window_id)
    local bottom_line_number = fn.line("w$", window_id)
    local ratio = number_of_lines_in_display_buffer / number_of_lines
    -- 0-based
    local strict_bar_top_coordinate = math.min(math.floor((top_line_number - 1) * ratio + 0.5), number_of_lines_in_display_buffer - 1)

    local number_of_visible_lines = bottom_line_number - top_line_number + 1
    local bar_length = math.max(math.floor(number_of_visible_lines * ratio + 0.5), 1)

    local bar_top_coordinate = math.min(strict_bar_top_coordinate, number_of_lines_in_display_buffer - bar_length + 1)

    return bar_top_coordinate, bar_length
end

function M:calculate(window_id)
    local bar_top_coordinate, bar_length = calculate_bar(window_id)

    -------------------------

    local bar_config = require('scrlbkun.config').get()[component_name]
    local option = {
        virt_text = {{bar_config.sign, bar_highlight_name}},
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = bar_config.priority
    }

    local coordinate_option_list = {}
    for i = bar_top_coordinate, bar_top_coordinate + bar_length - 1 do
        coordinate_option_list[i] = option
    end

    return coordinate_option_list
end

M.calculate_bar = calculate_bar

return M
