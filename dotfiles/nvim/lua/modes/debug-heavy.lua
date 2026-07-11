-- ═══════════════════════════════════════════════════════════════
-- Group: Debug-heavy
-- Full DAP setup: Python, Rust, Go, JS, virtual text, test runners
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
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls", "codelldb" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do lspconfig[s].setup({}) end
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
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } },
      on_attach = function(b)
        local gs = package.loaded.gitsigns
        vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { buffer = b })
        vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { buffer = b })
      end,
    },
  },

  -- ── Debug Plugins ───────────────────────────────────────────

  -- DAP core
  { "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      -- Auto-open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Keymaps
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
      vim.keymap.set("n", "<leader>dB", function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, { desc = "Conditional breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step into" })
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Step over" })
      vim.keymap.set("n", "<leader>dO", dap.step_out, { desc = "Step out" })
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Run last" })
      vim.keymap.set("n", "<leader>dx", function() dapui.toggle({ reset = true }) end, { desc = "Toggle DAP UI" })
      vim.keymap.set("v", "<leader>de", function() dapui.eval() end, { desc = "Eval selection" })
    end,
  },

  -- Mason-nvim-dap: auto-install DAP adapters
  { "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
    opts = {
      ensure_installed = { "python", "codelldb", "js", "go" },
      automatic_installation = true,
      handlers = {},
    },
  },

  -- DAP UI extensions
  { "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    opts = {
      layouts = {
        { elements = {
          { id = "scopes", size = 0.25 },
          { id = "breakpoints", size = 0.25 },
          { id = "stacks", size = 0.25 },
          { id = "watches", size = 0.25 },
        }, size = 40, position = "left" },
        { elements = {
          { id = "repl", size = 0.5 },
          { id = "console", size = 0.5 },
        }, size = 10, position = "bottom" },
      },
    },
  },

  -- DAP virtual text: inline variable values
  { "theHamsta/nvim-dap-virtual-text",
    event = "LspAttach",
    opts = { commented = true },
  },

  -- DAP UI colors
  { "folke/neodev.nvim",
    ft = "lua",
    opts = { library = { plugins = { "nvim-dap-ui" }, types = true } },
  },

  -- Neotest: test runner
  { "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-go",
    },
    keys = {
      { "<leader>tn", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary" },
      { "<leader>to", function() require("neotest").output_panel.toggle() end, desc = "Output panel" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
      { "<leader>tw", function() require("neotest").watch.toggle() end, desc = "Watch test" },
    },
    opts = {
      adapters = {
        require("neotest-vitest"),
        require("neotest-python"),
        require("neotest-go"),
      },
    },
  },

  -- DAP installs via mason
  { "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = { ensure_installed = { "codelldb", "python", "js", "go" }, auto_update = true },
  },

  -- Overseer: task runner (build, test, etc.)
  { "stevearc/overseer.nvim",
    keys = {
      { "<leader>oo", "<cmd>OverseerToggle<cr>", desc = "Overseer toggle" },
      { "<leader>or", "<cmd>OverseerRun<cr>", desc = "Overseer run" },
    },
    opts = {
      templates = { "builtin", "user.cpp_build", "user.run_script" },
    },
  },
}
