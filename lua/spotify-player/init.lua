-- lua/spotify-player/init.lua
-- Main logic and commands for the spotify-player.nvim plugin.
-- This file is set up to work without needing a setup() call.

local M = {}

-- -----------------------------------------------------------------------------
-- Configuration Helpers
-- -----------------------------------------------------------------------------

-- Function to create a deep copy of a table, to avoid modifying the default configuration.
local function deepcopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = deepcopy(v)
        end
        copy[k] = v
    end
    return copy
end

-- Merges table 'b' into 'a', modifying 'a'.
local function deep_merge(a, b)
  for k, v in pairs(b) do
    if type(v) == "table" and type(a[k]) == "table" then
      deep_merge(a[k], v)
    else
      a[k] = v
    end
  end
  return a
end

-- -----------------------------------------------------------------------------
-- Default Configuration
-- -----------------------------------------------------------------------------
local defaults = {
  -- General settings
  backend = "auto",   -- "auto" (detects OS), "playerctl" (Linux), "osascript" (macOS), "windows" (Windows)
  player = "spotify", -- Player name for playerctl (e.g., "spotify", "spotifyd")
  interval_ms = 1000, -- Update interval in milliseconds

  -- Window appearance
  width = 45,        -- Width in columns
  height = 7,        -- Height in lines
  row_offset = 3,    -- Distance from the bottom edge of Neovim
  col_offset = 2,    -- Distance from the right edge of Neovim
  border = "rounded",-- Border style (see :help nvim_open_win)

  -- Icons (requires a Nerd Font)
  icons = {
    track = "🎵", artist = "👥", album = "💿",
    shuffle_on = "🔀", shuffle_off = "→",
    repeat_on = "🔁", repeat_off = "→",
    volume = "🔊", playing = "▶", paused = "⏸", stopped = "⏹",
    progress_indicator = "●", progress_filled = "─", progress_empty = "·",
  },

  -- Keymaps (set `enabled = true` in your setup to activate them)
  keymaps = {
    enabled = false,
    volume_up = "<leader>s+", volume_down = "<leader>s-",
    previous = "<leader>sP", next = "<leader>sn",
    play_pause = "<leader>sp", toggle_repeat = "<leader>sr",
    toggle_shuffle = "<leader>ss", toggle_widget = "<leader>st",
  },
}

-- The configuration is initialized with default values.
-- This allows the plugin to work without calling M.setup().
local cfg = deepcopy(defaults)

-- -----------------------------------------------------------------------------
-- Internal State
-- -----------------------------------------------------------------------------
M._buf = nil
M._win = nil
M._timer = nil

-- -----------------------------------------------------------------------------
-- Helper Functions
-- -----------------------------------------------------------------------------

-- Detects the appropriate backend based on OS or configuration.
local function detect_backend()
  if cfg.backend and cfg.backend ~= "auto" then
    return cfg.backend
  end
  if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 or (jit and jit.os == "OSX") then
    return "osascript"
  elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 or (jit and jit.os == "Windows") then
    return "windows"
  else
    return "playerctl"
  end
end

-- Executes a system command and returns the first line of the output.
local function safe_system(cmd)
  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or not output or vim.tbl_isempty(output) then
    return nil
  end
  return output[1]
end

-- Formats a seconds string to MM:SS format.
local function format_time(seconds_str)
  local sec = tonumber(seconds_str)
  if not sec or sec < 0 then return "00:00" end
  local mins = math.floor(sec / 60)
  local secs = math.floor(sec % 60)
  return string.format("%02d:%02d", mins, secs)
end

-- Centers text within a given width, considering wide characters (icons).
local function center_text(text, width)
    local text_len = vim.fn.strwidth(text)
    if text_len >= width then return text end
    local padding = math.floor((width - text_len) / 2)
    return string.rep(" ", padding) .. text .. string.rep(" ", width - text_len - padding)
end

-- -----------------------------------------------------------------------------
-- Backend: playerctl (Linux)
-- -----------------------------------------------------------------------------

local function playerctl_available()
  return vim.fn.executable("playerctl") == 1
end

local function get_playerctl_info()
  if not playerctl_available() then
    return nil, "Error: `playerctl` is not installed."
  end

  local player = cfg.player
  local status_cmd = string.format("playerctl -p %s status 2>/dev/null", player)
  local status = safe_system(status_cmd)

  if not status then
    return nil, string.format("Player '%s' not active.", player)
  end

  return {
    status = status,
    title = safe_system(string.format("playerctl -p %s metadata --format '{{title}}'", player)),
    artist = safe_system(string.format("playerctl -p %s metadata --format '{{artist}}'", player)),
    album = safe_system(string.format("playerctl -p %s metadata --format '{{album}}'", player)),
    position = safe_system(string.format("playerctl -p %s position", player)),
    length = safe_system(string.format("playerctl -p %s metadata --format '{{mpris:length}}'", player)),
    shuffle = safe_system(string.format("playerctl -p %s shuffle", player)),
    loop = safe_system(string.format("playerctl -p %s loop", player)),
    volume = safe_system(string.format("playerctl -p %s volume", player)),
  }
end

local function run_playerctl_command(action)
  if not playerctl_available() then
    vim.notify("spotify-player: `playerctl` is not installed.", vim.log.levels.ERROR)
    return
  end
  if action == "play-pause" then
    vim.fn.system(string.format("playerctl -p %s play-pause", cfg.player))
  elseif action == "next" then
    vim.fn.system(string.format("playerctl -p %s next", cfg.player))
  elseif action == "previous" then
    vim.fn.system(string.format("playerctl -p %s previous", cfg.player))
  elseif action == "volume_up" then
    vim.fn.system(string.format("playerctl -p %s volume 0.05+", cfg.player))
  elseif action == "volume_down" then
    vim.fn.system(string.format("playerctl -p %s volume 0.05-", cfg.player))
  elseif action == "toggle_shuffle" then
    vim.fn.system(string.format("playerctl -p %s shuffle Toggle", cfg.player))
  elseif action == "toggle_repeat" then
    local current_loop = safe_system(string.format("playerctl -p %s loop", cfg.player))
    if current_loop == "None" then
      vim.fn.system(string.format("playerctl -p %s loop Playlist", cfg.player))
    elseif current_loop == "Playlist" then
      vim.fn.system(string.format("playerctl -p %s loop Track", cfg.player))
    else
      vim.fn.system(string.format("playerctl -p %s loop None", cfg.player))
    end
  end
end

-- -----------------------------------------------------------------------------
-- Backend: osascript (macOS)
-- -----------------------------------------------------------------------------

local function osascript_available()
  return vim.fn.executable("osascript") == 1
end

local function get_osascript_info()
  if not osascript_available() then
    return nil, "Error: `osascript` is not available on this system."
  end

  local script = [[
    if application "Spotify" is running then
      tell application "Spotify"
        set s_state to player state as string
        set s_title to name of current track
        set s_artist to artist of current track
        set s_album to album of current track
        set s_pos to player position as string
        set s_dur to ((duration of current track) / 1000) as string
        set s_shuf to shuffling as string
        set s_rep to repeating as string
        set s_vol to ((sound volume as real) / 100) as string
        return s_state & "<!#sep#!>" & s_title & "<!#sep#!>" & s_artist & "<!#sep#!>" & s_album & "<!#sep#!>" & s_pos & "<!#sep#!>" & s_dur & "<!#sep#!>" & s_shuf & "<!#sep#!>" & s_rep & "<!#sep#!>" & s_vol
      end tell
    else
      return "NOT_RUNNING"
    end if
  ]]

  local output = safe_system({ "osascript", "-e", script })
  if not output or output == "NOT_RUNNING" then
    return nil, "Player 'Spotify' not active."
  end

  local parts = vim.split(output, "<!#sep#!>", { plain = true })
  if #parts < 9 then
    return nil, "Could not parse Spotify status."
  end

  local dur_sec = tonumber(parts[6]) or 0

  return {
    status = parts[1],
    title = parts[2],
    artist = parts[3],
    album = parts[4],
    position = parts[5],
    length = tostring(math.floor(dur_sec * 1000000)),
    shuffle = (parts[7] == "true") and "On" or "Off",
    loop = (parts[8] == "true") and "Playlist" or "None",
    volume = parts[9],
  }
end

local function run_osascript_command(action)
  if not osascript_available() then
    vim.notify("spotify-player: `osascript` is not available.", vim.log.levels.ERROR)
    return
  end
  local script = nil
  if action == "play-pause" then
    script = 'tell application "Spotify" to playpause'
  elseif action == "next" then
    script = 'tell application "Spotify" to next track'
  elseif action == "previous" then
    script = 'tell application "Spotify" to previous track'
  elseif action == "volume_up" then
    script = 'tell application "Spotify" to set sound volume to (sound volume + 5)'
  elseif action == "volume_down" then
    script = 'tell application "Spotify" to set sound volume to (sound volume - 5)'
  elseif action == "toggle_shuffle" then
    script = 'tell application "Spotify" to set shuffling to not shuffling'
  elseif action == "toggle_repeat" then
    script = 'tell application "Spotify" to set repeating to not repeating'
  end
  if script then
    vim.fn.system({ "osascript", "-e", script })
  end
end

-- -----------------------------------------------------------------------------
-- Backend: Windows (PowerShell / SMTC & Media Keys)
-- -----------------------------------------------------------------------------

local function get_powershell_cmd()
  if vim.fn.executable("powershell.exe") == 1 then
    return "powershell.exe"
  elseif vim.fn.executable("powershell") == 1 then
    return "powershell"
  elseif vim.fn.executable("pwsh") == 1 then
    return "pwsh"
  end
  return nil
end

local function get_windows_info()
  local ps = get_powershell_cmd()
  if not ps then
    return nil, "Error: PowerShell is not available."
  end

  local script = [=[
    $ErrorActionPreference = 'SilentlyContinue'
    try {
      [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media,ContentType=WindowsRuntime] > $null
      $mgrOp = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
      $mgrOp.AsTask().Wait(400)
      $mgr = $mgrOp.GetResults()
      $s = $mgr.GetCurrentSession()
      if ($s -and $s.SourceAppUserModelId -like '*Spotify*') {
        $pOp = $s.TryGetMediaPropertiesAsync()
        $pOp.AsTask().Wait(400)
        $p = $pOp.GetResults()
        $tl = $s.GetTimelineProperties()
        $st = $s.GetPlaybackInfo().PlaybackStatus.ToString()
        $pos = [math]::Round($tl.Position.TotalSeconds)
        $dur = [math]::Round($tl.EndTime.TotalSeconds)
        Write-Output "$st<!#sep#!>$($p.Title)<!#sep#!>$($p.Artist)<!#sep#!>$($p.AlbumTitle)<!#sep#!>$pos<!#sep#!>$dur"
        exit 0
      }
    } catch {}
    $proc = Get-Process spotify | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
    if (-not $proc) {
      Write-Output "NOT_RUNNING"
      exit 0
    }
    $title = $proc.MainWindowTitle
    if ($title -match '^Spotify') {
      Write-Output "Paused<!#sep#!>Spotify<!#sep#!>Paused<!#sep#!><!#sep#!>0<!#sep#!>0"
    } else {
      $idx = $title.IndexOf(' - ')
      if ($idx -gt 0) {
        $artist = $title.Substring(0, $idx)
        $track = $title.Substring($idx + 3)
        Write-Output "Playing<!#sep#!>$track<!#sep#!>$artist<!#sep#!><!#sep#!>0<!#sep#!>0"
      } else {
        Write-Output "Playing<!#sep#!>$title<!#sep#!>Unknown<!#sep#!><!#sep#!>0<!#sep#!>0"
      }
    }
  ]=]

  local output = safe_system({ ps, "-NoProfile", "-NonInteractive", "-Command", script })
  if not output or output == "NOT_RUNNING" then
    return nil, "Player 'Spotify' not active."
  end

  local parts = vim.split(output, "<!#sep#!>", { plain = true })
  if #parts < 6 then
    return nil, "Could not parse Spotify status."
  end

  local dur_sec = tonumber(parts[6]) or 0

  return {
    status = parts[1] ~= "" and parts[1] or "Unknown",
    title = parts[2] ~= "" and parts[2] or "Unknown",
    artist = parts[3] ~= "" and parts[3] or "Unknown",
    album = parts[4] ~= "" and parts[4] or "Unknown",
    position = parts[5] or "0",
    length = tostring(math.floor(dur_sec * 1000000)),
    shuffle = "Off",
    loop = "None",
    volume = "1.0",
  }
end

local function run_windows_command(action)
  local ps = get_powershell_cmd()
  if not ps then
    vim.notify("spotify-player: PowerShell is not available.", vim.log.levels.ERROR)
    return
  end
  local key_code = nil
  if action == "play-pause" then
    key_code = 179 -- VK_MEDIA_PLAY_PAUSE
  elseif action == "next" then
    key_code = 176 -- VK_MEDIA_NEXT_TRACK
  elseif action == "previous" then
    key_code = 177 -- VK_MEDIA_PREV_TRACK
  elseif action == "volume_up" then
    key_code = 175 -- VK_VOLUME_UP
  elseif action == "volume_down" then
    key_code = 174 -- VK_VOLUME_DOWN
  elseif action == "toggle_shuffle" or action == "toggle_repeat" then
    vim.notify("spotify-player: Shuffle/Repeat toggling via media keys is not supported on Windows.", vim.log.levels.INFO)
    return
  end
  if key_code then
    local cmd = string.format("(New-Object -ComObject WScript.Shell).SendKeys([char]%d)", key_code)
    vim.fn.system({ ps, "-NoProfile", "-NonInteractive", "-Command", cmd })
  end
end

-- -----------------------------------------------------------------------------
-- Main Logic
-- -----------------------------------------------------------------------------

-- Gets all the necessary information from the player.
local function get_player_info()
  local backend = detect_backend()
  if backend == "osascript" then
    return get_osascript_info()
  elseif backend == "windows" then
    return get_windows_info()
  else
    return get_playerctl_info()
  end
end

-- Formats the player information into lines for the window.
local function format_content(info)
  if not info then return { "Player disconnected" } end

  local lines = {}
  local bar_width = cfg.width - 4 -- Width for the progress bar

  local status_icon = cfg.icons.stopped
  if info.status:lower():find("play") then status_icon = cfg.icons.playing end
  if info.status:lower():find("pause") then status_icon = cfg.icons.paused end

  local shuffle_icon = (info.shuffle == "On") and cfg.icons.shuffle_on or cfg.icons.shuffle_off
  local repeat_icon = (info.loop ~= "None") and cfg.icons.repeat_on or cfg.icons.repeat_off

  lines[1] = string.format(" %s  %s", cfg.icons.track, info.title or "Unknown")
  lines[2] = string.format(" %s  %s", cfg.icons.artist, info.artist or "Unknown")
  lines[3] = string.format(" %s  %s", cfg.icons.album, info.album or "Unknown")
  lines[4] = "" -- Blank line

  local volume_pct = math.floor((tonumber(info.volume) or 0) * 100)
  local controls_line = string.format("%s   %s   %s   %s %d%%", shuffle_icon, repeat_icon, status_icon, cfg.icons.volume, volume_pct)
  lines[5] = center_text(controls_line, bar_width + 2)

  local pos_s = tonumber(info.position) or 0
  local len_s = (tonumber(info.length) or 0) / 1000000 -- length is in microseconds
  local time_str = string.format("%s / %s", format_time(pos_s), format_time(len_s))
  
  local progress_pct = 0
  if len_s > 0 then progress_pct = (pos_s / len_s) end

  local indicator_pos = math.floor(bar_width * progress_pct)
  local progress_bar = ""
  for i = 1, bar_width do
    if i == indicator_pos then progress_bar = progress_bar .. cfg.icons.progress_indicator
    elseif i < indicator_pos then progress_bar = progress_bar .. cfg.icons.progress_filled
    else progress_bar = progress_bar .. cfg.icons.progress_empty end
  end
  lines[6] = " " .. progress_bar .. " "
  lines[7] = center_text(time_str, bar_width + 2)

  return lines
end

-- Updates the window content once.
local function update_once()
  if not M._buf or not vim.api.nvim_buf_is_valid(M._buf) then return end

  local info, err = get_player_info()
  local lines
  if not info then
    lines = { center_text(err, cfg.width - 2) }
  else
    lines = format_content(info)
  end

  vim.api.nvim_buf_set_option(M._buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M._buf, "modifiable", false)
end

-- -----------------------------------------------------------------------------
-- Window and Timer Management
-- -----------------------------------------------------------------------------

local function make_buffer()
  if M._buf and vim.api.nvim_buf_is_valid(M._buf) then return end
  M._buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M._buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M._buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(M._buf, "swapfile", false)
end

local function open_window()
  if M._win and vim.api.nvim_win_is_valid(M._win) then return end
  make_buffer()
  local width = math.min(cfg.width, vim.o.columns - 2)
  local height = math.min(cfg.height, vim.o.lines - 2)
  local row = vim.o.lines - height - cfg.row_offset
  local col = vim.o.columns - width - cfg.col_offset
  local opts = {
    style = "minimal", relative = "editor", width = width,
    height = height, row = row, col = col,
    border = cfg.border, noautocmd = true,
  }
  M._win = vim.api.nvim_open_win(M._buf, false, opts)
  vim.api.nvim_win_set_option(M._win, "winblend", 0)
  vim.api.nvim_win_set_option(M._win, "cursorline", false)
  vim.api.nvim_win_set_option(M._win, "wrap", false)
  local keymap_opts = { buffer = M._buf, silent = true }
  vim.keymap.set("n", "q", M.toggle, keymap_opts)
  vim.keymap.set("n", "<Esc>", M.toggle, keymap_opts)
end

local function close_window()
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    pcall(vim.api.nvim_win_close, M._win, true)
    M._win = nil
  end
end

local function stop_timer()
  if M._timer then
    pcall(function() M._timer:stop() end)
    pcall(function() M._timer:close() end)
    M._timer = nil
  end
end

local function start_timer()
  if M._timer and not M._timer:is_closing() then return end
  M._timer = vim.loop.new_timer()
  M._timer:start(0, cfg.interval_ms, vim.schedule_wrap(update_once))
end

-- -----------------------------------------------------------------------------
-- Public API and Commands
-- -----------------------------------------------------------------------------

-- Function to toggle the floating window.
function M.toggle()
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    stop_timer()
    close_window()
  else
    open_window()
    start_timer()
  end
end

-- Generic function to send commands to the player.
local function run_command(action)
  local backend = detect_backend()
  if backend == "osascript" then
    run_osascript_command(action)
  elseif backend == "windows" then
    run_windows_command(action)
  else
    run_playerctl_command(action)
  end

  if M._win and vim.api.nvim_win_is_valid(M._win) then
    vim.schedule(update_once)
  end
end

-- Handler for the :Spotify command.
function M.handler(args)
    local action = args.fargs[1]
    if not action or action == "" then
        run_command("play-pause")
    elseif action == "next" then
        run_command("next")
    elseif action == "previous" then
        run_command("previous")
    elseif action == "volume_up" then
        run_command("volume_up")
    elseif action == "volume_down" then
        run_command("volume_down")
    elseif action == "toggle_shuffle" then
        run_command("toggle_shuffle")
    elseif action == "toggle_repeat" then
        run_command("toggle_repeat")
    else
        vim.notify("spotify-player: Unknown command '" .. action .. "'", vim.log.levels.WARN)
    end
end

-- Sets up the keymaps defined in the configuration.
local function setup_keymaps()
  if not cfg.keymaps.enabled then return end
  local map = vim.keymap.set
  local opts = { noremap = true, silent = true, desc = "Control Spotify" }
  map("n", cfg.keymaps.toggle_widget, M.toggle, { noremap = true, silent = true, desc = "Toggle Spotify Player" })
  map("n", cfg.keymaps.play_pause, function() M.handler({ fargs = { "" } }) end, opts)
  map("n", cfg.keymaps.next, function() M.handler({ fargs = { "next" } }) end, opts)
  map("n", cfg.keymaps.previous, function() M.handler({ fargs = { "previous" } }) end, opts)
  map("n", cfg.keymaps.volume_up, function() M.handler({ fargs = { "volume_up" } }) end, opts)
  map("n", cfg.keymaps.volume_down, function() M.handler({ fargs = { "volume_down" } }) end, opts)
  map("n", cfg.keymaps.toggle_shuffle, function() M.handler({ fargs = { "toggle_shuffle" } }) end, opts)
  map("n", cfg.keymaps.toggle_repeat, function() M.handler({ fargs = { "toggle_repeat" } }) end, opts)
end

-- Main setup function (optional).
function M.setup(opts)
  -- Merges user options with the current configuration.
  deep_merge(cfg, opts or {})
  setup_keymaps()
end

-- -----------------------------------------------------------------------------
-- Neovim Command Creation
-- -----------------------------------------------------------------------------
-- They are created here so the plugin works without a `plugin/` file.

-- :Spotify command that accepts arguments
vim.api.nvim_create_user_command("Spotify", function(args)
  M.handler(args)
end, {
    nargs = "?", -- Accepts 0 or 1 argument
    complete = function()
        return { "next", "previous", "volume_up", "volume_down", "toggle_shuffle", "toggle_repeat" }
    end,
    desc = "Control Spotify (play-pause, next, previous, etc.)"
})

-- Command to toggle the widget
vim.api.nvim_create_user_command("SpotifyToggle", function()
  M.toggle()
end, {
  desc = "Shows/Hides the Spotify status window",
})

-- Cleanup on Neovim exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    stop_timer()
    close_window()
  end,
})

return M
