local fn = vim.fn

local component_name = "cursor"

local default_config = {
    enable = true,
    signs = {
        "▔",
        "━",
        "▁",
        -- "1",
        -- "2",
        -- "3",
        -- "4",
        -- "5",
        -- "6",
        -- "7",
        -- "8",
    },
    draw_events = {"BufEnter", "FocusGained", "CursorMoved"},
    draw_events_tab = {"VimResized", "TabEnter"},
    priority = 150,
    sign_arrangement = "skip_first", -- "skip_first" or "normal"
}

local cursor_highlight_name = "ScrlbkunCursor"
local highlights = {
    [cursor_highlight_name] = {
        default = true,
        fg = '#add8e6',
        ctermfg = 'LightBlue'
    }
}

local M = require('scrlbkun.components.base').new(component_name, default_config, highlights)

function M:calculate(window_id)
    local top_line_number = fn.line("w0", window_id)
    local bottom_line_number = fn.line("w$", window_id)

    local number_of_visible_lines = bottom_line_number - top_line_number + 1

    local bar_top_coordinate, bar_length = require('scrlbkun.components.bar').calculate_bar(window_id)

    -------------------------

    local cursor_line_number = fn.line(".", window_id)
    local strict_cursor_coordinate_relative_to_bar = (bar_length * (cursor_line_number - top_line_number + 0.5)) / number_of_visible_lines

    local cursor_config = require('scrlbkun.config').get()[component_name]

    local cursor_coordinate_relative_to_bar = math.floor(strict_cursor_coordinate_relative_to_bar)
    local fractional_part = strict_cursor_coordinate_relative_to_bar - cursor_coordinate_relative_to_bar


    local number_of_signs = #(cursor_config.signs)
    local sign_index = -1

    if cursor_config.sign_arrangement == "skip_first" then
        if number_of_signs == 1 then
            sign_index = 1
        else
            local interval = 1 / (number_of_signs - 1)

            if fractional_part < interval / 2 then
                if cursor_coordinate_relative_to_bar == 0 then
                    sign_index = 1
                else
                    cursor_coordinate_relative_to_bar = cursor_coordinate_relative_to_bar - 1
                    sign_index = number_of_signs
                end
            else
                sign_index = 2
                for i = interval / 2, 1, interval do
                    if i <= fractional_part and fractional_part < i + interval then
                        break
                    end
                    sign_index = sign_index + 1
                end
            end
        end
    elseif cursor_config.sign_arrangement == "normal" then
        if number_of_signs == 1 then
            sign_index = 1
        else
            sign_index = 1
            local interval = 1 / number_of_signs
            for i = 1, number_of_signs - 1 do
                if fractional_part <= i * interval then
                    break
                end
                sign_index = sign_index + 1
            end
        end
    else
        error(string.format("Invalid cursor arrangement: '%s'", cursor_config.sign_arrangement))
    end

    local sign = cursor_config.signs[sign_index]

    local option = {
        virt_text = {{sign, cursor_highlight_name}},
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = cursor_config.priority
    }

    local coordinate_option_list = {}
    coordinate_option_list[bar_top_coordinate + cursor_coordinate_relative_to_bar] = option
    return coordinate_option_list
end

return M
