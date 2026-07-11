-- Mode Dashboard plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-dashboard",
  name = "mode-dashboard",
  lazy = false,
  config = function()
    require("mode-dashboard").setup({ auto_open = false })
  end,
}
