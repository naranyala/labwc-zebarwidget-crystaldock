-- ═══════════════════════════════════════════════════════════════
-- Group: AI-assisted
-- Copilot, Codeium, ChatGPT, CopilotCheat, CopilotChat
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
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript", "markdown" },
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

  -- ── AI Plugins ──────────────────────────────────────────────

  -- GitHub Copilot
  { "github/copilot.vim",
    event = "InsertEnter",
    config = function()
      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<C-j>", 'copilot#Accept("<CR>")', { expr = true, silent = true })
    end,
  },

  -- CopilotChat: ChatGPT-like interface for Copilot
  { "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>cc", "<cmd>CopilotChat<cr>", desc = "Copilot Chat" },
      { "<leader>ce", "<cmd>CopilotChatExplain<cr>", mode = "x", desc = "Explain selection" },
      { "<leader>cr", "<cmd>CopilotChatReview<cr>", mode = "x", desc = "Review selection" },
      { "<leader>cf", "<cmd>CopilotChatFix<cr>", mode = "x", desc = "Fix selection" },
    },
    opts = {},
  },

  -- Codeium: free Copilot alternative
  -- { "Exafunction/codeium.vim",
  --   event = "InsertEnter",
  --   config = function()
  --     vim.g.codeium_disable_map = true
  --     vim.keymap.set("i", "<C-j>", function() return vim.fn["codeium#Accept"]() end, { expr = true })
  --   end,
  -- },

  -- ChatGPT: OpenAI API wrapper
  -- { "jackMort/ChatGPT.nvim",
  --   dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
  --   keys = {
  --     { "<leader>gP", "<cmd>ChatGPT<cr>", desc = "ChatGPT" },
  --     { "<leader>gE", "<cmd>ChatGPTEditWithInstruction<cr>", mode = "v", desc = "Edit with instruction" },
  --   },
  --   config = function() require("chatgpt").setup() end,
  -- },

  -- Codeium Chat (free alternative to CopilotChat)
  -- { "Exafunction/codeium.nvim",
  --   dependencies = { "nvim-lua/plenary.nvim", "hrsh7th/nvim-cmp" },
  --   config = function() require("codeium").setup() end,
  -- },
}
