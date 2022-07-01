# Scrlbkun

A scrollbar plugin for neovim.

## Overview

The plugin enables neovim to display the following components
at the right edge of windows.

* Scrollbar (mouse operation is not supported)
* Cursor position
* Positions of matched terms in the search mode
(the `'hlsearch'` option must be on)
* Positions of diagnostics results
* Positions of git hunks (requires [gitsigns](https://github.com/lewis6991/gitsigns.nvim))

Vim is not supported. It is available only to neovim.

## Preview
<!-- TODO: write -->

## Requirements

The plugin requires neovim >= 0.7.0

Switch `'hlsearch'` on to display search results

```vim
:set hlsearch
```

## Installation

You can install it in any way you like, just like any other plugin.

For example, if you use [vim-plug](https://github.com/junegunn/vim-plug),

```vim
Plug 'kensyo/nvim-scrlbkun'
```

Don't forget to install [gitsigns](https://github.com/lewis6991/gitsigns.nvim)
as well if you want to display git hunks.

## Setup

Invoke a setup function.

```lua
-- use the default configuration
require('scrlbkun').setup()
```  

If you use your own configuration,
pass a configuration table to the setup funciton
 like

```lua
require('scrlbkun').setup({
    single_window = false,
        cursor = {
            enable = false
    }
})
```

## Configuration

The default configuration is as follows.
<!-- TODO: write -->

```lua
{
    -- If you want to display scrollbars on multiple windows, set to false.
    -- If set to true, a scrollbar area comes out only on the current window.
    single_window = true,

    -- zindex of scrollbar areas.
    zindex = 10,

    -- winblend of scrollbar areas.
    winblend = 40,

    -- On these filetypes, any scrollbars don't come out.
    excluded_filetypes = {"NvimTree"},

    -- On these buftypes, any scrollbars don't come out.
    excluded_buftypes = {"prompt"},

    -- A scrollbar is hidden at these events.
    hide_events = {"WinLeave", "BufLeave", "BufWinLeave", "FocusLost"},

    -- A scrollbar area is deleted at these events.
    -- The difference between hide and delete is whether
    -- the buffer for display is deleted.
    delete_events = {"QuitPre"},

    -- Time until a scrollbar area is hidden. Specify in milliseconds.
    -- If set to 0, a scrollbar area isn't hidden over time.
    fadeout_time = 2000,

    -- bar component
    bar = {
        -- If set to true, the bar component is enabled.
        enable = true,

        -- The component is drawn at these events.
        draw_events = {"WinScrolled", "BufEnter", "FocusGained"},

        -- The component is drawn on all the windows in the current tabpage
        -- at these events. But if single_window is set to true, draw_events_tab
        -- is treated exactly the same as draw_events.
        draw_events_tab = {"VimResized", "TabEnter"},

        -- When components overlap, the one with the higher priority is drawn.
        -- Specify by positive integer.
        priority = 100,

        -- A sign for a scrollbar. It is recommended not to change it from
        -- the default empty symbol.
        sign = " ",

    },

    -- cursor component
    cursor = {
        -- The same as those of the bar component
        enable = true,
        draw_events = {"BufEnter", "FocusGained", "CursorMoved"},
        draw_events_tab = {"VimResized", "TabEnter"},
        priority = 150,

        -- Signs for a cursor. Specify in array. If you specify an array of n-elements,
        -- then the sign to be used is determined in n more levels depending on the
        -- cursor position.
        signs = {
            "▔",
            "━",
            "▁",
        },

        -- How to determin the sign to be used. "skip_first" or "normal"
        sign_arrangement = "skip_first"
    },

    -- search component
    search = {
        -- The same as those of the bar component
        enable = true,
        draw_events = {},
        draw_events_tab = {"TextChanged", "TextChangedI",
            "TextChangedP", "CmdlineLeave", "TabEnter", "CmdlineChanged"},
        priority = 500

        -- Signs for search results.
        -- If you specify an array of n-elements,
        -- then the sign to be used is determined in n more levels depending
        -- on the number of matched terms
        signs = {
            ".",
            ":",
        },

        -- If set to true, the 'signs' option is ignored and the plugin uses
        -- symbols and an algorithm that allow for just a little more detailed
        -- drawing.
        use_built_in_signs = true,
    },

    -- diagnostics component
    diagnostics = {
        -- The same as those of the bar component
        enable = true,
        draw_events = {},
        draw_events_tab = {"BufEnter", "DiagnosticChanged", "TabEnter"},
        priority = 300,

        -- Signs for diagnostics. 
        signs = {
            -- If you specify an array of n-elements,
            -- then the sign to be used is determined in n more levels depending
            -- on the number of errors {warns, infos, hints}.
            ERROR = {".", ":"},
            WARN = {".", ":"},
            INFO = {".", ":"},
            HINT = {".", ":"},
        },

        -- The same as that of the search component
        use_built_in_signs = true,
    }

    -- githunks component
    githunks = {
        -- The same as those of the bar component
        enable = true,
        draw_events = {},
        draw_events_tab = {"BufEnter", "TabEnter",
            "TextChanged", "TextChangedI", "TextChangedP"},
        priority = 200,

        -- Signs for githunks. 
        signs = {
            -- If you specify an array of n-elements,
            -- then the sign to be used is determined in n more levels depending
            -- on add {delete, change}-hunks length
            add = {"│"},
            delete = {"▸"},
            change = {"│"},
        },

        -- The same as that of the search component
        use_built_in_signs = false,
    },
}
```

## Highlighting

You can configure the following highlights.

* `ScrlbkunBar`
* `ScrlbkunCursor`
* `ScrlbkunSearch`
* `ScrlbkunDiagnosticsError`
* `ScrlbkunDiagnosticsWarn`
* `ScrlbkunDiagnosticsInfo`
* `ScrlbkunDiagnosticsHint`
* `ScrlbkunGithunksAdd`
* `ScrlbkunGithunksDelete`
* `ScrlbkunGithunksChange`

## Functions

Lua functions to switch between enable and disable are provided.

```lua
-- For enabling
require('scrlbkun.components').enable_all()

require('scrlbkun.components.bar').enable()
require('scrlbkun.components.cursor').enable()
require('scrlbkun.components.search').enable()
require('scrlbkun.components.diagnostics').enable()
require('scrlbkun.components.githunks').enable()

-- For disabling
require('scrlbkun.components').disable_all()

require('scrlbkun.components.bar').disable()
require('scrlbkun.components.cursor').disable()
require('scrlbkun.components.search').disable()
require('scrlbkun.components.diagnostics').disable()
require('scrlbkun.components.githunks').disable()
```

## Similar Plugins

* [satellite.nvim](https://github.com/lewis6991/satellite.nvim)
* [scrollbar.nvim](https://github.com/Xuyuanp/scrollbar.nvim)
* [nvim-scrollbar](https://github.com/petertriho/nvim-scrollbar)

They are helpful for implementing this plugin, too.

## LICENSE

The MIT License
