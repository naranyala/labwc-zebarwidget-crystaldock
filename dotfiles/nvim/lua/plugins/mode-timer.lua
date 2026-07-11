-- Mode Timer plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-timer",
  name = "mode-timer",
  lazy = false,
  config = function()
    require("mode-timer").setup()
  end,
}
