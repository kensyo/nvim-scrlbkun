-- default config
local config = {
    single_window = true,
    zindex = 10,
    winblend = 40,
    excluded_filetypes = {"NvimTree"},
    excluded_buftypes = {"prompt"},
    fadeout_time = 2000, -- milliseconds
    width = 3
}

local M = {}

M.set = function(another_config, is_overridden)
    if is_overridden then
        config = vim.tbl_deep_extend("force", config, another_config or {})
    else
        config = vim.tbl_deep_extend("keep", config, another_config or {})
    end
    return config
end

M.get = function()
    return config
end

return M
