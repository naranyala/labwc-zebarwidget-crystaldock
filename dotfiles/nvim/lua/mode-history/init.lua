-- ═══════════════════════════════════════════════════════════════
-- Mode History: track mode usage, show history, analytics
-- ═══════════════════════════════════════════════════════════════
local M = {}

local history_file = vim.fn.stdpath("data") .. "/mode-history.json"

-- Load history
local function load_history()
  local f = io.open(history_file, "r")
  if not f then return { entries = {}, stats = {} } end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or { entries = {}, stats = {} }
end

local function save_history(data)
  local f = io.open(history_file, "w")
  if not f then return end
  f:write(vim.json.encode(data))
  f:close()
end

-- Record a mode switch
function M.record_switch(old_mode, new_mode)
  local data = load_history()

  table.insert(data.entries, 1, {
    from = old_mode,
    to = new_mode,
    timestamp = os.time(),
    date = os.date("%Y-%m-%d %H:%M:%S"),
    hostname = vim.fn.hostname(),
  })

  -- Keep only last 100 entries
  if #data.entries > 100 then
    data.entries = { unpack(data.entries, 1, 100) }
  end

  -- Update stats
  data.stats[new_mode] = (data.stats[new_mode] or 0) + 1

  save_history(data)
end

-- Show mode history
function M.show_history()
  local data = load_history()
  local lines = { "# Mode History", "" }

  if #data.entries == 0 then
    table.insert(lines, "No history yet.")
  else
    table.insert(lines, "## Recent Switches")
    table.insert(lines, "")
    for i, entry in ipairs(data.entries) do
      if i > 30 then break end
      table.insert(lines, string.format("%s  %s → %s", entry.date, entry.from, entry.to))
    end
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Show mode statistics
function M.show_stats()
  local data = load_history()
  local lines = { "# Mode Statistics", "" }

  -- Sort stats by count
  local sorted = {}
  for mode, count in pairs(data.stats) do
    table.insert(sorted, { mode = mode, count = count })
  end
  table.sort(sorted, function(a, b) return a.count > b.count end)

  table.insert(lines, "## Usage Count")
  table.insert(lines, "")
  for _, s in ipairs(sorted) do
    local bar = string.rep("█", math.min(s.count, 30))
    table.insert(lines, string.format("- %-20s %3d  %s", s.mode, s.count, bar))
  end

  -- Total switches
  local total = 0
  for _, s in ipairs(sorted) do
    total = total + s.count
  end
  table.insert(lines, "")
  table.insert(lines, "Total switches: " .. total)

  -- Most used mode
  if #sorted > 0 then
    table.insert(lines, "Most used: " .. sorted[1].mode)
  end

  -- Last switch
  if #data.entries > 0 then
    table.insert(lines, "Last switch: " .. data.entries[1].date)
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Show mode streak (consecutive usage)
function M.show_streak()
  local data = load_history()
  local lines = { "# Mode Streak", "" }

  -- Calculate streaks
  local streaks = {}
  local current_streak = nil
  local streak_count = 0

  for i = #data.entries, 1, -1 do
    local entry = data.entries[i]
    if current_streak == entry.to then
      streak_count = streak_count + 1
    else
      if current_streak then
        table.insert(streaks, { mode = current_streak, count = streak_count })
      end
      current_streak = entry.to
      streak_count = 1
    end
  end
  if current_streak then
    table.insert(streaks, { mode = current_streak, count = streak_count })
  end

  table.insert(lines, "## Current Streaks")
  table.insert(lines, "")
  for _, s in ipairs(streaks) do
    table.insert(lines, string.format("- %s: %d switches", s.mode, s.count))
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Clear history
function M.clear()
  save_history({ entries = {}, stats = {} })
  vim.notify("[mode-history] History cleared", vim.log.levels.INFO)
end

-- Setup
function M.setup()
  vim.api.nvim_create_user_command("ModeHistory", function() M.show_history() end, { desc = "Show mode history" })
  vim.api.nvim_create_user_command("ModeStats", function() M.show_stats() end, { desc = "Show mode statistics" })
  vim.api.nvim_create_user_command("ModeStreak", function() M.show_streak() end, { desc = "Show mode streak" })
  vim.api.nvim_create_user_command("ModeHistoryClear", function() M.clear() end, { desc = "Clear history" })

  -- Hook into mode-switcher to record switches
  vim.api.nvim_create_autocmd("User", {
    pattern = "ModeSwitcherReload",
    callback = function()
      local mode_switcher = require("mode-switcher")
      local current = mode_switcher.get_mode()
      -- Record will be done on next mode switch
    end,
  })

  vim.keymap.set("n", "<leader>mH", M.show_history, { desc = "  Mode history" })
  vim.keymap.set("n", "<leader>m?", M.show_stats, { desc = "  Mode stats" })
end

return M
