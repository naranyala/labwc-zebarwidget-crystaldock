-- ═══════════════════════════════════════════════════════════════
-- Theme Switcher: switch colorschemes with live preview
-- Persists theme selection per-mode
-- ═══════════════════════════════════════════════════════════════
local M = {}

local state_file = vim.fn.stdpath("data") .. "/theme-switcher.json"

-- Built-in themes with their plugin names
local builtin_themes = {
  { name = "cyberdream",  plugin = "scottmckendry/cyberdream.nvim",  colors = { "cyberdream" } },
  { name = "catppuccin",  plugin = "catppuccin/nvim",               colors = { "catppuccin-mocha", "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato" } },
  { name = "tokyonight",  plugin = "folke/tokyonight.nvim",         colors = { "tokyonight-night", "tokyonight-day", "tokyonight-storm", "tokyonight-moon" } },
  { name = "rose-pine",   plugin = "rose-pine/neovim",              colors = { "rose-pine", "rose-pine-main", "rose-pine-dawn", "rose-pine-moon" } },
  { name = "gruvbox",     plugin = "ellisonleao/gruvbox.nvim",      colors = { "gruvbox", "gruvbox-dark", "gruvbox-light" } },
  { name = "kanagawa",    plugin = "renerocksai/kanagawa.nvim",     colors = { "kanagawa", "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" } },
  { name = "dracula",     plugin = "Mofiqul/dracula.nvim",          colors = { "dracula", "dracula-soft", "dracula-buff", "dracula-classic" } },
  { name = "nightfox",    plugin = "EdenEast/nightfox.nvim",        colors = { "nightfox", "nordfox", "duskfox", "carbonfox", "terafox", "dayfox" } },
  { name = "onedark",     plugin = "navarasu/onedark.nvim",         colors = { "onedark", "onedark-dark", "onedark-darker", "onedark-cool", "onedark-deep", "onedark-warm", "onedark-warmer", "onedark-light" } },
  { name = "nord",        plugin = "shaunsingh/nord.nvim",          colors = { "nord" } },
  { name = "oxocarbon",   plugin = "nyoom-engineering/oxocarbon.nvim", colors = { "oxocarbon", "oxocarbon-dark", "oxocarbon-light" } },
  { name = "melange",     plugin = "savq/melange-nvim",             colors = { "melange" } },
  { name = "everforest",  plugin = "neanias/everforest-nvim",       colors = { "everforest", "everforest-soft", "everforest-hard" } },
  { name = "material",    plugin = "marko-cerovac/material.nvim",   colors = { "material", "material-darker", "material-lighter", "material-palenight", "material-oceanic", "material-deep-ocean" } },
  { name = "modus",       name = "modus-themes/modus-themes.nvim",  colors = { "modus", "modus-vivendi", "modus-tinted" } },
  { name = "noctis",      plugin = "olimorris/noctis.nvim",         colors = { "noctis", "noctis-bordo", "noctis-lapis", "noctis-minimus", "noctis-umbra", "noctis-winter" } },
  { name = "iceberg",     plugin = "cocopon/iceberg.vim",           colors = { "iceberg", "iceberg-dark" } },
  { name = "habamax",     plugin = "habamax/vim-habamax",           colors = { "habamax" } },
}

-- Get state
local function load_state()
  local f = io.open(state_file, "r")
  if not f then return { theme = "cyberdark", variant = "cyberdark" } end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  return ok and data or { theme = "cyberdark", variant = "cyberdark" }
end

local function save_state(state)
  local f = io.open(state_file, "w")
  if not f then return end
  state.timestamp = os.time()
  f:write(vim.json.encode(state))
  f:close()
end

-- Apply a colorscheme
function M.apply(colorscheme)
  local ok, _ = pcall(vim.cmd.colorscheme, colorscheme)
  if ok then
    vim.notify("[theme-switcher] Applied: " .. colorscheme, vim.log.levels.INFO)
  else
    vim.notify("[theme-switcher] Failed to apply: " .. colorscheme, vim.log.levels.ERROR)
  end
end

-- Switch theme via Telescope
function M.switch()
  local state = load_state()

  -- Collect all available colorschemes
  local all_colors = {}
  for _, theme in ipairs(builtin_themes) do
    for _, color in ipairs(theme.colors) do
      table.insert(all_colors, {
        name = color,
        theme = theme.name,
        plugin = theme.plugin,
        is_current = color == state.theme,
      })
    end
  end

  -- Sort: current first, then alphabetical
  table.sort(all_colors, function(a, b)
    if a.is_current then return true end
    if b.is_current then return false end
    return a.name < b.name
  end)

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  pickers
    .new({
      prompt_title = "  Theme Switcher",
      results_title = "Colorschemes",
      layout_strategy = "cursor",
      layout_config = { width = 0.5, height = 0.6, prompt_position = "top" },
      border = true,
    }, {
      finder = finders.new_table({
        results = all_colors,
        entry_maker = function(entry)
          local icon = entry.is_current and " " or "  "
          local hl = entry.is_current and "ThemeSwitcherCurrent" or "ThemeSwitcherNormal"
          return {
            value = entry.name,
            display = string.format("%s %-30s (%s)", icon, entry.name, entry.theme),
            ordinal = entry.name,
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
            save_state({ theme = selection.value, variant = selection.value })
            M.apply(selection.value)
          end
        end)

        -- Preview on <C-i>
        map("i", "<C-i>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            M.apply(selection.value)
          end
        end)

        return true
      end,
    })
    :find()
end

-- Set theme directly
function M.set(theme_name)
  for _, theme in ipairs(builtin_themes) do
    for _, color in ipairs(theme.colors) do
      if color == theme_name or theme.name == theme_name then
        save_state({ theme = color, variant = color })
        M.apply(color)
        return
      end
    end
  end
  vim.notify("[theme-switcher] Unknown theme: " .. theme_name, vim.log.levels.ERROR)
end

-- Show current theme
function M.status()
  local state = load_state()
  vim.notify(
    string.format("[theme-switcher] Current: %s\nVariants: %s", state.theme, table.concat(M.get_variants(), ", ")),
    vim.log.levels.INFO
  )
end

-- Get variants of current theme
function M.get_variants()
  local state = load_state()
  for _, theme in ipairs(builtin_themes) do
    if theme.name == state.theme or vim.tbl_contains(theme.colors, state.theme) then
      return theme.colors
    end
  end
  return { state.theme }
end

-- Random theme
function M.random()
  local state = load_state()
  local candidates = {}
  for _, theme in ipairs(builtin_themes) do
    for _, color in ipairs(theme.colors) do
      if color ~= state.theme then
        table.insert(candidates, color)
      end
    end
  end
  if #candidates > 0 then
    local pick = candidates[math.random(#candidates)]
    save_state({ theme = pick, variant = pick })
    M.apply(pick)
  end
end

-- Setup
function M.setup(opts)
  opts = opts or {}

  -- Commands
  vim.api.nvim_create_user_command("ThemeSwitch", function() M.switch() end, { desc = "Switch theme" })
  vim.api.nvim_create_user_command("ThemeSet", function(a) M.set(a.args) end, { desc = "Set theme", nargs = 1 })
  vim.api.nvim_create_user_command("ThemeStatus", function() M.status() end, { desc = "Current theme" })
  vim.api.nvim_create_user_command("ThemeRandom", function() M.random() end, { desc = "Random theme" })
  vim.api.nvim_create_user_command("ThemeVariants", function()
    local variants = M.get_variants()
    vim.notify("[theme-switcher] Variants:\n" .. table.concat(variants, "\n"), vim.log.levels.INFO)
  end, { desc = "List theme variants" })

  -- Keymaps
  vim.keymap.set("n", "<leader>tS", M.switch, { desc = "  Switch theme" })
  vim.keymap.set("n", "<leader>tR", M.random, { desc = "  Random theme" })

  -- Highlights
  vim.api.nvim_set_hl(0, "ThemeSwitcherCurrent", { fg = "#7aa2f7", bold = true })
  vim.api.nvim_set_hl(0, "ThemeSwitcherNormal", { fg = "#a6accd" })

  -- Ensure state directory
  local state_dir = vim.fn.fnamemodify(state_file, ":h")
  if vim.fn.isdirectory(state_dir) == 0 then vim.fn.mkdir(state_dir, "p") end
end

return M
