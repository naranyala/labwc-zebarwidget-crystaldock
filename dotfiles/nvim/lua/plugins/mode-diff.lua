-- Mode Diff plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-diff",
  name = "mode-diff",
  lazy = false,
  config = function()
    require("mode-diff").setup()
  end,
}
