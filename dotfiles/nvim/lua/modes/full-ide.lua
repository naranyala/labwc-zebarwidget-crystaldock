-- ═══════════════════════════════════════════════════════════════
-- Group: Full IDE
-- Everything: picker, explorer, statusline, completion, git, format, lint, debug
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
  },

  -- Snacks: picker + notifications + ui
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

  -- Tabline
  { "echasnovski/mini.tabline", config = function() require("mini.tabline").setup() end },

  -- Key hints
  { "echasnovski/mini.clue",
    config = function()
      require("mini.clue").setup({
        triggers = {
          { mode = "n", keys = "<leader>" }, { mode = "x", keys = "<leader>" },
          { mode = "n", keys = "g" }, { mode = "n", keys = "z" },
          { mode = "n", keys = "'" }, { mode = "n", keys = "`" },
          { mode = "n", keys = "\"" }, { mode = "i", keys = "<C-r>" },
        },
        window = { config = { border = "rounded" } },
      })
    end,
  },

  -- Icons
  { "echasnovski/mini.icons", config = function() require("mini.icons").setup() end },

  -- Indent guides
  { "shellRaining/hlchunk.nvim",
    config = function()
      require("hlchunk").setup({
        chunk = { enable = true, style = { { fg = "#6c7086" } } },
        indent = { enable = true, style = { { fg = "#45475a" } } },
        blank = { enable = false },
      })
    end,
  },

  -- Bracket context
  { "code-biscuits/nvim-biscuits",
    config = function()
      require("nvim-biscuits").setup({
        default_config = { prefix = " » ", prefix_highlight = "Comment", suffix = "", max_length = 30 },
      })
    end,
  },

  -- Autopairs
  { "echasnovski/mini.pairs", config = function() require("mini.pairs").setup() end },

  -- Commenting
  { "echasnovski/mini.comment", config = function() require("mini.comment").setup() end },

  -- Folds
  { "jghauser/fold-cycle.nvim", config = function() require("fold-cycle").setup() end,
    keys = {
      { "<Tab>", function() require("fold-cycle").toggle() end, mode = "n", desc = "Toggle fold" },
      { "<S-Tab>", function() require("fold-cycle").open() end, mode = "n", desc = "Open fold" },
    },
  },

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

  -- LSP + Mason + Completion
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
      local caps = require("blink.cmp").get_lsp_capabilities()
      for _, s in ipairs({ "lua_ls", "rust_analyzer", "pyright", "gopls", "ts_ls", "clangd" }) do
        lspconfig[s].setup({ capabilities = caps })
      end
      vim.api.nvim_create_autocmd("LspAttach", {
        desc = "Configure diagnostics",
        group = vim.api.nvim_create_augroup("ocws-lsp-diagnostic", { clear = true }),
        callback = function()
          vim.diagnostic.config({
            virtual_text = true,
            signs = { text = {
              [vim.diagnostic.severity.ERROR] = " ", [vim.diagnostic.severity.WARN] = " ",
              [vim.diagnostic.severity.INFO] = " ", [vim.diagnostic.severity.HINT] = " ",
            } },
            underline = true, update_in_insert = false, float = { border = "rounded" },
          })
        end,
      })
    end,
  },
  { "saghen/blink.cmp", version = "*",
    opts = {
      keymap = { preset = "default",
        ["<C-Space>"] = { "show", "hide" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
      },
      sources = { default = { "lsp", "path", "buffer" } },
      completion = { documentation = { auto_show = true }, menu = { border = "rounded" } },
      appearance = { nerd_font_variant = "normal" },
    },
  },

  -- Git signs
  { "lewis6991/gitsigns.nvim",
    opts = {
      signs = { add = { text = "+" }, change = { text = "~" }, delete = { text = "_" },
        topdelete = { text = "‾" }, changedelete = { text = "~" } },
      on_attach = function(b)
        local gs = package.loaded.gitsigns
        local m = function(mode, key, action, desc)
          vim.keymap.set(mode, key, action, { buffer = b, desc = desc })
        end
        m("n", "]c", function() gs.nav_hunk("next") end, "Next hunk")
        m("n", "[c", function() gs.nav_hunk("prev") end, "Prev hunk")
        m("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        m("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
        m("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
        m("n", "<leader>gd", gs.diffthis, "Diff this")
        m("n", "<leader>gD", function() gs.diffthis("~") end, "Diff this ~")
        m("x", "<leader>gs", function() gs.stage_hunk() end, "Stage hunk")
        m("x", "<leader>gr", function() gs.reset_hunk() end, "Reset hunk")
      end,
    },
  },

  -- Formatter
  { "stevearc/conform.nvim", event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" }, python = { "black" }, rust = { "rustfmt" },
        go = { "gofumpt" }, javascript = { "prettier" }, typescript = { "prettier" },
        html = { "prettier" }, css = { "prettier" }, json = { "prettier" },
        yaml = { "prettier" }, markdown = { "prettier" },
        c = { "clang-format" }, cpp = { "clang-format" },
        sh = { "shfmt" }, _ = { "trim_whitespace" },
      },
      format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
    },
  },

  -- Linter
  { "mfussenegger/nvim-lint", event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "ruff" }, javascript = { "eslint_d" }, typescript = { "eslint_d" },
        sh = { "shellcheck" }, c = { "clangtidy" }, cpp = { "clangtidy" },
      }
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("ocws-lint", { clear = true }),
        callback = function() lint.try_lint() end,
      })
    end,
  },

  -- Debugger
  { "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio", "theHamsta/nvim-dap-virtual-text" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup()
      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end
    end,
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "Continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "Step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Step into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint" },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional BP" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "REPL" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Run last" },
      { "<leader>dx", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle UI" },
    },
  },
}
