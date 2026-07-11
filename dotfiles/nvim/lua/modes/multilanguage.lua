-- ═══════════════════════════════════════════════════════════════
-- Group: Multilanguage
-- Polyglot: Rust (rustacean), Go (go.nvim), TS/JS (typescript-tools)
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

  -- Yank
  { "gbprod/yanky.nvim",
    config = function()
      require("yanky").setup({ ring = { history_length = 100, storage = "shada" }, highlight = { timer = 150 } })
    end,
  },

  -- Treesitter (all major languages)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "lua", "vim", "query",
        "rust", "toml", "ron",
        "go", "gomod", "gosum", "gotmpl",
        "typescript", "javascript", "tsx", "jsx", "json", "jsonc",
        "python", "pylint",
        "c", "cpp", "cmake",
        "html", "css", "scss",
        "dockerfile", "yaml", "toml",
        "markdown", "markdown_inline",
        "regex", "bash", "fish",
      },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "gopls", "rust_analyzer", "ts_ls", "clangd", "html", "cssls" },
        automatic_installation = true,
      })
      local lspconfig = require("lspconfig")
      for _, s in ipairs({ "lua_ls", "pyright", "gopls", "rust_analyzer", "ts_ls", "clangd", "html", "cssls" }) do
        lspconfig[s].setup({})
      end
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

  -- ── Language-Specific Plugins ───────────────────────────────

  -- Rust: rustacean.nvim (better rust-analyzer integration)
  { "mrcjkb/rustaceanvim",
    ft = "rust",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-neotest/nvim-nio",
    },
    keys = {
      { "<leader>ra", function() vim.cmd.RustLsp("code_action") end, desc = "Rust code action" },
      { "<leader>rt", function() vim.cmd.RustLsp("runnables") end, desc = "Rust runnables" },
      { "<leader>rd", function() vim.cmd.RustLsp("debuggables") end, desc = "Rust debuggables" },
      { "<leader>rh", function() vim.cmd.RustLsp("hover_actions") end, desc = "Rust hover actions" },
      { "<leader>rr", function() vim.cmd.RustLsp("reloadWorkspace") end, desc = "Rust reload workspace" },
      { "<leader>rc", function() vim.cmd.RustLsp("openCargo") end, desc = "Open Cargo.toml" },
    },
    opts = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
            inlayHints = { locationLinks = true },
          },
        },
      },
    },
  },

  -- Go: go.nvim (Go-specific features)
  { "ray-x/go.nvim",
    ft = "go",
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
    },
    keys = {
      { "<leader>gR", "<cmd>GoRun<cr>", desc = "Go run" },
      { "<leader>gT", "<cmd>GoTest<cr>", desc = "Go test" },
      { "<leader>gc", "<cmd>GoCoverage<cr>", desc = "Go coverage" },
      { "<leader>gi", "<cmd>GoImpl<cr>", desc = "Go implement" },
      { "<leader>gf", "<cmd>GoFmt<cr>", desc = "Go format" },
      { "<leader>gL", "<cmd>GoLint<cr>", desc = "Go lint" },
      { "<leader>gI", "<cmd>GoImport<cr>", desc = "Go import" },
    },
    opts = {
      lsp_keymaps = true,
      diagnostic = { virtual_text = true },
      lsp_cfg = { settings = {} },
    },
    config = function(_, opts) require("go").setup(opts) end,
  },

  -- TypeScript/JavaScript: typescript-tools.nvim
  { "pmizio/typescript-tools.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    dependencies = { "neovim/nvim-lspconfig", "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>to", "<cmd>TSToolsOrganizeImports<cr>", desc = "Organize imports" },
      { "<leader>ta", "<cmd>TSToolsAddMissingImports<cr>", desc = "Add missing imports" },
      { "<leader>tr", "<cmd>TSToolsRemoveUnusedImports<cr>", desc = "Remove unused imports" },
      { "<leader>tf", "<cmd>TSToolsFixAll<cr>", desc = "Fix all" },
      { "<leader>ts", "<cmd>TSToolsGoToSourceDefinition<cr>", desc = "Go to source" },
    },
    opts = {
      settings = {
        tsserver_locale = "en",
        complete_function_calls = true,
        include_completions_with_insert_text = true,
        typescript = {
          inlayHints = {
            includeInlayParameterNameHints = "all",
            includeInlayVariableTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
          },
        },
      },
    },
  },

  -- Python: basedpyright + neovim
  { "neovim/nvim-lspconfig",
    ft = "python",
    opts = function()
      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "off",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })
    end,
  },

  -- C/C++: clangd extensions
  { "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp", "objc", "objcpp" },
    dependencies = { "neovim/nvim-lspconfig" },
    opts = {
      inlay_hints = { enabled = true },
      ast = { role_icons = { type = "", declaration = "", definition = "", specifier = "", statement = "", parameter = "" } },
    },
  },

  -- JSON: schemastore
  { "b0o/schemastore.nvim",
    ft = { "json", "jsonc", "yaml", "yml", "toml" },
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      local lspconfig = require("lspconfig")
      lspconfig.jsonls.setup({
        settings = { json = { schemas = require("schemastore").json.schemas } },
      })
      lspconfig.yamlls.setup({
        settings = { yaml = { schemas = require("schemastore").yaml.schemas } },
      })
    end,
  },

  -- HTML/CSS: emmet + html
  { "mattn/emmet-vim",
    ft = { "html", "css", "scss", "javascriptreact", "typescriptreact" },
    keys = {
      { "<C-e>", "<cmd>EmmetInstall<cr>", desc = "Emmet install" },
    },
    config = function()
      vim.g.user_emmet_leader_key = "<C-e>"
    end,
  },

  -- Shell: bash-language-server
  { "neovim/nvim-lspconfig",
    ft = { "sh", "bash" },
    opts = function()
      vim.lsp.config("bashls", {})
    end,
  },

  -- Docker: dockerfile support
  { "ekalinin/Dockerfile.vim",
    ft = "dockerfile",
    opts = {},
  },

  -- Terraform: hashivim
  { "hashivim/vim-terraform",
    ft = { "terraform", "tf", "hcl" },
    opts = { terraform_fmt_on_save = true, terraform_align_parentheses = true },
  },

  -- Ansible
  { "pearofducks/ansible-vim",
    ft = "yaml",
    opts = { yaml_indent_less = 2 },
  },

  -- Neodev: Lua development for Neovim
  { "folke/neodev.nvim",
    ft = "lua",
    opts = {},
  },

  -- Null-ls: format/lint (general purpose)
  { "nvimtools/none-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.stylua,
          null_ls.builtins.formatting.prettier,
          null_ls.builtins.formatting.black,
          null_ls.builtins.formatting.gofumpt,
          null_ls.builtins.formatting.rustfmt,
          null_ls.builtins.diagnostics.eslint,
          null_ls.builtins.diagnostics.flake8,
        },
      })
    end,
  },
}
