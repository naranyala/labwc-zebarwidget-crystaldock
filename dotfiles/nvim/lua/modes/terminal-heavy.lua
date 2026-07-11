-- ═══════════════════════════════════════════════════════════════
-- Group: Terminal-heavy
-- Toggleterm, buftabline, smart-splits, lazygit, neotest
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

  -- ── Terminal Plugins ────────────────────────────────────────

  -- Toggleterm: multiple terminal instances with keybindings
  { "akinsho/toggleterm.nvim", version = "*",
    keys = {
      { "<C-\\>", function() require("toggleterm").toggle(0) end, desc = "Toggle terminal" },
      { "<leader>tf", function() require("toggleterm").toggle(0, 15, "float") end, desc = "Floating terminal" },
      { "<leader>th", function() require("toggleterm").toggle(0, 20, "horizontal") end, desc = "Horizontal terminal" },
      { "<leader>tv", function() require("toggleterm").toggle(0, 80, "vertical") end, desc = "Vertical terminal" },
      { "<leader>tl", function() require("toggleterm").toggle(0, nil, "tab") end, desc = "Tab terminal" },
      { "<leader>tt", function() require("toggleterm").toggle(0, nil, "window") end, desc = "Window terminal" },
    },
    opts = {
      size = function(term)
        if term.direction == "horizontal" then return 15
        elseif term.direction == "vertical" then return vim.o.columns * 0.4
        else return 20 end
      end,
      open_mapping = [[<C-\>]],
      direction = "float",
      float_opts = { border = "curved", width = 100, height = 30 },
      shade_terminals = true,
    },
  },

  -- Lazygit: terminal UI for git
  { "kdheepak/lazygit.nvim",
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "Lazygit" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- BufTabLine: tab/buffer bar at top
  { "ap/vim-buftabline",
    dependencies = { "echasnovski/mini.bufremove" },
    config = function()
      vim.g.buftabline_show = 1
      vim.g.buftabline_indicators = 1
      vim.g.buftabline_separators = 0
    end,
  },

  -- Smart-splits: navigate and resize splits with arrows
  { "mrjohannchang/smart-splits.nvim",
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move left" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move down" },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move up" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move right" },
      { "<A-h>", function() require("smart-splits").resize_left() end, desc = "Resize left" },
      { "<A-j>", function() require("smart-splits").resize_down() end, desc = "Resize down" },
      { "<A-k>", function() require("smart-splits").resize_up() end, desc = "Resize up" },
      { "<A-l>", function() require("smart-splits").resize_right() end, desc = "Resize right" },
    },
    opts = { at_edge = "stop" },
  },

  -- Neotest: test runner with multiple adapters
  { "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-python",
    },
    keys = {
      { "<leader>tn", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary" },
      { "<leader>to", function() require("neotest").output_panel.toggle() end, desc = "Output panel" },
      { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
    },
    opts = {
      adapters = {
        require("neotest-vitest"),
        require("neotest-python"),
      },
    },
  },

  -- ── Debug ───────────────────────────────────────────────────

  -- DAP core
  { "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio", "theHamsta/nvim-dap-virtual-text" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
    end,
  },

  -- Mason-nvim-dap: auto-install DAP adapters
  { "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
    opts = { ensure_installed = { "python", "delve", "codelldb" }, automatic_installation = true },
  },
}
