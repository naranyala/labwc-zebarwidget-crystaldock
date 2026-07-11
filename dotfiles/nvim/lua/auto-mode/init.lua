-- ═══════════════════════════════════════════════════════════════
-- Auto Mode: auto-switch modes based on project type
-- Detects project type and loads appropriate mode
-- ═══════════════════════════════════════════════════════════════
local M = {}

local state_file = vim.fn.stdpath("data") .. "/auto-mode.json"

-- Project type → mode mapping
local default_mappings = {
  -- Languages
  ["rust"]       = "multilanguage",
  ["go"]         = "multilanguage",
  ["typescript"] = "multilanguage",
  ["javascript"] = "multilanguage",
  ["python"]     = "multilanguage",
  ["lua"]        = "vim-purist",

  -- Frameworks
  ["react"]      = "ai-assisted",
  ["nextjs"]     = "ai-assisted",
  ["vue"]        = "ai-assisted",

  -- Writing
  ["markdown"]   = "writing",
  ["org"]        = "zettelkasten",
  ["vimwiki"]    = "zettelkasten",

  -- DevOps
  ["docker"]     = "remote-dev",
  ["terraform"]  = "remote-dev",
  ["ansible"]    = "remote-dev",
  ["kubernetes"] = "remote-dev",

  -- Databases
  ["sql"]        = "database",
  ["postgres"]   = "database",
  ["mysql"]      = "database",
  ["sqlite"]     = "database",

  -- Small projects
  ["config"]     = "minimal",
  ["dotfiles"]   = "minimal",
  ["snippet"]    = "minimal",
}

-- Detect project type from files
function M.detect_project_type()
  local cwd = vim.fn.getcwd()
  local indicators = {}

  -- Check for project markers
  local markers = {
    { file = "Cargo.toml",      type = "rust" },
    { file = "go.mod",          type = "go" },
    { file = "package.json",    type = "javascript", check = function(content)
      return content:match("react") or content:match("next") or content:match("vue")
    end},
    { file = "tsconfig.json",   type = "typescript" },
    { file = "pyproject.toml",  type = "python" },
    { file = "requirements.txt", type = "python" },
    { file = "setup.py",        type = "python" },
    { file = "*.lua",           type = "lua", dir = "lua/" },
    { file = "Dockerfile",      type = "docker" },
    { file = "docker-compose.yml", type = "docker" },
    { file = "terraform.tf",    type = "terraform" },
    { file = "*.tf",            type = "terraform" },
    { file = "*.hcl",           type = "terraform" },
    { file = "ansible.cfg",     type = "ansible" },
    { file = "playbook.yml",    type = "ansible" },
    { file = "k8s/",            type = "kubernetes" },
    { file = "*.sql",           type = "sql" },
    { file = "*.md",            type = "markdown" },
    { file = "README.md",       type = "markdown" },
  }

  for _, marker in ipairs(markers) do
    if marker.dir then
      local files = vim.fn.glob(cwd .. "/" .. marker.dir .. marker.file, false, true)
      if #files > 0 then
        indicators[marker.type] = (indicators[marker.type] or 0) + 1
      end
    else
      local files = vim.fn.glob(cwd .. "/" .. marker.file, false, true)
      if #files > 0 then
        indicators[marker.type] = (indicators[marker.type] or 0) + 1
      end
    end
  end

  -- Find the most common type
  local best_type = nil
  local best_count = 0
  for type, count in pairs(indicators) do
    if count > best_count then
      best_count = count
      best_type = type
    end
  end

  return best_type
end

-- Get mode for project type
function M.get_mode_for_type(project_type)
  local state = nil
  local f = io.open(state_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok then state = data end
  end

  -- Use custom mapping if set
  if state and state.mappings and state.mappings[project_type] then
    return state.mappings[project_type]
  end

  -- Fall back to default mapping
  return default_mappings[project_type] or "full-ide"
end

-- Save auto-mode state
function M.save_state(state)
  local f = io.open(state_file, "w")
  if not f then return end
  state.timestamp = os.time()
  f:write(vim.json.encode(state))
  f:close()
end

-- Auto-switch mode based on current project
function M.auto_switch()
  local project_type = M.detect_project_type()
  if not project_type then
    vim.notify("[auto-mode] Could not detect project type", vim.log.levels.INFO)
    return
  end

  local suggested_mode = M.get_mode_for_type(project_type)
  local current_mode = require("mode-switcher").get_mode()

  if suggested_mode == current_mode then
    vim.notify(
      string.format("[auto-mode] Already in %s (detected: %s)", current_mode, project_type),
      vim.log.levels.INFO
    )
    return
  end

  vim.notify(
    string.format("[auto-mode] Detected: %s → Suggested mode: %s (current: %s)", project_type, suggested_mode, current_mode),
    vim.log.levels.INFO
  )

  local choice = vim.fn.confirm(
    string.format("Switch to %s mode?\n(Project type: %s)", suggested_mode, project_type),
    "&Yes\n&No",
    1
  )

  if choice == 1 then
    require("mode-switcher").set(suggested_mode)
  end
end

-- Show current auto-mode config
function M.status()
  local project_type = M.detect_project_type()
  local suggested_mode = project_type and M.get_mode_for_type(project_type) or nil
  local current_mode = require("mode-switcher").get_mode()

  local lines = {
    "[auto-mode] Status",
    "",
    "Current project type: " .. (project_type or "unknown"),
    "Suggested mode: " .. (suggested_mode or "none"),
    "Current mode: " .. current_mode,
    "",
    "Default mappings:",
  }

  for ptype, mode in pairs(default_mappings) do
    table.insert(lines, string.format("  %s → %s", ptype, mode))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { timeout = 5000 })
end

-- Update mapping for a project type
function M.set_mapping(project_type, mode)
  local state = nil
  local f = io.open(state_file, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok then state = data end
  end

  state = state or {}
  state.mappings = state.mappings or {}
  state.mappings[project_type] = mode
  M.save_state(state)
  vim.notify("[auto-mode] Mapping updated: " .. project_type .. " → " .. mode, vim.log.levels.INFO)
end

-- Setup
function M.setup(opts)
  opts = opts or {}

  -- Auto-detect on VimEnter
  if opts.auto_detect ~= false then
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        vim.schedule(function() M.auto_switch() end)
      end,
    })
  end

  -- Commands
  vim.api.nvim_create_user_command("AutoMode", function() M.auto_switch() end, { desc = "Auto-detect and switch mode" })
  vim.api.nvim_create_user_command("AutoModeStatus", function() M.status() end, { desc = "Show auto-mode status" })
  vim.api.nvim_create_user_command("AutoModeMap", function(a)
    local args = vim.split(a.args, " ")
    if #args < 2 then
      vim.notify("[auto-mode] Usage: :AutoModeMap <project_type> <mode>", vim.log.levels.WARN)
      return
    end
    M.set_mapping(args[1], args[2])
  end, { desc = "Set project type mapping", nargs = "+" })

  -- Keymaps
  vim.keymap.set("n", "<leader>mA", M.auto_switch, { desc = "  Auto-detect mode" })
end

return M
