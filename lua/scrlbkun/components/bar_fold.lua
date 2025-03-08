local api = vim.api
local fn = vim.fn
local states = require('scrlbkun.states')

local component_name = "bar_fold"

local default_config = {
    enable = true,
    sign = " ",
    draw_columns = { 1, 2, 3 },
    draw_events = { "WinScrolled", "BufEnter", "FocusGained" },
    draw_events_tab = { "VimResized", "TabEnter" },
    priority = 150,
}

local bar_highlight_name = "ScrlbkunBarFold"
local highlights = {
    [bar_highlight_name] = {
        default = true,
        bg = api.nvim_get_hl_by_name('Folded', true).background,
        ctermbg = api.nvim_get_hl_by_name('Folded', false).background
    }
}

local M = require('scrlbkun.components.base').new(component_name, default_config, highlights)

function M:calculate(window_id)

    local bar_fold_config = require('scrlbkun.config').get()[component_name]
    local option = {
        virt_text = { { bar_fold_config.sign, bar_highlight_name } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = bar_fold_config.priority
    }

    local coordinate_option_list = {}

    local current_line_number = fn.line("w0", window_id)
    local bottom_line_number = fn.line("w$", window_id)

    local s = states.states[window_id]
    local number_of_lines_in_display_buffer = s.number_of_lines_in_display_buffer
    local number_of_lines = api.nvim_buf_line_count(api.nvim_win_get_buf(window_id))
    local ratio = number_of_lines_in_display_buffer / number_of_lines

    while current_line_number <= bottom_line_number do
        local foldclosedend = fn.foldclosedend(current_line_number)
        if foldclosedend >= 0 then
            local foldclosed = fn.foldclosed(current_line_number)

            -- 0-based
            local strict_bar_top_coordinate = math.min(math.floor((foldclosed - 1) * ratio + 0.5),
                number_of_lines_in_display_buffer - 1)

            local number_of_visible_lines = foldclosedend - foldclosed + 1
            local bar_length = math.max(math.floor(number_of_visible_lines * ratio + 0.5), 1)

            local bar_top_coordinate = math.min(strict_bar_top_coordinate,
                number_of_lines_in_display_buffer - bar_length + 1)

            for i = bar_top_coordinate, bar_top_coordinate + bar_length - 1 do
                coordinate_option_list[i] = option
            end

            current_line_number = foldclosedend + 1
        else
            current_line_number = current_line_number + 1
        end
    end


    return coordinate_option_list
end

return M
