local api = vim.api
local states = require('scrlbkun.states')

local component_name = "githunks"

local default_config = {
    enable = true,
    signs = {
        add = {"│"},
        delete = {"▸"},
        change = {"│"},
        -- " │ ┃ ┆ ┇ ┊ ┋",
    },
    use_built_in_signs = true,
    draw_columns = {2},
    draw_events = {},
    draw_events_tab = {"BufEnter", "TabEnter", "TextChanged", "TextChangedI", "TextChangedP"},
    priority = 300,
}

local highlight_names = {
    add = "ScrlbkunGithunksAdd",
    delete = "ScrlbkunGithunksDelete",
    change = "ScrlbkunGithunksChange",
}

local highlights = {
    [highlight_names.add] = {
        default = true,
        link = "GitSignsAdd"
    },
    [highlight_names.delete] = {
        default = true,
        link = "GitSignsDelete"
    },
    [highlight_names.change] = {
        default = true,
        link = "GitSignsChange"
    },
}

local M = require('scrlbkun.components.base').new(component_name, default_config, highlights)

local built_in_signs = {
    {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"},

    {"▔", "▔", "▀", "▀", "▀", "▀", "█", "█"},
}

local function determine_type_to_use(detail)
    local number_of_add
        = detail.add
            and detail.add.upper + detail.add.lower
            or 0
    local number_of_delete
        = detail.delete
            and detail.delete.upper + detail.delete.lower
            or 0
    local number_of_change
        = detail.change
            and detail.change.upper + detail.change.lower
            or 0
    if number_of_add >= number_of_delete and number_of_add >= number_of_change then
        return "add"
    elseif number_of_delete >= number_of_add and number_of_delete >= number_of_change then
        return "delete"
    elseif number_of_change >= number_of_add and number_of_change >= number_of_delete then
        return "change"
    end
end

function M:calculate(window_id)

    local s = states.states[window_id]
    local number_of_liness_in_display_buffer = s.number_of_lines_in_display_buffer
    local buffer_number = api.nvim_win_get_buf(window_id)
    local number_of_lines_in_buffer = api.nvim_buf_line_count(buffer_number)
    -- local number_of_lines_per_row = number_of_lines_in_buffer / number_of_liness_in_display_buffer

    local hunks_info = {}

    for _, hunk in pairs(require('gitsigns').get_hunks(buffer_number) or {}) do
        local hunk_type = hunk.type
        -- 0-based
        local start_line = math.max(0, hunk.added.start - 1)
        for i = start_line, start_line + math.max(0, hunk.added.count - 1) do

            -- local strict_coordinate = i * / number_of_lines_per_row
            local strict_coordinate = i * number_of_liness_in_display_buffer / number_of_lines_in_buffer
            local coordinate = math.floor(strict_coordinate)
            local fractional_part = strict_coordinate - coordinate

            if not hunks_info[coordinate] then
                hunks_info[coordinate] = {}
            end

            if not hunks_info[coordinate][hunk_type] then
                hunks_info[coordinate][hunk_type] = {}
                hunks_info[coordinate][hunk_type].upper = 0
                hunks_info[coordinate][hunk_type].lower = 0
            end

            if fractional_part < 0.5 then
                hunks_info[coordinate][hunk_type].upper = hunks_info[coordinate][hunk_type].upper + 1
            else
                hunks_info[coordinate][hunk_type].lower = hunks_info[coordinate][hunk_type].lower + 1
            end
        end
    end

    local githunks_config = require('scrlbkun.config').get()[component_name]

    local coordinate_option_table = {}

    if githunks_config.use_built_in_signs then

        local number_of_signs = #(built_in_signs[1])
        local interval = 1 / number_of_signs
        local coordinates_with_upper_lower_the_same = {} -- key: coordinate, value: sign_index

        for coordinate, detail in pairs(hunks_info) do
            local type_to_use = determine_type_to_use(detail)

            local numbers = detail[type_to_use]

            -- local min = math.ceil(coordinate * number_of_lines_per_row)
            local min = math.ceil(coordinate * number_of_lines_in_buffer / number_of_liness_in_display_buffer)
            -- local max = math.ceil((coordinate + 1) * number_of_lines_per_row) - 1
            local max = math.ceil((coordinate + 1) * number_of_lines_in_buffer / number_of_liness_in_display_buffer) - 1

            --- the number of numbers whose integer part when divided by `number_of_lines_per_row` is `coordinate`
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
                virt_text = {{sign, highlight_names[type_to_use]}},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                priority = githunks_config.priority
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
        for coordinate, detail in pairs(hunks_info) do
            local type_to_use = determine_type_to_use(detail)

            local numbers = detail[type_to_use]

            local number_of_signs = #(githunks_config.signs[type_to_use])
            local interval = 1 / number_of_signs

            -- local ratio = (numbers.upper + numbers.lower) / number_of_lines_per_row
            local ratio = (numbers.upper + numbers.lower) * number_of_liness_in_display_buffer / number_of_lines_in_buffer

            local sign_index = 1

            for i = 1, number_of_signs - 1 do
                if ratio <= i * interval then
                    break
                end
                sign_index = sign_index + 1
            end

            local sign = githunks_config.signs[type_to_use][sign_index]
            local option = {
                virt_text = {{sign, highlight_names[type_to_use]}},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                priority = githunks_config.priority
            }

            coordinate_option_table[coordinate] = option
        end
    end

    return coordinate_option_table
end

return M

