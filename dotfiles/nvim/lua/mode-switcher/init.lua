local M = {}

-- State file: stores the current mode
local state_file = vim.fn.stdpath("data") .. "/mode-switcher.json"

-- Available modes (experiment groups)
-- Populated at runtime by scanning lua/modes/
local available_modes = {}

-- Default mode if nothing is saved
local default_mode = "full-ide"

-- Get list of available modes from lua/modes/*.lua
function M.get_available_modes()
  if #available_modes > 0 then return available_modes end

  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes"
  local ok, files = pcall(vim.fn.readdir, modes_dir)
  if not ok then return {} end

  for _, file in ipairs(files) do
    if file:match("%.lua$") then
      local name = file:gsub("%.lua$", "")
      table.insert(available_modes, name)
    end
  end

  table.sort(available_modes)
  return available_modes
end

-- Load saved mode from disk
function M.load_mode()
  local f = io.open(state_file, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if ok and data and data.mode then
    -- Validate mode exists
    local modes = M.get_available_modes()
    for _, m in ipairs(modes) do
      if m == data.mode then return data.mode end
    end
  end
  return nil
end

-- List all modes in a buffer
function M.list_modes()
  local modes = M.get_available_modes()
  local current = M.get_mode()
  local lines = { "# Available Modes", "" }

  for _, mode in ipairs(modes) do
    local marker = mode == current and " (current)" or ""
    local modes_dir = vim.fn.stdpath("config") .. "/lua/modes"
    local f = io.open(modes_dir .. "/" .. mode .. ".lua", "r")
    local desc = ""
    local plugin_count = 0
    if f then
      local content = f:read("*a")
      f:close()
      if content then
        local first_line = content:match("^(.-)\n") or content
        desc = first_line:match("^%-%-%s*(.+)$") or ""
        for _ in content:gmatch('{ "%S+/%S+"') do
          plugin_count = plugin_count + 1
        end
      end
    end
    table.insert(lines, string.format("- **%s**%s (%d plugins)", mode, marker, plugin_count))
    if desc ~= "" then
      table.insert(lines, "  " .. desc)
    end
  end

  -- Open in a new buffer
  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Save mode to disk
function M.save_mode(mode)
  local f = io.open(state_file, "w")
  if not f then
    vim.notify("[mode-switcher] Failed to save state", vim.log.levels.ERROR)
    return false
  end

  local state = {
    mode = mode,
    timestamp = os.time(),
    hostname = vim.fn.hostname(),
  }
  f:write(vim.json.encode(state))
  f:close()

  vim.notify("[mode-switcher] Mode saved: " .. mode, vim.log.levels.INFO)
  return true
end

-- Get current mode (with fallback)
function M.get_mode()
  return M.load_mode() or default_mode
end

-- Switch mode via Telescope picker
function M.switch()
  local modes = M.get_available_modes()
  if #modes == 0 then
    vim.notify("[mode-switcher] No modes found in lua/modes/", vim.log.levels.WARN)
    return
  end

  local current = M.get_mode()

  -- Try Telescope first
  local ok, telescope = pcall(require, "telescope")
  if ok then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values

    pickers
      .new({
        prompt_title = "  Switch Mode",
        results_title = "Available Modes",
        layout_strategy = "cursor",
        layout_config = { width = 0.4, height = #modes + 4, prompt_position = "top" },
        border = true,
        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      }, {
        finder = finders.new_table({
          results = modes,
          entry_maker = function(entry)
            local is_current = entry == current
            local icon = is_current and " " or "  "
            local hl = is_current and "ModeSwitcherCurrent" or "ModeSwitcherNormal"

            -- Read description and plugin count from mode file
            local modes_dir = vim.fn.stdpath("config") .. "/lua/modes"
            local f = io.open(modes_dir .. "/" .. entry .. ".lua", "r")
            local desc = ""
            local plugin_count = 0
            if f then
              local content = f:read("*a")
              f:close()
              if content then
                -- Get first comment line
                local first_line = content:match("^(.-)\n") or content
                desc = first_line:match("^%-%-%s*(.+)$") or ""
                if #desc > 40 then desc = desc:sub(1, 37) .. "..." end
                -- Count plugins
                for _ in content:gmatch('{ "%S+/%S+"') do
                  plugin_count = plugin_count + 1
                end
              end
            end

            return {
              value = entry,
              display = string.format("%s %-20s %3d plugins  %s", icon, entry, plugin_count, desc),
              ordinal = entry,
              hl_group = hl,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(_, map)
          actions.select_default:replace(function(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            if selection then
              local new_mode = selection.value
              if new_mode == current then
                vim.notify("[mode-switcher] Already in mode: " .. new_mode, vim.log.levels.INFO)
                return
              end

              M.save_mode(new_mode)
              M._reload_mode(new_mode)
            end
          end)

          -- Preview mode info on <C-i>
          map("i", "<C-i>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              M._preview_mode(selection.value)
            end
          end)

          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select
    vim.ui.select(modes, {
      prompt = "  Switch Mode",
      format_item = function(item)
        local marker = item == current and " (current)" or ""
        return item .. marker
      end,
    }, function(choice)
      if choice and choice ~= current then
        M.save_mode(choice)
        M._reload_mode(choice)
      end
    end)
  end
end

-- Preview mode info (shows what plugins are in the mode)
function M._preview_mode(mode)
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes/" .. mode .. ".lua"
  local f = io.open(modes_dir, "r")
  if not f then
    vim.notify("[mode-switcher] Cannot read mode file: " .. mode, vim.log.levels.ERROR)
    return
  end

  local content = f:read("*a")
  f:close()

  -- Count plugins (lines with { "plugin/name" })
  local plugin_count = 0
  for _ in content:gmatch('{ "%S+/%S+"' ) do
    plugin_count = plugin_count + 1
  end

  -- Get first comment line (description)
  local desc = content:match("^%-%- (.+)$") or "No description"

  vim.notify(
    string.format("[mode-switcher] %s\n  Plugins: %d\n  Description: %s", mode, plugin_count, desc),
    vim.log.levels.INFO
  )
end

-- Reload mode: tell user to restart or run :Lazy sync
function M._reload_mode(mode)
  local msg = string.format(
    "Mode changed to: %s\n\nTo apply changes:\n  1. Restart Neovim, OR\n  2. Run :Lazy sync",
    mode
  )
  vim.notify("[mode-switcher] " .. msg, vim.log.levels.INFO, { timeout = 5000 })

  -- Auto-reload option: if user wants instant reload
  -- This is risky but works for most cases
  local choice = vim.fn.confirm("Reload now?", "&Yes\n&No (restart later)", 2)
  if choice == 1 then
    M._force_reload()
  end
end

-- Force reload: re-source the plugins/init.lua
function M._force_reload()
  -- Clear all loaded modules
  for name, _ in pairs(package.loaded) do
    if name:match("^modes%.") or name:match("^plugins%.") then
      package.loaded[name] = nil
    end
  end

  -- Re-run lazy.nvim setup
  vim.cmd("doautocmd User ModeSwitcherReload")
  vim.notify("[mode-switcher] Reloading plugins...", vim.log.levels.INFO)
end

-- Show current mode
function M.status()
  local mode = M.get_mode()
  local modes = M.get_available_modes()
  local timestamp = nil

  local f = io.open(state_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok and data and data.timestamp then
      timestamp = os.date("%Y-%m-%d %H:%M:%S", data.timestamp)
    end
  end

  local msg = string.format(
    "Current mode: %s\nAvailable: %s\nLast switched: %s",
    mode,
    table.concat(modes, ", "),
    timestamp or "never"
  )
  vim.notify("[mode-switcher]\n" .. msg, vim.log.levels.INFO, { timeout = 5000 })
end

-- Cycle through modes (next/prev)
function M.cycle(direction)
  local modes = M.get_available_modes()
  local current = M.get_mode()
  local current_idx = 1

  for i, m in ipairs(modes) do
    if m == current then
      current_idx = i
      break
    end
  end

  local next_idx
  if direction == "next" then
    next_idx = (current_idx % #modes) + 1
  else
    next_idx = ((current_idx - 2) % #modes) + 1
  end

  local new_mode = modes[next_idx]
  M.save_mode(new_mode)
  vim.notify("[mode-switcher] Mode: " .. current .. " → " .. new_mode, vim.log.levels.INFO)
end

-- Quick switch: directly set mode without picker
function M.set(mode)
  local modes = M.get_available_modes()
  for _, m in ipairs(modes) do
    if m == mode then
      local current = M.get_mode()
      if current == mode then
        vim.notify("[mode-switcher] Already in mode: " .. mode, vim.log.levels.INFO)
        return
      end
      M.save_mode(mode)
      vim.notify("[mode-switcher] Mode: " .. current .. " → " .. mode, vim.log.levels.INFO)
      return
    end
  end
  vim.notify("[mode-switcher] Unknown mode: " .. mode, vim.log.levels.ERROR)
end

-- Setup: create commands and keymaps
function M.setup(opts)
  opts = opts or {}
  default_mode = opts.default_mode or "full-ide"

  -- Commands
  vim.api.nvim_create_user_command("ModeSwitch", function() M.switch() end, { desc = "Switch experiment mode" })
  vim.api.nvim_create_user_command("ModeStatus", function() M.status() end, { desc = "Show current mode" })
  vim.api.nvim_create_user_command("ModeSet", function(a)
    if a.args == "" then
      vim.notify("[mode-switcher] Usage: :ModeSet <mode>", vim.log.levels.WARN)
      return
    end
    M.set(a.args)
  end, { desc = "Set mode directly", nargs = 1 })
  vim.api.nvim_create_user_command("ModeList", function() M.list_modes() end, { desc = "List all modes" })

  -- Keymaps
  vim.keymap.set("n", "<leader>ms", M.switch, { desc = "  Switch mode" })
  vim.keymap.set("n", "<leader>mn", function() M.cycle("next") end, { desc = "  Next mode" })
  vim.keymap.set("n", "<leader>mp", function() M.cycle("prev") end, { desc = "  Prev mode" })
  vim.keymap.set("n", "<leader>mi", M.status, { desc = "  Mode info" })

  -- Highlight for current mode in telescope
  vim.api.nvim_set_hl(0, "ModeSwitcherCurrent", { fg = "#7aa2f7", bold = true })
  vim.api.nvim_set_hl(0, "ModeSwitcherNormal", { fg = "#a6accd" })

  -- Ensure state directory exists
  local state_dir = vim.fn.fnamemodify(state_file, ":h")
  if vim.fn.isdirectory(state_dir) == 0 then
    vim.fn.mkdir(state_dir, "p")
  end
end

return M
