-- ═══════════════════════════════════════════════════════════════
-- Plugin Profiler: analyze startup time, lazy-load status, deps
-- ═══════════════════════════════════════════════════════════════
local M = {}

-- Get plugin stats from lazy.nvim
function M.get_stats()
  local lazy = require("lazy")
  local plugins = lazy.plugins()
  local stats = {
    total = #plugins,
    loaded = 0,
    not_loaded = 0,
    by_type = {},
    slowest = {},
    largest = {},
  }

  for _, plugin in ipairs(plugins) do
    -- Count loaded vs not loaded
    if plugin._.loaded then
      stats.loaded = stats.loaded + 1
    else
      stats.not_loaded = stats.not_loaded + 1
    end

    -- Categorize by type
    local plugin_type = "other"
    if plugin.name:match("lsp") or plugin.name:match("mason") then
      plugin_type = "lsp"
    elseif plugin.name:match("telescope") or plugin.name:match("picker") then
      plugin_type = "picker"
    elseif plugin.name:match("treesitter") then
      plugin_type = "treesitter"
    elseif plugin.name:match("completion") or plugin.name:match("cmp") then
      plugin_type = "completion"
    elseif plugin.name:match("git") or plugin.name:match("fugitive") or plugin.name:match("gitsigns") then
      plugin_type = "git"
    elseif plugin.name:match("ui") or plugin.name:match("statusline") or plugin.name:match("bufferline") then
      plugin_type = "ui"
    elseif plugin.name:match("editor") or plugin.name:match("mini") then
      plugin_type = "editor"
    end

    stats.by_type[plugin_type] = (stats.by_type[plugin_type] or 0) + 1
  end

  return stats
end

-- Show plugin stats in a buffer
function M.show_stats()
  local stats = M.get_stats()
  local lines = {
    "# Plugin Stats",
    "",
    string.format("Total plugins: %d", stats.total),
    string.format("Loaded: %d", stats.loaded),
    string.format("Not loaded: %d", stats.not_loaded),
    "",
    "## By Type",
  }

  for plugin_type, count in pairs(stats.by_type) do
    table.insert(lines, string.format("- %s: %d", plugin_type, count))
  end

  -- Open in buffer
  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Show startup time breakdown
function M.show_startup()
  local lines = { "# Startup Time", "" }

  -- Get lazy.nvim startup info
  local lazy = require("lazy")
  local startup = lazy.stats()

  table.insert(lines, string.format("Neovim startup: %.1f ms", startup.startuptime))
  table.insert(lines, string.format("Plugins loaded: %d / %d", startup.loaded, startup.count))
  table.insert(lines, "")

  -- Get per-plugin load times
  local plugins = lazy.plugins()
  local load_times = {}
  for _, plugin in ipairs(plugins) do
    if plugin._.loaded and plugin._.loaded时间和 then
      table.insert(load_times, { name = plugin.name, time = plugin._.loaded时间和 })
    end
  end

  -- Sort by load time
  table.sort(load_times, function(a, b) return a.time > b.time end)

  table.insert(lines, "## Slowest Plugins")
  for i, p in ipairs(load_times) do
    if i > 15 then break end
    table.insert(lines, string.format("  %3d. %-30s %6.1f ms", i, p.name, p.time))
  end

  -- Open in buffer
  vim.cmd("new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buftype = "nofile"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0 })
end

-- Show dependency tree for a plugin
function M.show_deps(plugin_name)
  local lazy = require("lazy")
  local plugins = lazy.plugins()
  local lines = { "# Dependencies: " .. plugin_name, "" }

  for _, plugin in ipairs(plugins) do
    if plugin.name == plugin_name then
      table.insert(lines, "## Direct dependencies")
      if plugin.dependencies then
        for _, dep in ipairs(plugin.dependencies) do
          local dep_name = type(dep) == "string" and dep or dep.name or dep[1] or "unknown"
          table.insert(lines, "  - " .. dep_name)
        end
      else
        table.insert(lines, "  (none)")
      end
      break
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

-- Show which plugins are disabled in current mode
function M.show_disabled()
  local lazy = require("lazy")
  local plugins = lazy.plugins()
  local lines = { "# Disabled Plugins", "" }

  local disabled = 0
  for _, plugin in ipairs(plugins) do
    if not plugin._.loaded then
      disabled = disabled + 1
      local ft = plugin.ft and table.concat(plugin.ft, ", ") or "always"
      local cmd = plugin.cmd and table.concat(plugin.cmd, ", ") or "always"
      table.insert(lines, string.format("- %s (ft: %s, cmd: %s)", plugin.name, ft, cmd))
    end
  end

  table.insert(1, string.format("Total disabled: %d", disabled))

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
  vim.api.nvim_create_user_command("ProfilePlugins", function() M.show_stats() end, { desc = "Plugin stats" })
  vim.api.nvim_create_user_command("ProfileStartup", function() M.show_startup() end, { desc = "Startup time" })
  vim.api.nvim_create_user_command("ProfileDeps", function(a) M.show_deps(a.args) end, { desc = "Plugin dependencies", nargs = 1 })
  vim.api.nvim_create_user_command("ProfileDisabled", function() M.show_disabled() end, { desc = "Disabled plugins" })

  vim.keymap.set("n", "<leader>pP", M.show_stats, { desc = "  Plugin stats" })
  vim.keymap.set("n", "<leader>pS", M.show_startup, { desc = "  Startup time" })
end

return M
