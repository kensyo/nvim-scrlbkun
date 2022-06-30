# Scrlbkun

A scrollbar plugin for neovim.

## Overview

The plugin enables neovim to display the followings at the right edge of windows.

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

Switch `'hlsearch'` on to display the results of search,

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
    -- If set to true, a scrollbar comes out only on the current window.
    single_window = true,

    -- zindex of scrollbar areas.
    zindex = 10,

    -- winblend of scrollbar areas.
    winblend = 40,

    -- On these filetypes, any scrollbars don't come out.
    excluded_filetypes = {"NvimTree"},

    -- On these buftypes, any scrollbars don't come out.
    excluded_buftypes = {"prompt"},

    -- A scrollbar is hidden on these events.
    hide_events = {"WinLeave", "BufLeave", "BufWinLeave", "FocusLost"},

    -- A scrollbar is deleted on these events.
    -- The difference between hide and delete is whether
    -- the buffer for display is deleted.
    delete_events = {"QuitPre"},

    -- Time until a scrollbar is hidden. Specify in milliseconds.
    -- If set to 0, a scrollbar isn't hidden over time.
    fadeout_time = 2000,

    cursor = {
    },

    bar = {
    },

    diagnostics = {
    },

    githunks = {
    },

    search = {
    }
}
```

See the help for more details.

### Highlighting

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

<!-- TODO: write -->

## Similar Plugins
<!-- TODO: write -->

## LICENSE

The MIT License
