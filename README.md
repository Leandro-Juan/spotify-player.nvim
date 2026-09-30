# 🎵 spotify-player.nvim

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**spotify-player.nvim** is a lightweight and elegant plugin for **Neovim** that displays the current playback status of Spotify (or another player compatible with `playerctl`) and allows you to control it without leaving the editor.



---

## Screenshot / Image
<img width="707" height="281" alt="screenshot" src="https://github.com/user-attachments/assets/bd08b8e5-88e0-4c90-b7ff-6c68fa94b9b3" />



<img width="1920" height="1080" alt="screenshot2" src="https://github.com/user-attachments/assets/3aff731a-9ae0-4482-bf55-dfbd69bbc6a2" />

---

## Table of Contents

- [Features](#features)
- [Screenshot / Image](#screenshot--image)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Commands](#commands)
  - [Available Actions](#available-actions)
  - [Shortcuts / Keymaps](#shortcuts--keymaps)
- [Configuration](#configuration)
- [Contribute](#contribute)
- [Acknowledgments](#acknowledgments)
- [License](#license)

---

## Features

- Floating window displaying the current song, artist, and album.
- Built-in controls: `Play/Pause`, `Next/Previous`, `Volume`, `Shuffle`, and `Repeat`.
- Visual progress bar and playback time.
- Highly configurable.
- Very lightweight — only one external dependency: `playerctl` (Linux).

---

## Requirements

- **Linux**
- **Neovim** `v0.7+`
- **playerctl** — command line utility to control media players (Spotify, mpv, etc.) via MPRIS:
  - Debian/Ubuntu: `sudo apt install playerctl`
  - Arch Linux: `sudo pacman -S playerctl`
  - Fedora: `sudo dnf install playerctl`
- A **Nerd Font** installed and configured in your terminal to display icons correctly (optional, but recommended).

> **Note:** macOS and Windows are currently not supported as `playerctl` relies on the Linux MPRIS D-Bus interface.

---

## Installation

Install the plugin with your favorite plugin manager. Example with `lazy.nvim`:

```lua
-- lua/plugins/spotify.lua
return {
  {
    "Leandro-Juan/spotify-player.nvim",
    opts = {
      -- You can add your custom options here if you want
    },
    -- optional lazy-loading:
    cmd = { "SpotifyToggle", "Spotify" },
  }
}
```

---

## Usage

### Commands

- `:SpotifyToggle` — Show or hide the player window.
- `:Spotify [action]` — Control the player. If `action` is not specified, toggle `play/pause`.

### Available Actions

- `next`
- `previous`
- `volume_up`
- `volume_down`
- `toggle_shuffle`
- `toggle_repeat`

Example from the Neovim command line:

```vim
:Spotify
:Spotify next
:Spotify volume_up
```

### Shortcuts / Keymaps

There are two ways to enable shortcuts:

**1. Automatic mode** — activate from the options (see configuration below):

```lua
require("spotify-player").setup({
  keymaps = {
    enabled = true,
  }
})
```

**2. Manual mode** — define your own shortcuts:

```lua
local spotify = require("spotify-player")

-- Normal mode
vim.keymap.set("n", "<leader>st", spotify.toggle, { desc = "Toggle Spotify Player" })
vim.keymap.set("n", "<leader>sn", function() vim.cmd("Spotify next") end, { desc = "Spotify Next" })
vim.keymap.set("n", "<leader>sp", function() vim.cmd("Spotify previous") end, { desc = "Spotify Previous" })
vim.keymap.set("n", "<leader>sv+", function() vim.cmd("Spotify volume_up") end, { desc = "Spotify Vol +" })
vim.keymap.set("n", "<leader>sv-", function() vim.cmd("Spotify volume_down") end, { desc = "Spotify Vol -" })
```

> Adjust the keys `<leader>st`, etc., to your liking.

---

## Configuration

The plugin is configured by calling `setup()` and passing a table with options. Basic example with default options:

```lua
-- lua/plugins/spotify.lua or in your init.lua
require("spotify-player").setup({
  -- General settings
  player = "spotify",       -- Player name for playerctl (e.g., "spotify", "spotifyd")
  interval_ms = 1000,       -- Update interval in milliseconds

  -- Window appearance
  width = 45,               -- Width in columns
  height = 7,               -- Height in lines
  row_offset = 3,           -- Distance from the bottom edge of Neovim
  col_offset = 2,           -- Distance from the right edge of Neovim
  border = "rounded",       -- Border style (see :help nvim_open_win)

  -- Icons (requires a Nerd Font)
  icons = {
    track = "🎵",
    artist = "👥",
    album = "💿",
    shuffle_on = "🔀",
    shuffle_off = "→",
    repeat_on = "🔁",
    repeat_off = "→",
    volume = "🔊",
    playing = "▶",
    paused = "⏸",
    stopped = "⏹",
    progress_indicator = "●",
    progress_filled = "─",
    progress_empty = "·",
  },

  -- Keymaps
  keymaps = {
    enabled = false,        -- Set to true to enable default shortcuts
    volume_up = "<leader>s+",
    volume_down = "<leader>s-",
    previous = "<leader>sP",
    next = "<leader>sn",
    play_pause = "<leader>sp",
    toggle_repeat = "<leader>sr",
    toggle_shuffle = "<leader>ss",
    toggle_widget = "<leader>st",
  },
})
```

---

## Contribute

Contributions are welcome! If you want to collaborate:

1. Fork the repository.
2. Create a new branch: `git checkout -b feat/my-change`.
3. Make your changes and add tests/examples if applicable.
4. Open a Pull Request clearly describing the changes.

Suggestions welcome: UI improvements (progress bar, layout), support for more players / OS backends (such as macOS AppleScript support), and more configurable shortcuts.

---

## Acknowledgments

This project is inspired by ideas from `stsewd/spotify.nvim`. Many thanks to the author for the inspiration and ideas.

---

## License

**MIT** license — see `LICENSE` in the repository.
