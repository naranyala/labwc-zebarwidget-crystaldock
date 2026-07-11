-- Shared colorscheme (loaded by all modes)
-- Override in individual modes if needed
return {
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({
        transparent = true,
        italic_comments = true,
        terminal_colors = true,
      })
      vim.cmd.colorscheme("cyberdream")
    end,
  },
}
