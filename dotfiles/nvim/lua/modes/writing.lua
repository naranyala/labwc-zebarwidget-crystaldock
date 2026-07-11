-- ═══════════════════════════════════════════════════════════════
-- Group: Writing
-- Prose-focused: minimal UI, zen mode, markdown support, no dev tools
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
  },

  -- Snacks: picker
  { "folke/snacks.nvim", priority = 950, lazy = false,
    opts = {
      picker = { enabled = true },
      notifier = { enabled = true, style = "compact" },
      animate = { enabled = true },
      scroll = { enabled = true },
      bigfile = { enabled = true },
      quickfile = { enabled = true },
    },
  },

  -- Oil: file explorer
  { "stevearc/oil.nvim", dependencies = { "echasnovski/mini.icons" },
    opts = { default_file_explorer = true, view_options = { show_hidden = true },
      keymaps = { ["<C-h>"] = false, ["<C-l>"] = false },
      skip_confirm_for_simple_edits = true },
  },

  -- Statusline
  { "echasnovski/mini.statusline", config = function()
    require("mini.statusline").setup({ use_icons = true, set_vim_settings = false })
  end },

  -- Icons
  { "echasnovski/mini.icons", config = function() require("mini.icons").setup() end },

  -- Autopairs
  { "echasnovski/mini.pairs", config = function() require("mini.pairs").setup() end },

  -- Commenting
  { "echasnovski/mini.comment", config = function() require("mini.comment").setup() end },

  -- Treesitter (markdown + text)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  -- Zen mode
  { "junegunn/goyo.vim", cmd = "Goyo",
    keys = { { "<leader>G", "<cmd>Goyo<cr>", desc = "Zen mode" } },
  },

  -- Focus mode (dim paragraphs)
  { "junegunn/limelight.vim", cmd = "Limelight",
    keys = { { "<leader>L", "<cmd>Limelight<cr>", desc = "Focus mode" } },
  },

  -- Markdown preview
  { "iamcco/markdown-preview.nvim", build = "cd app && npm install",
    ft = "markdown",
    keys = { { "<leader>mp", "<cmd>MarkdownPreview<cr>", desc = "Markdown preview" } },
  },

  -- Word count in statusline
  { "justincampbell/vim-wordcount", ft = { "markdown", "text", "tex" } },
}
