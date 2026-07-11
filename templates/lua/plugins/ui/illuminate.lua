return {
  { "code-biscuits/nvim-biscuits",
    config = function()
      require("nvim-biscuits").setup({
        default_config = { prefix = " » ", prefix_highlight = "Comment", suffix = "", max_length = 30 },
      })
    end,
  },
  -- { "RRethy/vim-illuminate",
  --   config = function() require("illuminate").configure({ delay = 200 }) end },
}
