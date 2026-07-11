-- ═══════════════════════════════════════════════════════════════
-- Mode Combiner: merge plugins from multiple modes
-- e.g., combine "full-ide" + "ai-assisted" + "git-centric"
-- ═══════════════════════════════════════════════════════════════
local M = {}

local state_file = vim.fn.stdpath("data") .. "/mode-combiner.json"

-- Load state
local function load_state()
  local f = io.open(state_file, "r")
  if not f then return { modes = {} } end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or { modes = {} }
end

local function save_state(state)
  local f = io.open(state_file, "w")
  if not f then return end
  state.timestamp = os.time()
  f:write(vim.json.encode(state))
  f:close()
end

-- Get all available modes
function M.get_modes()
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

-- Parse a mode file and extract plugin names
function M.get_plugins_from_mode(mode_name)
  local modes_dir = vim.fn.stdpath("config") .. "/lua/modes/" .. mode_name .. ".lua"
  local f = io.open(modes_dir, "r")
  if not f then return {} end

  local content = f:read("*a")
  f:close()

  -- Extract plugin names from { "user/repo" } patterns
  local plugins = {}
  for plugin_name in content:gmatch('{ "(%S+/%S+)"') do
    table.insert(plugins, plugin_name)
  end

  return plugins
end

-- Combine plugins from multiple modes (deduped)
function M.combine(mode_names)
  local all_plugins = {}
  local seen = {}

  for _, mode_name in ipairs(mode_names) do
    local plugins = M.get_plugins_from_mode(mode_name)
    for _, plugin in ipairs(plugins) do
      if not seen[plugin] then
        seen[plugin] = true
        table.insert(all_plugins, plugin)
      end
    end
  end

  return all_plugins
end

-- Show combined plugins in a buffer
function M.show_combined()
  local state = load_state()
  local lines = { "# Combined Modes", "" }

  if #state.modes == 0 then
    table.insert(lines, "No modes selected. Use :ModeCombineAdd to add modes.")
  else
    table.insert(lines, "## Selected Modes")
    for _, mode in ipairs(state.modes) do
      local plugins = M.get_plugins_from_mode(mode)
      table.insert(lines, string.format("- **%s** (%d plugins)", mode, #plugins))
    end

    local combined = M.combine(state.modes)
    table.insert(lines, "")
    table.insert(lines, string.format("## Combined: %d unique plugins", #combined))
    table.insert(lines, "")
    for _, plugin in ipairs(combined) do
      table.insert(lines, "- " .. plugin)
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

-- Add a mode to the combination
function M.add_mode(mode_name)
  local state = load_state()
  for _, m in ipairs(state.modes) do
    if m == mode_name then
      vim.notify("[mode-combiner] Already added: " .. mode_name, vim.log.levels.INFO)
      return
    end
  end
  table.insert(state.modes, mode_name)
  save_state(state)
  vim.notify("[mode-combiner] Added: " .. mode_name, vim.log.levels.INFO)
end

-- Remove a mode from the combination
function M.remove_mode(mode_name)
  local state = load_state()
  local new_modes = {}
  for _, m in ipairs(state.modes) do
    if m ~= mode_name then
      table.insert(new_modes, m)
    end
  end
  state.modes = new_modes
  save_state(state)
  vim.notify("[mode-combiner] Removed: " .. mode_name, vim.log.levels.INFO)
end

-- Pick modes to combine via Telescope
function M.pick_modes()
  local all_modes = M.get_modes()
  local state = load_state()
  local selected = {}
  for _, m in ipairs(state.modes) do selected[m] = true end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  pickers
    .new({
      prompt_title = "  Combine Modes",
      results_title = "Toggle modes (select multiple)",
      layout_strategy = "cursor",
      layout_config = { width = 0.4, height = #all_modes + 4, prompt_position = "top" },
    }, {
      finder = finders.new_table({
        results = all_modes,
        entry_maker = function(entry)
          local is_selected = selected[entry]
          local icon = is_selected and " " or "  "
          local hl = is_selected and "ModeCombinerSelected" or "ModeCombinerNormal"
          local plugins = M.get_plugins_from_mode(entry)
          return {
            value = entry,
            display = string.format("%s %-20s (%d plugins)", icon, entry, #plugins),
            ordinal = entry,
            hl_group = hl,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(_, map)
        actions.select_default:replace(function(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            if selected[selection.value] then
              M.remove_mode(selection.value)
            else
              M.add_mode(selection.value)
            end
            -- Refresh picker
            actions.close(prompt_bufnr)
            vim.schedule(function() M.pick_modes() end)
          end
        end)

        -- Apply combination on <C-a>
        map("i", "<C-a>", function()
          actions.close(prompt_bufnr)
          M.apply_combination()
        end)

        return true
      end,
    })
    :find()
end

-- Apply the combination: save to mode-switcher state
function M.apply_combination()
  local state = load_state()
  if #state.modes == 0 then
    vim.notify("[mode-combiner] No modes selected", vim.log.levels.WARN)
    return
  end

  -- Save as a combined mode in mode-switcher
  local combined_name = table.concat(state.modes, "+")
  local mode_switcher = require("mode-switcher")
  mode_switcher.save_mode(combined_name)

  vim.notify(
    string.format("[mode-combiner] Applied: %s\nRestart Neovim or run :Lazy sync", combined_name),
    vim.log.levels.INFO
  )
end

-- Clear all selected modes
function M.clear()
  save_state({ modes = {} })
  vim.notify("[mode-combiner] Cleared all modes", vim.log.levels.INFO)
end

-- Setup
function M.setup()
  vim.api.nvim_create_user_command("ModeCombine", function() M.pick_modes() end, { desc = "Pick modes to combine" })
  vim.api.nvim_create_user_command("ModeCombineShow", function() M.show_combined() end, { desc = "Show combined modes" })
  vim.api.nvim_create_user_command("ModeCombineAdd", function(a) M.add_mode(a.args) end, { desc = "Add mode to combination", nargs = 1 })
  vim.api.nvim_create_user_command("ModeCombineRemove", function(a) M.remove_mode(a.args) end, { desc = "Remove mode", nargs = 1 })
  vim.api.nvim_create_user_command("ModeCombineClear", function() M.clear() end, { desc = "Clear combination" })
  vim.api.nvim_create_user_command("ModeCombineApply", function() M.apply_combination() end, { desc = "Apply combination" })

  vim.keymap.set("n", "<leader>mC", M.pick_modes, { desc = "  Combine modes" })
  vim.keymap.set("n", "<leader>mA", M.apply_combination, { desc = "  Apply combination" })

  vim.api.nvim_set_hl(0, "ModeCombinerSelected", { fg = "#9ece6a", bold = true })
  vim.api.nvim_set_hl(0, "ModeCombinerNormal", { fg = "#a6accd" })
end

return M
