-- Mode Export plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/mode-export",
  name = "mode-export",
  lazy = false,
  config = function()
    require("mode-export").setup()
  end,
}
