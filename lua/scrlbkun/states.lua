local M = {}

local states = {}

-- for metatable
local state_methods = {
    clear_timer = function(self)
        if self.timer then
            self.timer:stop()
            self.timer:close()
            self.timer = nil
        end
    end
}

local function new_state(
        display_buffer_number,
        number_of_lines_in_display_buffer,
        display_window_id,
        horizontal_offset_of_display_window,
        timer
    )

    local state = {
        display_buffer_number = display_buffer_number,
        number_of_lines_in_display_buffer = number_of_lines_in_display_buffer,
        display_window_id = display_window_id,
        horizontal_offset_of_display_window = horizontal_offset_of_display_window,
        timer = timer
    }

    return setmetatable(state, {__index = state_methods})
end

M.new_state = new_state
M.states = states

return M
