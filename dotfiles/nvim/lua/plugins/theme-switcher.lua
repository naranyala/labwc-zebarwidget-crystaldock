-- Theme Switcher plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/theme-switcher",
  name = "theme-switcher",
  lazy = false,
  priority = 9999,
  config = function()
    require("theme-switcher").setup()
  end,
}
