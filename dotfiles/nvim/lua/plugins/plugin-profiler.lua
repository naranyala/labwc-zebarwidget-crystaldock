-- Plugin Profiler plugin
return {
  dir = vim.fn.stdpath("config") .. "/lua/plugin-profiler",
  name = "plugin-profiler",
  lazy = false,
  config = function()
    require("plugin-profiler").setup()
  end,
}
