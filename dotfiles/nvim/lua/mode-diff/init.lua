-- ═══════════════════════════════════════════════════════════════
-- Mode Diff: compare plugins between modes, find unique/shared
-- ═══════════════════════════════════════════════════════════════
local M = {}

-- Get all available modes
local function get_modes()
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes"
  local ok, files = pcall(vim.fn.readdir, modes_dir)
  if not ok then return {} end

  local modes = {}
  for _, file in ipairs(files) do
    if file:match("%.lua$") then
      table.insert(modes, file:gsub("%.lua$", ""))
    end
  end
  table.sort(modes)
  return modes
end

-- Get plugins from a mode
local function get_plugins(mode_name)
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes/" .. mode_name .. ".lua"
  local f = io.open(modes_dir, "r")
  if not f then return {} end

  local content = f:read("*a")
  f:close()

  local plugins = {}
  for plugin_name in content:gmatch('{ "(%S+/%S+)"') do
    plugins[plugin_name] = true
  end

  return plugins
end

-- Diff two modes
function M.diff_modes(mode1, mode2)
  local plugins1 = get_plugins(mode1)
  local plugins2 = get_plugins(mode2)

  local only_in_1 = {}
  local only_in_2 = {}
  local shared = {}

  -- Find plugins only in mode1
  for plugin, _ in pairs(plugins1) do
    if plugins2[plugin] then
      table.insert(shared, plugin)
    else
      table.insert(only_in_1, plugin)
    end
  end

  -- Find plugins only in mode2
  for plugin, _ in pairs(plugins2) do
    if not plugins1[plugin] then
      table.insert(only_in_2, plugin)
    end
  end

  table.sort(only_in_1)
  table.sort(only_in_2)
  table.sort(shared)

  return {
    mode1 = mode1,
    mode2 = mode2,
    only_in_1 = only_in_1,
    only_in_2 = only_in_2,
    shared = shared,
    total_1 = vim.tbl_count(plugins1),
    total_2 = vim.tbl_count(plugins2),
  }
end

-- Show diff in a buffer
function M.show_diff(mode1, mode2)
  local diff = M.diff_modes(mode1, mode2)
  local lines = {
    "# Mode Diff",
    "",
    string.format("## %s (%d plugins)", diff.mode1, diff.total_1),
    string.format("## %s (%d plugins)", diff.mode2, diff.total_2),
    "",
    string.format("### Shared (%d)", #diff.shared),
  }

  for _, plugin in ipairs(diff.shared) do
    table.insert(lines, "- " .. plugin)
  end

  table.insert(lines, "")
  table.insert(lines, string.format("### Only in %s (%d)", diff.mode1, #diff.only_in_1))
  for _, plugin in ipairs(diff.only_in_1) do
    table.insert(lines, "- " .. plugin)
  end

  table.insert(lines, "")
  table.insert(lines, string.format("### Only in %s (%d)", diff.mode2, #diff.only_in_2))
  for _, plugin in ipairs(diff.only_in_2) do
    table.insert(lines, "- " .. plugin)
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Show all unique plugins across all modes
function M.show_all_unique()
  local modes = get_modes()
  local all_plugins = {}

  for _, mode in ipairs(modes) do
    local plugins = get_plugins(mode)
    for plugin, _ in pairs(plugins) do
      if not all_plugins[plugin] then
        all_plugins[plugin] = {}
      end
      table.insert(all_plugins[plugin], mode)
    end
  end

  -- Sort by usage count
  local sorted = {}
  for plugin, mode_list in pairs(all_plugins) do
    table.insert(sorted, { name = plugin, modes = mode_list, count = #mode_list })
  end
  table.sort(sorted, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.name < b.name
  end)

  local lines = { "# All Plugins Across Modes", "" }

  for _, p in ipairs(sorted) do
    table.insert(lines, string.format("- %s (used in %d modes: %s)", p.name, p.count, table.concat(p.modes, ", ")))
  end

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Find plugins that are only in one mode (candidates for moving to shared)
function M.find_unique_plugins()
  local modes = get_modes()
  local plugin_usage = {}

  for _, mode in ipairs(modes) do
    local plugins = get_plugins(mode)
    for plugin, _ in pairs(plugins) do
      plugin_usage[plugin] = (plugin_usage[plugin] or 0) + 1
    end
  end

  local lines = { "# Unique Plugins (only in one mode)", "", "These could be moved to shared plugins:", "" }

  local count = 0
  for plugin, usage in pairs(plugin_usage) do
    if usage == 1 then
      count = count + 1
      -- Find which mode uses it
      for _, mode in ipairs(modes) do
        local plugins = get_plugins(mode)
        if plugins[plugin] then
          table.insert(lines, string.format("- %s (only in %s)", plugin, mode))
          break
        end
      end
    end
  end

  table.insert(2, string.format("Found %d unique plugins", count))

  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Setup
function M.setup()
  vim.api.nvim_create_user_command("ModeDiff", function(a)
    local args = vim.split(a.args, " ")
    if #args < 2 then
      vim.notify("[mode-diff] Usage: :ModeDiff <mode1> <mode2>", vim.log.levels.WARN)
      return
    end
    M.show_diff(args[1], args[2])
  end, { desc = "Diff two modes", nargs = "+" })

  vim.api.nvim_create_user_command("ModeDiffAll", function() M.show_all_unique() end, { desc = "All plugins across modes" })
  vim.api.nvim_create_user_command("ModeDiffUnique", function() M.find_unique_plugins() end, { desc = "Find unique plugins" })

  vim.keymap.set("n", "<leader>md", function()
    local modes = get_modes()
    vim.ui.select(modes, { prompt = "First mode" }, function(m1)
      if not m1 then return end
      vim.ui.select(modes, { prompt = "Second mode" }, function(m2)
        if m2 then M.show_diff(m1, m2) end
      end)
    end)
  end, { desc = "  Diff modes" })
end

return M
