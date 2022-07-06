local api = vim.api
local display = require('scrlbkun.display')
local util = require('scrlbkun.util')

local M = {}

local function execute_for_winscrolled(window_id)
    if not display.is_window_to_draw(window_id) then
        display.delete(window_id)
        return
    end

    if display.should_form_window(window_id) then
        display.form_window(window_id)

        if display.should_fadeout() then
            display.fadeout(window_id)
        end
    elseif display.should_form(window_id) then
        display.form(window_id)
        require('scrlbkun.components').draw_all(window_id)

        if display.should_fadeout() then
            display.fadeout(window_id)
        end
    end

end

local function setup(user_config)
    local config = require('scrlbkun.config').set(user_config, true)

    require('scrlbkun.components').init()

    local group_form = api.nvim_create_augroup("_scrlbkun_form", {})
    local form_callback = config.single_window
        and function ()
                local window_id = api.nvim_get_current_win()
                execute_for_winscrolled(window_id)
            end
        or function ()
                util.execute_on_all_windows_in_current_tab(execute_for_winscrolled)
            end
    util.create_autocmd_wrapped(group_form, {"WinScrolled"}, form_callback)

    if config.single_window then
        local hide_events = config.hide_events
        local group_hide = api.nvim_create_augroup("_ScrlbkunHide", {})
        util.create_autocmd_wrapped(group_hide, hide_events, function ()
            display.hide(api.nvim_get_current_win())
        end)
    end

    local delete_events = config.delete_events
    local group_delete = api.nvim_create_augroup("_ScrlbkunDelete", {})
    util.create_autocmd_wrapped(group_delete, delete_events, function ()
        display.delete(api.nvim_get_current_win())
    end)
end

M.setup = setup

return M
