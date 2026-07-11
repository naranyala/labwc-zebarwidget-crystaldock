-- ═══════════════════════════════════════════════════════════════
-- Group: Project-centric
-- Project.nvim, persistence, neoclip, todo-comments, trouble, which-key
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "catppuccin/nvim", priority = 1000, name = "catppuccin",
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        integrations = { which_key = true, gitsigns = true, treesitter = true },
      })
      vim.cmd.colorscheme("catppuccin-mocha")
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

  -- Lualine
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto", section_separators = "", component_separators = "" } },
  },

  -- Bufferline
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { diagnostics = "nvim_lsp", always_show_bufferline = false } },
  },

  -- Devicons
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Which-key
  { "folke/which-key.nvim", event = "VeryLazy",
    opts = { plugins = { spelling = { enabled = true } } },
  },

  -- Commenting
  { "numToStr/Comment.nvim", keys = {
    { "gcc", function() require("Comment.api").toggle.linewise.current() end, desc = "Toggle line" },
    { "gc", function() require("Comment.api").toggle.linewise("v") end, mode = "v", desc = "Toggle selection" },
  },
    config = function() require("Comment").setup() end },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript", "markdown" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP + Mason + Nvim-cmp
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      local caps = require("cmp_nvim_lsp").default_capabilities()
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do lspconfig[s].setup({ capabilities = caps }) end
    end,
  },
  { "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "L3MON4D3/LuaSnip" },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = { expand = function(a) luasnip.lsp_expand(a.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(f) if cmp.visible() then cmp.select_next_item() elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump() else f() end end, { "i", "s" }),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" } }, { { name = "buffer" } }),
      })
    end,
  },

  -- Git signs
  { "lewis6991/gitsigns.nvim",
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } },
      on_attach = function(b)
        local gs = package.loaded.gitsigns
        vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { buffer = b })
        vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { buffer = b })
      end,
    },
  },

  -- ── Project-centric Plugins ─────────────────────────────────

  -- Project.nvim: switch between projects with telescope
  { "ahmedkhalf/project.nvim",
    keys = {
      { "<leader>fp", "<cmd>Telescope projects<cr>", desc = "Find projects" },
    },
    opts = {
      detection_methods = { "lsp", "pattern" },
      patterns = { ".git", "Makefile", "package.json", "Cargo.toml", "go.mod", "pyproject.toml" },
      ignore_lsp = {},
      exclude_dirs = {},
      show_hidden = false,
      silent_chdir = true,
      scope_chdir = "global",
    },
    config = function(_, opts) require("project_nvim").setup(opts) end,
  },

  -- Persistence: session management (auto-save/restore)
  { "folke/persistence.nvim",
    event = "BufReadPre",
    keys = {
      { "<leader>ps", function() require("persistence").load() end, desc = "Restore session" },
      { "<leader>pl", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>pd", function() require("persistence").stop() end, desc = "Stop session" },
    },
    opts = { dir = vim.fn.expand("~/.local/state/nvim/sessions/"), options = { "buffers", "tabpages", "winsize", "globals" } },
  },

  -- Neoclip: clipboard manager with telescope
  { "AckslD/nvim-neoclip.lua",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>fy", "<cmd>Telescope neoclip<cr>", desc = "Clipboard history" },
    },
    opts = { default_register = "+", enable_macro_history = true, filter = function(data) return #data.registers[1] > 1 end },
    config = function(_, opts) require("neoclip").setup(opts) end,
  },

  -- Todo-comments: highlight TODO, FIXME, HACK, etc.
  { "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "TODOs in Trouble" },
    },
    opts = { signs = true, keywords = {
      FIX = { icon = " ", color = "error" },
      TODO = { icon = " ", color = "info" },
      HACK = { icon = " ", color = "warning" },
      WARN = { icon = " ", color = "warning" },
      NOTE = { icon = " ", color = "hint" },
      PERF = { icon = " ", color = "default" },
    } },
  },

  -- Trouble: better diagnostics list
  { "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
      { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
    },
    opts = {},
  },

  -- No-neck-pain: center editor content
  { "shorttb/no-neck-pain.nvim",
    keys = {
      { "<leader>np", function() require("no-neck-pain").toggle() end, desc = "No neck pain" },
    },
    opts = { width = 120, autocmds = { enableOnVimEnter = false, enableOnTabEnter = false } },
  },

  -- Bufremove: delete buffers without closing windows
  { "echasnovski/mini.bufremove",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete() end, desc = "Delete buffer" },
      { "<leader>bw", function() require("mini.bufremove").wipeout() end, desc = "Wipeout buffer" },
    },
  },

  -- Persistence + project combo
  { "rmagatti/auto-session",
    lazy = false,
    opts = {
      suppressed_dirs = { "~/", "~/Downloads", "/", "/usr", "/usr/local" },
      auto_session_use_git_branch = true,
    },
  },
}
