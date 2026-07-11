-- Auto Mode plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/auto-mode",
  name = "auto-mode",
  lazy = false,
  config = function()
    require("auto-mode").setup()
  end,
}
