local ffi = require('ffi')
local util= require('scrlbkun.util')
local C = ffi.C
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
    draw_events = {},
    draw_events_tab = {"TextChanged", "TextChangedI", "TextChangedP", "CmdlineLeave", "TabEnter", "CmdlineChanged"},
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

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

-- The argument of ffi.cdef, C_char_u_VLA, C_regmatch_T, get_win_T, get_buf_T, and build_regmatch_T
-- are the codes obatained by mofifying the codes in
--     * https://github.com/kevinhwang91/nvim-hlslens/blob/main/lua/hlslens/wffi.lua
-- .
-- Origiinally under BSD 3-Clause lisence, https://github.com/kevinhwang91/nvim-hlslens/blob/main/LICENSE
--   Copyright (c) 2021, kevinhwang91
-- Relicensed under the MIT license, <TODO: url>
--   Copyright (c) 2022, kensyo

ffi.cdef([[
    typedef unsigned char char_u;
    typedef struct regprog regprog_T;

    typedef long linenr_T;
    typedef int colnr_T;

    typedef uint64_t proftime_T;

    typedef struct {
        linenr_T lnum;
        colnr_T col;
    } lpos_T;

    typedef struct {
        regprog_T *regprog;
        lpos_T startpos[10];
        lpos_T endpos[10];
        int rmm_ic;
        colnr_T rmm_maxcol;
    } regmmatch_T;

    typedef struct window_S win_T;
    typedef struct file_buffer buf_T;

    regprog_T *vim_regcomp(char_u *expr_arg, int re_flags);

    char_u *ml_get_buf(buf_T *buf, linenr_T lnum, bool will_change);

    int ignorecase(char_u *pat);

    long vim_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf, linenr_T lnum, colnr_T col,
        proftime_T *tm, int *timed_out);

    size_t strlen(const char *s);

    int curwin_col_off(void);

    typedef struct {} Error;
    buf_T *find_buffer_by_handle(int buffer, Error *err);
    win_T *find_window_by_handle(int window, Error *err);
]])

local C_char_u_VLA = ffi.typeof('char_u[?]')
local C_regmmatch_T = ffi.typeof('regmmatch_T')

local function get_win_T(window_id)
    -- local err = ffi.new('Error')
    local win_T = C.find_window_by_handle(window_id, nil)
    return win_T
end

local function get_buf_T(buffer_number)
    -- local err = ffi.new('Error')
    local buf_T = C.find_buffer_by_handle(buffer_number, nil)
    return buf_T
end

local function build_regmatch_T(pat)
    C_pattern = C_char_u_VLA(#pat + 1)
    ffi.copy(C_pattern, pat)

    local reg_prog = C.vim_regcomp(C_pattern, vim.o.magic and 1 or 0)
    if reg_prog == nil then
        return
    end
    local regm = C_regmmatch_T()
    regm.regprog = reg_prog
    regm.rmm_ic = C.ignorecase(C_pattern)
    regm.rmm_maxcol = 0
    return regm
end

----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

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
        local reg_match = build_regmatch_T(pattern)
        local win_T = get_win_T(window_id)
        local buf_T = get_buf_T(buffer_number)

        for line_number = 1, number_of_lines_in_buffer do
            if C.vim_regexec_multi(
                    reg_match,
                    win_T,
                    buf_T,
                    line_number,
                    0,
                    nil,
                    nil
                ) >= 1 then
                -- 0-based
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
