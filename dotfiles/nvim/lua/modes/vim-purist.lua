-- ═══════════════════════════════════════════════════════════════
-- Group: Vim Purist
-- Hardtime, mini.ai, undotree, vim-matchup, vim-sleuth
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
  },

  -- Telescope
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>" },
    },
  },

  -- Oil
  { "stevearc/oil.nvim", dependencies = { "echasnovski/mini.icons" },
    opts = { default_file_explorer = true, skip_confirm_for_simple_edits = true },
  },

  -- Statusline
  { "echasnovski/mini.statusline", config = function()
    require("mini.statusline").setup({ use_icons = true, set_vim_settings = false })
  end },

  -- Icons
  { "echasnovski/mini.icons", config = function() require("mini.icons").setup() end },

  -- Commenting
  { "echasnovski/mini.comment", config = function() require("mini.comment").setup() end },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do lspconfig[s].setup({}) end
    end,
  },

  -- ── Vim Purist Plugins ──────────────────────────────────────

  -- Hardtime: break bad habits, learn proper vim motions
  { "m4xshen/hardtime.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      restricted_keys = {
        "j", "k", "V", "v", "<Up>", "<Down>", "<Left>", "<Right>",
        "<BS>", "<C-h>", "<C-j>", "<C-k>", "<C-l>",
      },
      disabled_filetypes = { "lazy", "oil", "mason", "TelescopePrompt" },
      hints = {
        ["[kj]"] = { "Use g + motion to move within a line" },
        ["[Vv]"] = { "Consider using operator+motion instead" },
      },
    },
  },

  -- Mini.ai: improved text objects (around, inside)
  { "echasnovski/mini.ai",
    dependencies = { "echasnovski/mini.icons" },
    opts = {
      n_lines = 500,
    },
  },

  -- Mini.move: move lines/blocks with alt keys
  { "echasnovski/mini.move",
    opts = {
      mappings = {
        left = "<A-h>", right = "<A-l>", down = "<A-j>", up = "<A-k>",
        line_left = "<A-h>", line_right = "<A-l>", line_down = "<A-j>", line_up = "<A-k>",
      },
    },
  },

  -- Mini.splitjoin: split/join arguments, lists, etc.
  { "echasnovski/mini.splitjoin",
    opts = { mappings = { split = "gS", join = "gJ" } },
  },

  -- Undotree: visual undo history
  { "mbbill/undotree",
    keys = { { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" } },
    config = function()
      vim.g.undotree_SplitWidth = 35
      vim.g.undotree_SetFocusWhenToggle = 1
    end,
  },

  -- Vim-matchup: extended % matching
  { "andymass/vim-matchup",
    event = "BufReadPost",
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
      vim.g.matchup_text_obj_enabled = 1
      vim.g.matchup_surround_enabled = 1
    end,
  },

  -- Vim-sleuth: auto-detect indentation
  { "tpope/vim-sleuth", event = "BufReadPost" },

  -- Vim-illuminate: highlight word under cursor
  { "RRethy/vim-illuminate",
    event = "CursorHold",
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 200,
        under_cursor = true,
        filetypes_denylist = { "oil", "lazy", "mason", "TelescopePrompt" },
      })
    end,
  },

  -- Surround: add/delete/change surrounding chars
  { "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  -- Abolish: substitute and coerce (cr* for camelCase, cr- for kebab-case)
  { "tpope/vim-abolish", event = "VeryLazy" },

  -- Speeddating: increment/decrement dates
  { "tpope/vim-speeddating", event = "VeryLazy" },

  -- Repeat: repeat plugin maps with .
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- Git signs (minimal)
  { "lewis6991/gitsigns.nvim",
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } },
      on_attach = function(b)
        local gs = package.loaded.gitsigns
        vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { buffer = b })
        vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { buffer = b })
      end,
    },
  },
}
