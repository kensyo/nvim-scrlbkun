local M = {}

local components = {
    require('scrlbkun.components.bar'),
    require('scrlbkun.components.search'),
    require('scrlbkun.components.diagnostics'),
    require('scrlbkun.components.cursor'),
}

local ok, _ = pcall(require, "gitsigns")
if ok then
    table.insert(components, require('scrlbkun.components.githunks'))
end

local enabled_components = {
}

local function init()
    for _, component in pairs(components) do
        component:init()
    end
end

local function draw_all(window_id)
    for _, component in pairs(enabled_components) do
        component:draw(window_id)
    end
end

local function add_to_enabled_components(component)
    if not enabled_components[component.component_name] then
        enabled_components[component.component_name] = component
    end
end

local function remove_from_enabled_components(component)
    if enabled_components[component.component_name] then
        enabled_components[component.component_name] = nil
    end
end

local function enable_all()
    for _, component in pairs(components) do
        component:enable()
    end
end

local function disable_all()
    for _, component in pairs(components) do
        component:disable()
    end
end

M.init = init
M.draw_all = draw_all
M.add_to_enabled_components = add_to_enabled_components
M.remove_from_enabled_components = remove_from_enabled_components
M.enable_all = enable_all
M.disable_all = disable_all
M.enabled_components = enabled_components

return M
