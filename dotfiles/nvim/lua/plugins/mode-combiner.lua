-- Mode Combiner plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-combiner",
  name = "mode-combiner",
  lazy = false,
  config = function()
    require("mode-combiner").setup()
  end,
}
