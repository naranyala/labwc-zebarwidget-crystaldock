-- ═══════════════════════════════════════════════════════════════
-- Mode Dashboard: startup screen with mode overview
-- Shows current mode, quick switch, recent activity
-- ═══════════════════════════════════════════════════════════════
local M = {}

-- ASCII art for the dashboard
local logo = {
  "  ╔══════════════════════════════════════════╗",
  "  ║         MODE SWITCHER DASHBOARD         ║",
  "  ╚══════════════════════════════════════════╝",
  "",
}

-- Get current mode info
local function get_mode_info()
  local mode = require("mode-switcher").get_mode()
  local modes = require("mode-switcher").get_available_modes()

  -- Count plugins in current mode
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes"
  local f = io.open(modes_dir .. "/" .. mode .. ".lua", "r")
  local plugin_count = 0
  local description = ""
  if f then
    local content = f:read("*a")
    f:close()
    for _ in content:gmatch('{ "%S+/%S+"') do
      plugin_count = plugin_count + 1
    end
    local first_line = content:match("^(.-)\n") or content
    description = first_line:match("^%-%-%s*(.+)$") or ""
  end

  return {
    name = mode,
    plugin_count = plugin_count,
    description = description,
    total_modes = #modes,
  }
end

-- Get quick actions
local function get_quick_actions()
  return {
    { key = "ms", action = "ModeSwitch",       desc = "Switch mode" },
    { key = "mn", action = "ModeNext",         desc = "Next mode" },
    { key = "mi", action = "ModeStatus",       desc = "Mode info" },
    { key = "tS", action = "ThemeSwitch",      desc = "Switch theme" },
    { key = "pP", action = "ProfilePlugins",   desc = "Plugin stats" },
    { key = "mH", action = "ModeHistory",      desc = "Mode history" },
    { key = "m?", action = "ModeStats",        desc = "Mode stats" },
    { key = "md", action = "ModeDiff",         desc = "Diff modes" },
  }
end

-- Get recent mode history
local function get_recent_history()
  local history_file = vim.fn.stdpath("data") .. "/mode-history.json"
  local f = io.open(history_file, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data.entries then return {} end

  local recent = {}
  for i = 1, math.min(5, #data.entries) do
    table.insert(recent, data.entries[i])
  end
  return recent
end

-- Open dashboard
function M.open()
  local mode_info = get_mode_info()
  local actions = get_quick_actions()
  local history = get_recent_history()

  local lines = vim.deepcopy(logo)

  -- Current mode
  table.insert(lines, "  Current Mode: " .. mode_info.name)
  table.insert(lines, "  Plugins: " .. mode_info.plugin_count)
  if mode_info.description ~= "" then
    table.insert(lines, "  " .. mode_info.description)
  end
  table.insert(lines, "")

  -- Quick actions
  table.insert(lines, "  Quick Actions:")
  table.insert(lines, "  ─────────────────────────────────────")
  for _, action in ipairs(actions) do
    table.insert(lines, string.format("  <leader>%-4s  %s", action.key, action.desc))
  end
  table.insert(lines, "")

  -- Recent history
  if #history > 0 then
    table.insert(lines, "  Recent Switches:")
    table.insert(lines, "  ─────────────────────────────────────")
    for _, entry in ipairs(history) do
      table.insert(lines, string.format("  %s  %s → %s", entry.date:sub(1, 16), entry.from, entry.to))
    end
  end

  -- Available modes
  local modes = require("mode-switcher").get_available_modes()
  table.insert(lines, "")
  table.insert(lines, "  Available Modes (" .. #modes .. "):")
  table.insert(lines, "  ─────────────────────────────────────")
  for _, m in ipairs(modes) do
    local marker = m == mode_info.name and " *" or "  "
    table.insert(lines, "  " .. marker .. " " .. m)
  end

  -- Open in a new buffer
  vim.cmd("enew")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.bo.filetype = "mode-dashboard"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modifiable = false

  -- Keymaps
  local buf = vim.api.nvim_get_current_buf()
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close dashboard" })
  vim.keymap.set("n", "s", function()
    vim.cmd("ModeSwitch")
  end, { buffer = buf, desc = "Switch mode" })
  vim.keymap.set("n", "t", function()
    vim.cmd("ThemeSwitch")
  end, { buffer = buf, desc = "Switch theme" })
  vim.keymap.set("n", "r", function()
    vim.cmd("ModeStatus")
  end, { buffer = buf, desc = "Mode info" })
  vim.keymap.set("n", "h", function()
    vim.cmd("ModeHistory")
  end, { buffer = buf, desc = "History" })

  -- Highlights
  vim.api.nvim_buf_add_highlight(buf, 0, "DashboardHeader", 0, 0, -1)
  for i = 1, 2 do
    vim.api.nvim_buf_add_highlight(buf, 0, "DashboardHeader", i, 0, -1)
  end
end

-- Auto-open on startup
function M.setup(opts)
  opts = opts or {}

  -- Command
  vim.api.nvim_create_user_command("ModeDashboard", function() M.open() end, { desc = "Open mode dashboard" })

  -- Keymaps
  vim.keymap.set("n", "<leader>mD", M.open, { desc = "  Mode dashboard" })

  -- Auto-open on VimEnter (if enabled)
  if opts.auto_open then
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        -- Only open if no arguments were passed
        if vim.fn.argc() == 0 then
          vim.schedule(function() M.open() end)
        end
      end,
    })
  end

  -- Highlights
  vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#7aa2f7", bold = true })
end

return M
