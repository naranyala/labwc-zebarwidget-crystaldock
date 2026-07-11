-- ═══════════════════════════════════════════════════════════════
-- Group: Database
-- vim-dadbod, vim-dadbod-ui, vim-dadbod-completion, SQL workbench
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
  },

  -- Snacks
  { "folke/snacks.nvim", priority = 950, lazy = false,
    opts = { picker = { enabled = true }, notifier = { enabled = true, style = "compact" } },
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

  -- Treesitter (SQL + database languages)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "sql", "python", "typescript", "javascript", "json", "yaml" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "sqlls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      lspconfig.sqlls.setup({})
      lspconfig.lua_ls.setup({})
    end,
  },

  -- Completion
  { "saghen/blink.cmp", version = "*",
    opts = {
      keymap = { preset = "default",
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      sources = { default = { "lsp", "path", "buffer" } },
    },
  },

  -- Git signs
  { "lewis6991/gitsigns.nvim",
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } } },
  },

  -- ── Database Plugins ────────────────────────────────────────

  -- Dadbod: interact with databases from Vim
  { "tpope/vim-dadbod",
    cmd = "DB",
    keys = {
      { "<leader>dB", "<cmd>DB<cr>", mode = "v", desc = "Execute selection" },
      { "<leader>dd", "<cmd>DBUIToggle<cr>", desc = "Dadbod UI toggle" },
      { "<leader>da", "<cmd>DBAddConnection<cr>", desc = "Add connection" },
      { "<leader>dl", "<cmd>DBListConnections<cr>", desc = "List connections" },
    },
  },

  -- Dadbod UI: visual database explorer
  { "kristijanhusak/vim-dadbod-ui",
    cmd = "DBUIToggle",
    dependencies = { "tpope/vim-dadbod" },
    config = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_icons = {
        expanded = { db = "", tables = "", schemas = "", results = "" },
        collapsed = { db = "", tables = "", schemas = "", results = "" },
        saved_query = "", new_query = "", tables = "", buffers = "", connection_ok = "", connection_error = "",
      }
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 30
    end,
  },

  -- Dadbod completion: SQL completion in dadbod buffers
  { "kristijanhusak/vim-dadbod-completion",
    ft = { "sql", "mysql", "plsql" },
    dependencies = { "tpope/vim-dadbod" },
    config = function()
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = { "*.sql", "*.mysql", "*.plsql" },
        callback = function()
          require("cmp").setup.buffer({
            sources = {
              { name = "vim-dadbod-completion" },
              { name = "buffer" },
            },
          })
        end,
      })
    end,
  },

  -- SQL workbench: advanced SQL features
  -- { "jrop/vim-sql-syntax",
  --   ft = { "sql", "mysql", "plsql" },
  --   config = function()
  --     vim.g.sql_syntax_highlight = 1
  --     vim.g.sql_type_default = "mysql"
  --   end,
  -- },

  -- Dadbod dashboard: quick access to saved queries
  { "kristijanhusak/vim-dadbod-ui",
    ft = "sql",
    cmd = "DBUIToggle",
    config = function()
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_execute_on_enter = 0
    end,
  },

  -- SQL formatting
  { "tpope/vim-dadbod",
    ft = "sql",
    config = function()
      vim.g.db_adapter = "mysql"
    end,
  },
}
