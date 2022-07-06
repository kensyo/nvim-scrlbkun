local api = vim.api
local util = require('scrlbkun.util')
local severities = vim.diagnostic.severity
local states = require('scrlbkun.states')

local component_name = "diagnostics"

local default_config = {
    enable = true,
    signs = {
        ERROR = {".", ":"},
        WARN = {".", ":"},
        INFO = {".", ":"},
        HINT = {".", ":"},
    },
    use_built_in_signs = true,
    draw_events = {},
    draw_events_tab = {"BufEnter", "DiagnosticChanged", "TabEnter"},
    priority = 400,
}

local highlight_names = {
    [severities.ERROR] = "ScrlbkunDiagnosticsError",
    [severities.WARN] = "ScrlbkunDiagnosticsWarn",
    [severities.INFO] = "ScrlbkunDiagnosticsInfo",
    [severities.HINT] = "ScrlbkunDiagnosticsHint",
}

local highlights = {
    [highlight_names[severities.ERROR]] = {
        default = true,
        fg = api.nvim_get_hl_by_name('DiagnosticError', true).foreground,
        ctermfg = api.nvim_get_hl_by_name('DiagnosticError', false).foreground
    },
    [highlight_names[severities.WARN]] = {
        default = true,
        fg = api.nvim_get_hl_by_name('DiagnosticWarn', true).foreground,
        ctermfg = api.nvim_get_hl_by_name('DiagnosticWarn', false).foreground
    },
    [highlight_names[severities.INFO]] = {
        default = true,
        fg = api.nvim_get_hl_by_name('DiagnosticInfo', true).foreground,
        ctermfg = api.nvim_get_hl_by_name('DiagnosticInfo', false).foreground
    },
    [highlight_names[severities.HINT]] = {
        default = true,
        fg = api.nvim_get_hl_by_name('DiagnosticHint', true).foreground,
        ctermfg = api.nvim_get_hl_by_name('DiagnosticHint', false).foreground
    },
}

local M = require('scrlbkun.components.base').new(component_name, default_config, highlights)

local built_in_signs = {
    {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"},

    {"▔", "▔", "▀", "▀", "▀", "▀", "█", "█"},
}

function M:calculate(window_id)
    local s = states.states[window_id]
    local number_of_lines_in_display_buffer = s.number_of_lines_in_display_buffer
    local buffer_number = api.nvim_win_get_buf(window_id)
    local number_of_lines_in_buffer = api.nvim_buf_line_count(buffer_number)
    local number_of_lines_per_row = number_of_lines_in_buffer / number_of_lines_in_display_buffer

    ---@type table<integer, table<integer, integer>>
    --- array of severity and line_number(0-based)
    local check_list = {}

    local diagnostic_info = {}

    for _, diagnostic in pairs(vim.diagnostic.get(buffer_number)) do
        local severity = diagnostic.severity
        -- 0-based
        local lnum = diagnostic.lnum

        local checked_pair = {severity, lnum}
        if not util.deep_contains(check_list, checked_pair) then
            table.insert(check_list, checked_pair)

            local strict_coordinate = lnum / number_of_lines_per_row
            local coordinate = math.floor(strict_coordinate)
            local fractional_part = strict_coordinate - coordinate

            if not diagnostic_info[coordinate] then
                diagnostic_info[coordinate] = {}
            end

            if not diagnostic_info[coordinate][severity] then
                diagnostic_info[coordinate][severity] = {}
                diagnostic_info[coordinate][severity].upper = 0
                diagnostic_info[coordinate][severity].lower = 0
            end

            if fractional_part < 0.5 then
                diagnostic_info[coordinate][severity].upper = diagnostic_info[coordinate][severity].upper + 1
            else
                diagnostic_info[coordinate][severity].lower = diagnostic_info[coordinate][severity].lower + 1
            end
        end
    end

    local diagnostics_config = require('scrlbkun.config').get()[component_name]

    local coordinate_option_table = {}

    if diagnostics_config.use_built_in_signs then

        local number_of_signs = #(built_in_signs[1])
        local interval = 1 / number_of_signs
        local coordinates_with_upper_lower_the_same = {} -- key: coordinate, value: sign_index

        for coordinate, detail in pairs(diagnostic_info) do
            local severity_to_use
            if detail[severities.ERROR] then
                severity_to_use = severities.ERROR
            elseif detail[severities.WARN] then
                severity_to_use = severities.WARN
            elseif detail[severities.INFO] then
                severity_to_use = severities.INFO
            elseif detail[severities.HINT] then
                severity_to_use = severities.HINT
            end

            local numbers = detail[severity_to_use]

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
                virt_text = {{sign, highlight_names[severity_to_use]}},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                priority = diagnostics_config.priority
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
        local number_of_signs = #(diagnostics_config.signs)
        local interval = 1 / number_of_signs

        for coordinate, detail in pairs(diagnostic_info) do
            local severity_to_use
            if detail[severities.ERROR] then
                severity_to_use = severities.ERROR
            elseif detail[severities.WARN] then
                severity_to_use = severities.WARN
            elseif detail[severities.INFO] then
                severity_to_use = severities.INFO
            elseif detail[severities.HINT] then
                severity_to_use = severities.HINT
            end

            local numbers = detail[severity_to_use]

            local ratio = (numbers.upper + numbers.lower) / number_of_lines_per_row

            local sign_index = 1

            for i = 1, number_of_signs - 1 do
                if ratio <= i * interval then
                    break
                end
                sign_index = sign_index + 1
            end

            local sign = diagnostics_config.signs[severities[severity_to_use]][sign_index]
            local option = {
                virt_text = {{sign, highlight_names[severity_to_use]}},
                virt_text_pos = "overlay",
                hl_mode = "combine",
                priority = diagnostics_config.priority
            }

            coordinate_option_table[coordinate] = option
        end
    end

    return coordinate_option_table
end

return M
