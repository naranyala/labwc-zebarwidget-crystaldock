-- ═══════════════════════════════════════════════════════════════
-- Group: Git-centric
-- Neogit, Diffview, git-conflict, fugitive, lazygit, gitsigns
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "catppuccin/nvim", priority = 1000, name = "catppuccin",
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        integrations = { gitsigns = true, which_key = true },
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
    opts = { options = { theme = "auto", section_separators = "", component_separators = "" },
      sections = { lualine_b = { "branch" } },
    },
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

  -- Commenting
  { "numToStr/Comment.nvim", keys = {
    { "gcc", function() require("Comment.api").toggle.linewise.current() end, desc = "Toggle line" },
  },
    config = function() require("Comment").setup() end },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript", "git_config", "git_rebase", "gitcommit", "gitignore" },
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

  -- Nvim-cmp
  { "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "L3MON4D3/LuaSnip" },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        mapping = cmp.mapping.preset.insert({
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" } }, { { name = "buffer" } }),
      })
    end,
  },

  -- ── Git Plugins ─────────────────────────────────────────────

  -- Gitsigns: full featured
  { "lewis6991/gitsigns.nvim",
    opts = {
      signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" }, topdelete = { text = "‾" }, changedelete = { text = "~" } },
      on_attach = function(b)
        local gs = package.loaded.gitsigns
        vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { buffer = b, desc = "Next hunk" })
        vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { buffer = b, desc = "Prev hunk" })
        vim.keymap.set("n", "<leader>gp", gs.preview_hunk, { buffer = b, desc = "Preview hunk" })
        vim.keymap.set("n", "<leader>gr", gs.reset_hunk, { buffer = b, desc = "Reset hunk" })
        vim.keymap.set("n", "<leader>gR", gs.reset_buffer, { buffer = b, desc = "Reset buffer" })
        vim.keymap.set("n", "<leader>gb", function() gs.blame_line({ full = true }) end, { buffer = b, desc = "Blame line" })
        vim.keymap.set("n", "<leader>gd", gs.diffthis, { buffer = b, desc = "Diff this" })
        vim.keymap.set("n", "<leader>gS", gs.stage_buffer, { buffer = b, desc = "Stage buffer" })
      end,
    },
  },

  -- Neogit: Magit-like git interface
  { "NeogitOrg/neogit",
    dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim" },
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" },
      { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit commit" },
      { "<leader>gp", "<cmd>Neogit push<cr>", desc = "Neogit push" },
      { "<leader>gl", "<cmd>Neogit log<cr>", desc = "Neogit log" },
    },
    opts = {},
  },

  -- Diffview: git diff viewer
  { "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview open" },
      { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "File history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Buffer history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Diffview close" },
    },
    opts = {},
  },

  -- Git-conflict: resolve merge conflicts
  { "akinsho/git-conflict.nvim",
    event = "BufReadPost",
    opts = {
      default_mappings = true,
      disable_diagnostics = true,
    },
  },

  -- Lazygit: terminal UI for git
  { "kdheepak/lazygit.nvim",
    keys = { { "<leader>gL", "<cmd>LazyGit<cr>", desc = "Lazygit" } },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- Fugitive: classic git commands
  { "tpope/vim-fugitive",
    cmd = { "Git", "Gsplit", "Gvsplit", "Gtabedit", "Gdiffsplit" },
    keys = {
      { "<leader>gs", "<cmd>Git<cr>", desc = "Fugitive status" },
      { "<leader>gw", "<cmd>Git write<cr>", desc = "Git write" },
      { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git blame" },
    },
  },

  -- Gitlinker: open file on GitHub/GitLab
  { "ruifm/gitlinker.nvim",
    keys = {
      { "<leader>gy", function() require("gitlinker").get_buf_range_url("n") end, desc = "Copy GitHub URL" },
      { "<leader>gy", function() require("gitlinker").get_buf_range_url("v") end, mode = "v", desc = "Copy GitHub URL (selection)" },
    },
    opts = { mappings = nil },
  },

  -- Git signs virtual text blame
  { "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = false,
      current_line_blame_opts = { virt_text_pos = "eol", delay = 500 },
    },
  },
}
