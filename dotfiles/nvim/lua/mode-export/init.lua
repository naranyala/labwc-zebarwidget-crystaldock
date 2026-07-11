-- ═══════════════════════════════════════════════════════════════
-- Mode Export/Import: share mode configs with others
-- Export mode to clipboard/file, import from JSON
-- ═══════════════════════════════════════════════════════════════
local M = {}

-- Get plugins from a mode
local function get_mode_plugins(mode_name)
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes/" .. mode_name .. ".lua"
  local f = io.open(modes_dir, "r")
  if not f then return nil end

  local content = f:read("*a")
  f:close()

  local plugins = {}
  for plugin_name in content:gmatch('{ "(%S+/%S+)"') do
    table.insert(plugins, plugin_name)
  end

  return plugins
end

-- Export mode to JSON
function M.export_mode(mode_name, format)
  local plugins = get_mode_plugins(mode_name)
  if not plugins then
    vim.notify("[mode-export] Mode not found: " .. mode_name, vim.log.levels.ERROR)
    return
  end

  local data = {
    name = mode_name,
    plugins = plugins,
    exported_at = os.date("%Y-%m-%dT%H:%M:%S"),
    exported_by = vim.fn.hostname(),
  }

  local json = vim.json.encode(data)

  if format == "clipboard" then
    vim.fn.setreg("+", json)
    vim.notify("[mode-export] Copied to clipboard", vim.log.levels.INFO)
  elseif format == "file" then
    local filename = vim.fn.expand("~") .. "/mode-" .. mode_name .. ".json"
    local f = io.open(filename, "w")
    if f then
      f:write(json)
      f:close()
      vim.notify("[mode-export] Exported to: " .. filename, vim.log.levels.INFO)
    end
  else
    -- Print to messages
    vim.notify("[mode-export] " .. json, vim.log.levels.INFO)
  end

  return json
end

-- Export mode as a Neovim config file
function M.export_as_config(mode_name)
  local plugins = get_mode_plugins(mode_name)
  if not plugins then
    vim.notify("[mode-export] Mode not found: " .. mode_name, vim.log.levels.ERROR)
    return
  end

  local lines = {
    "-- ═══════════════════════════════════════════════════════════════",
    "-- Exported Mode: " .. mode_name,
    "-- Exported at: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "-- ═══════════════════════════════════════════════════════════════",
    "",
    "return {",
  }

  for _, plugin in ipairs(plugins) do
    table.insert(lines, string.format('  { "%s" },', plugin))
  end

  table.insert(lines, "}")
  table.insert(lines, "")

  local content = table.concat(lines, "\n")

  -- Copy to clipboard
  vim.fn.setreg("+", content)
  vim.notify("[mode-export] Config copied to clipboard", vim.log.levels.INFO)

  return content
end

-- Import mode from JSON
function M.import_mode(json_string, mode_name)
  local ok, data = pcall(vim.json.decode, json_string)
  if not ok then
    vim.notify("[mode-export] Invalid JSON", vim.log.levels.ERROR)
    return false
  end

  mode_name = mode_name or data.name
  if not mode_name then
    vim.notify("[mode-export] No mode name specified", vim.log.levels.ERROR)
    return false
  end

  -- Create mode file
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes"
  local mode_file = modes_dir .. "/" .. mode_name .. ".lua"

  local lines = {
    "-- ═══════════════════════════════════════════════════════════════",
    "-- Group: " .. mode_name,
    "-- Imported at: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "-- ═══════════════════════════════════════════════════════════════",
    "return {",
  }

  for _, plugin in ipairs(data.plugins or {}) do
    table.insert(lines, string.format('  { "%s" },', plugin))
  end

  table.insert(lines, "}")

  local f = io.open(mode_file, "w")
  if f then
    f:write(table.concat(lines, "\n"))
    f:close()
    vim.notify("[mode-export] Imported mode: " .. mode_name, vim.log.levels.INFO)
    return true
  else
    vim.notify("[mode-export] Failed to write mode file", vim.log.levels.ERROR)
    return false
  end
end

-- Import from clipboard
function M.import_from_clipboard(mode_name)
  local json = vim.fn.getreg("+")
  if json == "" then
    vim.notify("[mode-export] Clipboard is empty", vim.log.levels.WARN)
    return false
  end
  return M.import_mode(json, mode_name)
end

-- Import from file
function M.import_from_file(filepath, mode_name)
  local f = io.open(filepath, "r")
  if not f then
    vim.notify("[mode-export] File not found: " .. filepath, vim.log.levels.ERROR)
    return false
  end
  local content = f:read("*a")
  f:close()
  return M.import_mode(content, mode_name)
end

-- Show mode as formatted text (for sharing)
function M.show_mode(mode_name)
  local plugins = get_mode_plugins(mode_name)
  if not plugins then
    vim.notify("[mode-export] Mode not found: " .. mode_name, vim.log.levels.ERROR)
    return
  end

  local lines = {
    "Mode: " .. mode_name,
    "Plugins (" .. #plugins .. "):",
    "",
  }

  for _, plugin in ipairs(plugins) do
    table.insert(lines, "- " .. plugin)
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
  vim.keymap.set("n", "<leader>y", function()
    vim.cmd("%yank +")
    vim.notify("[mode-export] Copied to clipboard", vim.log.levels.INFO)
  end, { buffer = 0, desc = "Copy to clipboard" })
end

-- Setup
function M.setup()
  vim.api.nvim_create_user_command("ModeExport", function(a)
    local args = vim.split(a.args, " ")
    local format = #args > 1 and args[2] or "message"
    M.export_mode(args[1], format)
  end, { desc = "Export mode", nargs = "+" })

  vim.api.nvim_create_user_command("ModeExportConfig", function(a)
    M.export_as_config(a.args)
  end, { desc = "Export as config", nargs = 1 })

  vim.api.nvim_create_user_command("ModeImport", function(a)
    M.import_from_clipboard(a.args ~= "" and a.args or nil)
  end, { desc = "Import from clipboard", nargs = "?" })

  vim.api.nvim_create_user_command("ModeImportFile", function(a)
    local args = vim.split(a.args, " ")
    M.import_from_file(args[1], args[2])
  end, { desc = "Import from file", nargs = "+" })

  vim.api.nvim_create_user_command("ModeShow", function(a)
    M.show_mode(a.args)
  end, { desc = "Show mode details", nargs = 1 })

  vim.keymap.set("n", "<leader>mE", function()
    local modes = require("mode-switcher").get_available_modes()
    vim.ui.select(modes, { prompt = "Export mode" }, function(choice)
      if choice then M.export_mode(choice, "clipboard") end
    end)
  end, { desc = "  Export mode" })

  vim.keymap.set("n", "<leader>mI", function()
    M.import_from_clipboard()
  end, { desc = "  Import mode" })
end

return M
