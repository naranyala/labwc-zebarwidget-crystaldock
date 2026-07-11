-- Mode History plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-history",
  name = "mode-history",
  lazy = false,
  config = function()
    require("mode-history").setup()
  end,
}
