-- ═══════════════════════════════════════════════════════════════
-- Group: Kitchen Sink
-- Everything including alternatives: nvim-cmp, telescope, neo-tree,
-- lualine, bufferline, which-key, fugitive, vimspector, none-ls
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "catppuccin/nvim", priority = 1000, name = "catppuccin",
    config = function()
      require("catppuccin").setup({ transparent_background = true })
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },

  -- Telescope
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>" },
    },
  },

  -- Neo-tree
  { "nvim-neo-tree/neo-tree.nvim", branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
    keys = { { "<leader>e", "<cmd>Neotree toggle<cr>" } },
    opts = { filesystem = { follow_current_file = { enabled = true } } },
  },

  -- Lualine
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto", section_separators = "", component_separators = "" } },
  },

  -- Bufferline
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

  -- Vim-illuminate
  { "RRethy/vim-illuminate",
    config = function() require("illuminate").configure({ delay = 200 }) end },

  -- Autopairs
  { "windwp/nvim-autopairs", event = "InsertEnter",
    config = function() require("nvim-autopairs").setup() end },

  -- Comment.nvim
  { "numToStr/Comment.nvim", keys = {
    { "gcc", function() require("Comment.api").toggle.linewise.current() end, desc = "Toggle line" },
    { "gc", function() require("Comment.api").toggle.linewise("v") end, mode = "v", desc = "Toggle selection" },
  },
    config = function() require("Comment").setup() end },

  -- Nvim-ufo (folds)
  { "kevinhwang91/nvim-ufo", dependencies = { "kevinhwang91/promise-async" },
    keys = {
      { "zR", function() require("ufo").openAllFolds() end, desc = "Open all" },
      { "zM", function() require("ufo").closeAllFolds() end, desc = "Close all" },
    },
    config = function()
      vim.o.foldcolumn = "1"; vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99; vim.o.foldenable = true
      require("ufo").setup({ provider_selector = function() return { "lsp", "indent" } end })
    end },

  -- Increment/decrement
  { "monaqa/dial.nvim",
    config = function()
      local a = require("dial.augend")
      require("dial.config").augends:register_group({ default = {
        a.integer.alias.decimal, a.integer.alias.hex,
        a.date.alias["%Y-%m-%d"], a.constant.alias.bool,
        a.constant.new({ elements = { "true", "false" } }), a.semver.alias.semver,
      } })
    end,
    keys = {
      { "<C-a>", function() require("dial").augend() end, mode = { "n", "x" }, desc = "Increment" },
      { "<C-x>", function() require("dial").augend() end, mode = { "n", "x" }, desc = "Decrement" },
    },
  },

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

  -- Annotation generator
  { "danymat/neogen", config = function() require("neogen").setup({ enabled = true }) end,
    keys = { { "<leader>nf", function() require("neogen").generate() end, desc = "Generate annotation" } },
  },

  -- Refactoring
  { "ThePrimeagen/refactoring.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    config = function() require("refactoring").setup() end,
    keys = {
      { "<leader>re", function() require("refactoring").refactor("Extract Function") end, mode = "x", desc = "Extract function" },
      { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end, mode = "x", desc = "Extract variable" },
    },
  },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "c", "lua", "vim", "vimdoc", "query",
        "python", "rust", "go", "typescript", "javascript",
        "html", "css", "json", "yaml", "toml",
        "bash", "make", "diff", "markdown",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    },
  },

  -- LSP + Mason + Nvim-cmp
  { "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "rust_analyzer", "pyright", "gopls", "ts_ls", "clangd" },
        automatic_installation = true,
      })
      require("mason-tool-installer").setup({
        ensure_installed = { "stylua", "black", "rustfmt", "gofumpt", "prettier", "ruff", "shellcheck", "shfmt" },
        run_on_start = true,
      })
      local lspconfig = require("lspconfig")
      local caps = require("cmp_nvim_lsp").default_capabilities()
      for _, s in ipairs({ "lua_ls", "rust_analyzer", "pyright", "gopls", "ts_ls", "clangd" }) do
        lspconfig[s].setup({ capabilities = caps })
      end
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("ocws-lsp-diagnostic", { clear = true }),
        callback = function()
          vim.diagnostic.config({ virtual_text = true, signs = true, underline = true, float = { border = "rounded" } })
        end,
      })
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
          ["<S-Tab>"] = cmp.mapping(function(f) if cmp.visible() then cmp.select_prev_item() elseif luasnip.jumpable(-1) then luasnip.jump(-1) else f() end end, { "i", "s" }),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" } }, { { name = "buffer" } }),
        window = { completion = cmp.config.window.bordered(), documentation = cmp.config.window.bordered() },
      })
    end,
  },

  -- Fugitive
  { "tpope/vim-fugitive",
    keys = {
      { "<leader>gs", "<cmd>Git<cr>" },
      { "<leader>gc", "<cmd>Git log<cr>" },
      { "<leader>gp", "<cmd>Git push<cr>" },
      { "<leader>gl", "<cmd>Git pull<cr>" },
    },
  },

  -- Formatter + Linter (none-ls)
  { "nvimtools/none-ls.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufWritePre",
    config = function()
      local nls = require("null-ls")
      nls.setup({ sources = {
        nls.builtins.formatting.stylua, nls.builtins.formatting.black,
        nls.builtins.formatting.rustfmt, nls.builtins.formatting.gofumpt,
        nls.builtins.formatting.prettier, nls.builtins.formatting.shfmt,
        nls.builtins.diagnostics.ruff, nls.builtins.diagnostics.shellcheck,
      } })
    end,
  },

  -- Debugger (vimspector)
  { "puremourning/vimspector",
    keys = {
      { "<F5>", "<cmd>call vimspector#Continue()<cr>" },
      { "<F10>", "<cmd>call vimspector#StepOver()<cr>" },
      { "<F11>", "<cmd>call vimspector#StepInto()<cr>" },
      { "<F12>", "<cmd>call vimspector#StepOut()<cr>" },
      { "<leader>db", "<cmd>call vimspector#ToggleBreakpoint()<cr>" },
      { "<leader>dx", "<cmd>call vimspector#Reset()<cr>" },
    },
  },
}
