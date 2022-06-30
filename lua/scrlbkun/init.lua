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
    api.nvim_create_autocmd({"WinScrolled"}, {
        group = group_form,
        callback = form_callback
    })


    if config.single_window then
        local hide_events = config.hide_events
        if hide_events and #hide_events > 0 then
            local group_hide = api.nvim_create_augroup("_ScrlbkunHide", {})

            api.nvim_create_autocmd(hide_events, {
                group = group_hide,
                callback = function()
                    display.hide(api.nvim_get_current_win())
                end
            })
        end
    end


    local delete_events = config.delete_events
    if delete_events and #delete_events > 0 then
        local group_delete = api.nvim_create_augroup("_ScrlbkunDelete", {})

        api.nvim_create_autocmd(delete_events, {
            group = group_delete,
            callback = function()
                display.delete(api.nvim_get_current_win())
            end
        })
    end

end

M.setup = setup

return M
