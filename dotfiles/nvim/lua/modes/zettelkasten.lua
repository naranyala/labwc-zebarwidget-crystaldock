-- ═══════════════════════════════════════════════════════════════
-- Group: Zettelkasten
-- Obsidian.nvim, telekasten, vim-wiki, peek.md
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
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

  -- Treesitter (markdown focus)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "markdown", "markdown_inline", "yaml", "json" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
      matchup = { enable = true },
    },
  },

  -- LSP (markdown + yaml + json)
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "marksman", "ltex" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      lspconfig.marksman.setup({})
      lspconfig.ltex.setup({})
    end,
  },

  -- ── Zettelkasten Plugins ────────────────────────────────────

  -- Obsidian.nvim: first-class Obsidian vault integration
  { "epwalsh/obsidian.nvim",
    version = "*",
    ft = "markdown",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim", "hrsh7th/nvim-cmp" },
    opts = {
      workspaces = {
        { name = "main", path = "~/notes" },
        { name = "work", path = "~/notes/work" },
      },
      completion = { cmp = { enabled = true } },
      daily_notes = { folder = "daily", date_format = "%Y-%m-%d", template = "templates/daily.md" },
      templates = { folder = "templates", date_format = "%Y-%m-%d", time_format = "%H:%M" },
      new_notes_location = "current_dir",
      follow_url_func = function(url) vim.fn.jobstart({ "xdg-open", url }) end,
    },
    keys = {
      { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New note" },
      { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian app" },
      { "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Backlinks" },
      { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search vault" },
      { "<leader>ot", "<cmd>ObsidianTags<cr>", desc = "Tags" },
      { "<leader>od", "<cmd>ObsidianToday<cr>", desc = "Daily note" },
      { "<leader>oy", "<cmd>ObsidianYesterday<cr>", desc = "Yesterday's note" },
      { "<leader>ol", "<cmd>ObsidianLinks<cr>", desc = "All links" },
      { "<leader>op", "<cmd>ObsidianPasteImg<cr>", desc = "Paste image" },
      { "<leader>or", "<cmd>ObsidianRename<cr>", desc = "Rename note" },
      { "gf", "<cmd>ObsidianFollowLink<cr>", desc = "Follow link" },
    },
  },

  -- Peek.nvim: markdown preview in browser
  { "toppair/peek.nvim",
    ft = "markdown",
    build = "deno task --quiet build:fast",
    keys = {
      { "<leader>mp", function() require("peek").open() end, desc = "Peek markdown" },
      { "<leader>mc", function() require("peek").close() end, desc = "Close peek" },
    },
    config = function() require("peek").setup({ auto_load = false, app = "browser" }) end,
  },

  -- Markdown-preview.nvim: real-time preview in browser
  { "iamcco/markdown-preview.nvim",
    ft = "markdown",
    build = function() vim.fn["mkdp#util#install"]() end,
    keys = { { "<leader>mk", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview" } },
    config = function() vim.g.mkdp_auto_start = 0 end,
  },

  -- Vimwiki: personal wiki
  -- { "vimwiki/vimwiki",
  --   keys = { { "<leader>ww", "<cmd>VimwikiIndex<cr>", desc = "Vimwiki index" } },
  --   config = function()
  --     vim.g.vimwiki_list = {{ path = "~/vimwiki", syntax = "markdown", ext = ".md" }}
  --   end,
  -- },

  -- Neorg: org-mode for Neovim
  -- { "nvim-neorg/neorg",
  --   ft = "norg",
  --   dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
  --   build = ":Neorg sync-parsers",
  --   opts = {
  --     load = {
  --       ["core.defaults"] = {},
  --       ["core.concealer"] = {},
  --       ["core.dirman"] = { config = { workspaces = { notes = "~/notes" } } },
  --     },
  --   },
  --   keys = {
  --     { "<leader>ni", "<cmd>Neorg index<cr>", desc = "Neorg index" },
  --     { "<leader>nt", "<cmd>Neorg toc<cr>", desc = "Neorg TOC" },
  --   },
  -- },

  -- Telekasten: zettelkasten with telescope
  -- { "renerocksai/telekasten.nvim",
  --   ft = "markdown",
  --   dependencies = { "nvim-telescope/telescope.nvim" },
  --   config = function()
  --     require("telekasten").setup({
  --       home = vim.fn.expand("~/notes"),
  --       take_over_my_home = false,
  --       daily_at = "09:00",
  --       templates_new_note = vim.fn.expand("~/notes/templates/template.md"),
  --     })
  --   end,
  --   keys = {
  --     { "<leader>zf", "<cmd>Telekasten find_notes<cr>", desc = "Find notes" },
  --     { "<leader>zg", "<cmd>Telekasten search_notes<cr>", desc = "Grep notes" },
  --     { "<leader>zn", "<cmd>Telekasten new_note<cr>", desc = "New note" },
  --     { "<leader>zd", "<cmd>Telekasten daily_notes<cr>", desc = "Daily note" },
  --     { "<leader>zt", "<cmd>Telekasten toggle_todo<cr>", desc = "Toggle TODO" },
  --     { "<leader>zl", "<cmd>Telekasten insert_link<cr>", desc = "Insert link" },
  --   },
  -- },
}
