local util= require('scrlbkun.util')
local states = require('scrlbkun.states')

local api = vim.api
local fn = vim.fn

local component_name = "search"

local default_config = {
    enable = true,
    use_built_in_signs = true,
    signs = {
        ".",
        ":",
    },
    draw_columns = {1},
    draw_events = {},
    draw_events_tab = {
        "TextChanged",
        "TextChangedI",
        "TextChangedP",
        "TabEnter",
        {
            "CmdlineLeave",
            {"/", "\\?", ":"}
        },
        {
            "CmdlineChanged",
            {"/", "\\?"}
        },
    },
    priority = 500
}

local search_highlight_name = "ScrlbkunSearch"
local highlights = {
    [search_highlight_name] = {
        default = true,
        fg = api.nvim_get_hl_by_name('Search', true).background,
        ctermfg = api.nvim_get_hl_by_name('Search', false).background
    }
}

local cache = {}

local built_in_signs = {
    {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"},

    {"▔", "▔", "▀", "▀", "▀", "▀", "█", "█"},
}

local M = require('scrlbkun.components.base').new(component_name, default_config, highlights)

local function is_search_mode()
    return api.nvim_get_mode().mode == 'c'
        and vim.tbl_contains({'/', '?'}, fn.getcmdtype())
end

local function get_search_pattern()
    if is_search_mode() then
        return fn.getcmdline()
    else
        return fn.getreg('/')
    end
end

function M:calculate(window_id)
    if not (vim.v.hlsearch == 1) and not is_search_mode() then
        return {}
    end

    local s = states.states[window_id]
    local number_of_lines_in_display_buffer = s.number_of_lines_in_display_buffer
    local buffer_number = api.nvim_win_get_buf(window_id)
    local number_of_lines_in_buffer = api.nvim_buf_line_count(buffer_number)
    local number_of_lines_per_row = number_of_lines_in_buffer / number_of_lines_in_display_buffer

    local match_result = {}
    local pattern = get_search_pattern()

    if cache[buffer_number]
        and cache[buffer_number].pattern == pattern
        and cache[buffer_number].changedtick == vim.b.changedtick
        and cache[buffer_number].window_height == number_of_lines_in_display_buffer then

        match_result = cache[buffer_number].match_result
    else
         -- save originals and go to the target window
        local original_window_id = api.nvim_get_current_win()
        api.nvim_set_current_win(window_id)
        local original_view = fn.winsaveview()
        local original_foldenable = api.nvim_win_get_option(window_id, 'foldenable')
        api.nvim_win_set_option(window_id, 'foldenable', false)

        api.nvim_win_set_cursor(window_id, {1, 0})
        local line_number = 1
        while true do
            local ok
            ok, line_number = pcall(vim.fn.search, pattern, "W")
            if not ok then
                -- restore
                api.nvim_win_set_option(window_id, 'foldenable', original_foldenable)
                fn.winrestview(original_view)
                api.nvim_set_current_win(original_window_id)
                return {}
            end

            if line_number == 0 then
                -- restore
                api.nvim_win_set_option(window_id, 'foldenable', original_foldenable)
                fn.winrestview(original_view)
                api.nvim_set_current_win(original_window_id)
                break
            end

            local strict_coordinate = (line_number - 1) / number_of_lines_per_row
            local coordinate = math.floor(strict_coordinate)
            local fractional_part = strict_coordinate - coordinate
            if match_result[coordinate] then
                if fractional_part < 0.5 then
                    match_result[coordinate].upper = match_result[coordinate].upper + 1
                else
                    match_result[coordinate].lower = match_result[coordinate].lower + 1
                end
            else
                match_result[coordinate] = {upper = 0, lower = 0}
                if fractional_part < 0.5 then
                    match_result[coordinate].upper = 1
                else
                    match_result[coordinate].lower = 1
                end
            end
        end

        -- Update cache
        cache[buffer_number] = {
            pattern = pattern,
            changedtick = vim.b.changedtick,
            window_height = number_of_lines_in_display_buffer,
            match_result = match_result
        }

    end

    local search_config = require('scrlbkun.config').get()[component_name]

    local coordinate_option_table = {}
    if search_config.use_built_in_signs then

        local number_of_signs = #(built_in_signs[1])
        local interval = 1 / number_of_signs
        local coordinates_with_upper_lower_the_same = {} -- key: coordinate, value: sign_index

        for coordinate, numbers in pairs(match_result) do
            local min = math.ceil(number_of_lines_per_row * coordinate)
            local max = math.ceil(number_of_lines_per_row * (coordinate + 1)) - 1

            --- Number of numbers whose integer part when divided by `number_of_lines_per_row` is `coordinate`
            local maximum_number_of_lines_coordinate_can_contain = max - min + 1

            local ratio = (numbers.upper + numbers.lower) / maximum_number_of_lines_coordinate_can_contain

            local sign_index = 1

            for i = 1, number_of_signs - 1 do
                if ratio < i * interval then
                    break
                end
                sign_index = sign_index + 1
            end

            local sign
            if numbers.lower > numbers.upper then
                sign = built_in_signs[1][sign_index]
            elseif numbers.lower < numbers.upper then
                sign = built_in_signs[2][sign_index]
            else
                sign = built_in_signs[1][sign_index]
                coordinates_with_upper_lower_the_same[coordinate] = sign_index
            end

            local option = {
                virt_text = {{sign, search_highlight_name}},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                priority = search_config.priority
            }

            coordinate_option_table[coordinate] = option
        end

        -- modification of the signs to use
        for coordinate, sign_index in pairs(coordinates_with_upper_lower_the_same) do
            if coordinate_option_table[coordinate + 1]
                and vim.tbl_contains(
                    built_in_signs[2],
                    coordinate_option_table[coordinate + 1].virt_text[1][1]
                ) then

                coordinate_option_table[coordinate].virt_text[1][1] = built_in_signs[1][sign_index]
            elseif coordinate_option_table[coordinate - 1]
                and vim.tbl_contains(
                    built_in_signs[1],
                    coordinate_option_table[coordinate - 1].virt_text[1][1]
                ) then

                coordinate_option_table[coordinate].virt_text[1][1] = built_in_signs[2][sign_index]
            end
        end
    else
        local number_of_search_signs = #(search_config.signs)
        local interval = 1 / number_of_search_signs

        for coordinate, numbers in pairs(match_result) do
            local ratio = (numbers.upper + numbers.lower) / number_of_lines_per_row

            local search_sign_index = 1

            for i = 1, number_of_search_signs - 1 do
                if 0 <= ratio and ratio <= i * interval then
                    break
                end
                search_sign_index = search_sign_index + 1
            end

            local sign = search_config.signs[search_sign_index]
            local option = {
                virt_text = {{sign, search_highlight_name}},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                priority = search_config.priority
            }

            coordinate_option_table[coordinate] = option
        end
    end

    return coordinate_option_table

end

--- Instead of the execute function in base, use the draw function redefined as follows
--- At CmdlineLeave timing, v:hlsearch is not set to 0 when :nohlsearch is executed.
--- Similarly, v:hlsearch is not set to 1 after /"searchwords".
--- Therefore, the role of this redefined function is to execute with a delay.
function M:execute(window_id)
    util.set_timeout(1, vim.schedule_wrap(function()
        if not (vim.v.exiting == vim.NIL) then
            return
        end

        local window_ids_in_current_tab = api.nvim_tabpage_list_wins(0)
        if not vim.tbl_contains(window_ids_in_current_tab, window_id) then
            return
        end
        require('scrlbkun.components.base').execute(self, window_id)
    end))
end

return M
