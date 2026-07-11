-- ═══════════════════════════════════════════════════════════════
-- Group: Beautiful UI
-- UI polish: noice, fidget, dressing, zen-mode, twilight, render-markdown
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "catppuccin/nvim", priority = 1000, name = "catppuccin",
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        integrations = { noice = true, mason = true, telescope = { enabled = true },
          gitsigns = true, treesitter = true, which_key = true },
      })
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },

  -- Snacks
  { "folke/snacks.nvim", priority = 950, lazy = false,
    opts = {
      picker = { enabled = true },
      notifier = { enabled = true, style = "compact" },
      animate = { enabled = true },
      scroll = { enabled = true },
      indent = { enabled = true, chunk = { enabled = false } },
      bigfile = { enabled = true },
      quickfile = { enabled = true },
    },
  },

  -- Oil
  { "stevearc/oil.nvim", dependencies = { "echasnovski/mini.icons" },
    opts = { default_file_explorer = true, view_options = { show_hidden = true },
      keymaps = { ["<C-h>"] = false, ["<C-l>"] = false },
      skip_confirm_for_simple_edits = true },
  },

  -- Lualine (feature-rich statusline)
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto", section_separators = "", component_separators = "" } },
  },

  -- Bufferline (fancy tabs)
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { diagnostics = "nvim_lsp", always_show_bufferline = false } },
  },

  -- Which-key
  { "folke/which-key.nvim", event = "VeryLazy",
    opts = { plugins = { spelling = { enabled = true } } },
  },

  -- Devicons
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Indent blankline
  { "lukas-reineke/indent-blankline.nvim", main = "ibl",
    opts = { indent = { char = "│" }, scope = { enabled = true } },
  },

  -- Commenting
  { "numToStr/Comment.nvim", keys = {
    { "gcc", function() require("Comment.api").toggle.linewise.current() end, desc = "Toggle line" },
    { "gc", function() require("Comment.api").toggle.linewise("v") end, mode = "v", desc = "Toggle selection" },
  },
    config = function() require("Comment").setup() end },

  -- Autopairs
  { "windwp/nvim-autopairs", event = "InsertEnter",
    config = function() require("nvim-autopairs").setup() end },

  -- Yank ring
  { "gbprod/yanky.nvim",
    config = function()
      require("yanky").setup({
        ring = { history_length = 100, storage = "shada" },
        highlight = { timer = 150 },
        preserve_cursor_position = { enabled = true },
      })
    end,
  },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript", "markdown", "html", "css", "json" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP + Mason + Nvim-cmp
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls", "ts_ls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      local caps = require("cmp_nvim_lsp").default_capabilities()
      for _, s in ipairs({ "lua_ls", "pyright", "gopls", "ts_ls" }) do lspconfig[s].setup({ capabilities = caps }) end
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
        window = { completion = cmp.config.window.bordered(), documentation = cmp.config.window.bordered() },
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

  -- ── UI Polish Plugins ───────────────────────────────────────

  -- Noice: replaces cmdline, search, and notifications with beautiful UI
  { "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      require("noice").setup({
        lsp = { override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        } },
        presets = { bottom_search = true, command_palette = true, long_message_to_split = true, lsp_doc_border = true },
      })
    end,
  },

  -- Fidget: LSP progress spinner (replaces LSP progress in statusline)
  { "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = { notification = { window = { winblend = 0 } } },
  },

  -- Dressing: better vim.ui.select and vim.ui.input
  { "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = { input = { enabled = true }, select = { enabled = true, backend = { "telescope" } } },
  },

  -- Zen-mode: distraction-free writing
  { "folke/zen-mode.nvim",
    keys = { { "<leader>z", function() require("zen-mode").toggle() end, desc = "Zen mode" } },
    opts = { window = { width = 0.85 } },
  },

  -- Twilight: dim inactive code blocks
  { "folke/twilight.nvim",
    keys = { { "<leader>tw", function() require("twilight").toggle() end, desc = "Twilight toggle" } },
    opts = { context = 10 },
  },

  -- Render-markdown: beautiful markdown rendering
  { "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown" } },
  },

  -- Headlines: highlighting for markdown headlines
  -- { "lukas-reineke/headlines.nvim", ft = "markdown",
  --   dependencies = "nvim-treesitter/nvim-treesitter",
  --   config = function() require("headlines").setup({ markdown = { headline_highlights = { "Headline1", "Headline2" } } }) end },
  -- },
}
