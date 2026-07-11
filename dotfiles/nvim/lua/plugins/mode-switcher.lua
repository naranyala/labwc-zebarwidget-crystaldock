-- Mode Switcher: meta-plugin to switch between experiment groups
-- Persists the last picked mode to disk
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-switcher",
  name = "mode-switcher",
  lazy = false,
  priority = 10000, -- Load first
  config = function()
    require("mode-switcher").setup({
      default_mode = "full-ide",
    })
  end,
}
