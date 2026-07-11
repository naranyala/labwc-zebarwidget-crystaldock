-- ═══════════════════════════════════════════════════════════════
-- Group: Performance
-- Every plugin lazy-loaded, fast startup, minimal overhead
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
  },

  -- Telescope (all keys lazy-loaded)
  { "nvim-telescope/telescope.nvim", cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>" },
    },
  },

  -- Oil (lazy-loaded on directory open)
  { "stevearc/oil.nvim", dependencies = { "echasnovski/mini.icons" },
    cmd = "Oil",
    keys = { { "<leader>e", "<cmd>Oil<cr>", desc = "Open Oil" } },
    opts = { default_file_explorer = true, skip_confirm_for_simple_edits = true },
  },

  -- Statusline (loaded after UI enter)
  { "echasnovski/mini.statusline", event = "VeryLazy",
    config = function() require("mini.statusline").setup({ use_icons = true, set_vim_settings = false }) end,
  },

  -- Icons (loaded before UI)
  { "echasnovski/mini.icons", event = "VeryLazy",
    config = function() require("mini.icons").setup() end },

  -- Commenting (loaded on keypress)
  { "echasnovski/mini.comment", keys = { "gcc", "gc", { "gc", mode = "v" } },
    config = function() require("mini.comment").setup() end },

  -- Treesitter (loaded after file open, before syntax)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP (lazy-loaded on file open)
  { "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do lspconfig[s].setup({}) end
    end,
  },

  -- Git signs (loaded after git file detection)
  { "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } },
      on_attach = function(b)
        local gs = package.loaded.gitsigns
        vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { buffer = b })
        vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { buffer = b })
      end,
    },
  },

  -- Yank (loaded on first yank operation)
  { "gbprod/yanky.nvim",
    keys = {
      { "y", "<Plug>(yanky-yank)", mode = { "n", "x" } },
      { "p", "<Plug>(yanky-paste-after)", mode = { "n", "x" } },
      { "P", "<Plug>(yanky-paste-before)", mode = { "n", "x" } },
    },
    config = function()
      require("yanky").setup({
        ring = { history_length = 50, storage = "memory" },
        highlight = { timer = 150 },
      })
    end,
  },

  -- Dial (loaded on first dial operation)
  { "monaqa/dial.nvim",
    keys = {
      { "<C-a>", function() return require("dial.map").inc_normal() end, expr = true },
      { "<C-x>", function() return require("dial.map").dec_normal() end, expr = true },
    },
    config = function()
      local augend = require("dial.augend")
      require("dial.config").augends:register_group({ default = {
        augend.integer.alias.decimal,
        augend.integer.alias.hex,
        augend.date.alias["%Y/%m/%d"],
        augend.constant.alias.bool,
      } })
    end,
  },

  -- ── Performance Tips ────────────────────────────────────────

  -- Disable built-in plugins and optimize settings
  { "folke/lazy.nvim",
    priority = 10001,
    config = function()
      vim.g.loaded_gzip = 1
      vim.g.loaded_zip = 1
      vim.g.loaded_zipPlugin = 1
      vim.g.loaded_tar = 1
      vim.g.loaded_tarPlugin = 1
      vim.g.loaded_tutor = 1
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.g.loaded_matchit = 1
      vim.g.loaded_matchparen = 1
      vim.g.loaded_2html_plugin = 1
      vim.g.loaded_vimball = 1
      vim.g.loaded_vimballPlugin = 1
      vim.g.loaded_getscript = 1
      vim.g.loaded_getscriptPlugin = 1
      vim.g.loaded_logipat = 1
      vim.g.loaded_rrhelper = 1
      vim.g.loaded_spellfile_plugin = 1
      vim.g.loaded_shada_plugin = 1
      vim.g.loaded_man = 1
      vim.g.loaded_tohtml = 1
      vim.g.loaded_spellfile = 1
      vim.g.did_load_filetypes = 0
      vim.g.loaded_perl_provider = 0
      vim.g.loaded_ruby_provider = 0
      vim.g.loaded_node_provider = 0
      vim.opt.updatetime = 100
      vim.opt.clipboard = "unnamedplus"
      vim.opt.completeopt = "menuone,noselect"
      vim.opt.ttimeoutlen = 10
      vim.opt.timeoutlen = 300
    end,
  },
}
