local api = vim.api
local display = require('scrlbkun.display')
local states = require('scrlbkun.states')
local util = require('scrlbkun.util')

local M = {}

function M:clear(window_id)
    local s = states.states[window_id]

    if (not s) or not s.display_buffer_number then
        return
    end

    api.nvim_buf_clear_namespace(s.display_buffer_number, self.namespace_id, 0, -1)
end

function M:draw(window_id)
    self:clear(window_id)

    local coordinate_option_table = self:calculate(window_id)

    local config = require('scrlbkun.config').get()

    for _, draw_column in ipairs(config[self.component_name].draw_columns) do
        if draw_column <= config.width then
            for coordinate, option in pairs(coordinate_option_table) do
                local hp_0based = draw_column - 1
                local ok, err = pcall(
                    api.nvim_buf_set_extmark,
                    states.states[window_id].display_buffer_number,
                    self.namespace_id,
                    coordinate,
                    hp_0based,
                    option
                )
                if not ok then
                    print(string.format('%s, %s, %d, %d, %s', "scrlbkun", self.component_name, coordinate, hp_0based, err))
                end
            end
        end
    end

end

function M.new(component_name, default_config, highlights)
    vim.validate({
        component_name = {component_name, "string"},
        default_config = {
            default_config,
            -- default_config must have the form of
            -- {
        --         enable = [boolean],
        --         draw_events = [table],
        --         ...
            -- }
            function (dc)
                if type(dc) ~= "table" then
                    return false
                end

                local enable = dc.enable
                local priority = dc.priority
                local draw_columns = dc.draw_columns
                local draw_events = dc.draw_events
                local draw_events_tab = dc.draw_events_tab
                if not (enable ~= nil and draw_events and draw_events_tab and priority) then
                    return false
                end

                return type(enable) == "boolean"
                    and type(draw_events) == "table"
                    and type(draw_events_tab) == "table"
                    and type(priority) == "number"
                    and type(draw_columns) == "table"
            end,
            "component config"
        },
        highlights = {highlights, "table"}
    })

    local component_namespace_prefix = "scrlbkun_"
    local obj = {
        component_name = component_name,
        namespace_id = api.nvim_create_namespace(
            component_namespace_prefix .. component_name
        ),
        default_config = default_config,
        highlights = highlights
    }
    return setmetatable(obj, {__index = M})
end

function M:execute(window_id)
    if not display.is_window_to_draw(window_id) then
        display.delete(window_id)
        return
    end

    if display.should_form_window(window_id) then
        display.form_window(window_id)
        self:draw(window_id)
    elseif display.should_form(window_id) then
        display.form(window_id)
        require('scrlbkun.components').draw_all(window_id)
    else
        self:draw(window_id)
    end

    if display.should_fadeout() then
        display.fadeout(window_id)
    end
end

function M:create_autocmd(is_enabled)
    local component_augroup_prefix = "_scrlbkun_draw_"
    local augroup_name = component_augroup_prefix .. self.component_name

    local group = api.nvim_create_augroup(augroup_name, {})

    if not is_enabled then
        return
    end

    local callback_for_single_window = function ()
        self:execute(api.nvim_get_current_win())
    end

    local config = require('scrlbkun.config').get()

    local component_name = self.component_name
    local draw_events = config[component_name].draw_events
    util.create_autocmd_wrapped(group, draw_events, callback_for_single_window)

    if config.single_window then
        -- Even events in draw_events_tab apply to the current window only
        local draw_events_tab = config[component_name].draw_events_tab
        util.create_autocmd_wrapped(group, draw_events_tab, callback_for_single_window)
    else
        local callback_for_multi_windows = function ()
            util.execute_on_all_windows_in_current_tab(function(window_id)
                self:execute(window_id)
            end)
        end

        local draw_events_tab = config[component_name].draw_events_tab
        util.create_autocmd_wrapped(group, draw_events_tab, callback_for_multi_windows)
    end
end

function M:set_highlights()
    for highlight_name, value in pairs(self.highlights) do
        api.nvim_set_hl(0, highlight_name, value)
    end
end

function M:init()
    local component_config = {
        [self.component_name] = self.default_config
    }
    local config = require('scrlbkun.config').set(component_config)

    self:set_highlights()

    local is_enabled = config[self.component_name].enable
    self:create_autocmd(is_enabled)
    if is_enabled then
        require('scrlbkun.components').add_to_enabled_components(self)
    end
end

function M:enable()
    require('scrlbkun.components').add_to_enabled_components(self)

    local config = require('scrlbkun.config').get()
    if config.single_window then
        self:execute(api.nvim_get_current_win())
    else
        util.execute_on_all_windows_in_current_tab(function(window_id)
            self:execute(window_id)
        end)
    end

    self:create_autocmd(true)
end

function M:disable()
    self:create_autocmd(false)

    for window_id, _ in pairs(states.states) do
        self:clear(window_id)
    end
    require('scrlbkun.components').remove_from_enabled_components(self)
end

return M
