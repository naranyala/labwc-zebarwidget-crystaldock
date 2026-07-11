-- ═══════════════════════════════════════════════════════════════
-- Group: Notes & Knowledge
-- Neorg, vimwiki, orgmode, obsidian, telescope, markdown
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
      { "<leader>fn", "<cmd>Telescope find_files cwd=~/notes<cr>", desc = "Find notes" },
      { "<leader>gn", "<cmd>Telescope live_grep cwd=~/notes<cr>", desc = "Grep notes" },
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

  -- Treesitter (markdown focus)
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
    opts = {
      ensure_installed = { "lua", "vim", "query", "markdown", "markdown_inline", "yaml", "json", "org" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "marksman", "ltex", "yamlls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      lspconfig.marksman.setup({})
      lspconfig.ltex.setup({ settings = { ltex = { language = "en-US" } } })
      lspconfig.yamlls.setup({})
    end,
  },

  -- Completion
  { "saghen/blink.cmp", version = "*",
    opts = {
      keymap = { preset = "default", ["<CR>"] = { "accept", "fallback" } },
      sources = { default = { "lsp", "path", "buffer" } },
    },
  },

  -- Git signs
  { "lewis6991/gitsigns.nvim",
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } } },
  },

  -- ── Notes & Knowledge Plugins ───────────────────────────────

  -- Neorg: org-mode for Neovim
  { "nvim-neorg/neorg",
    ft = "norg",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    build = ":Neorg sync-parsers",
    keys = {
      { "<leader>ni", "<cmd>Neorg index<cr>", desc = "Neorg index" },
      { "<leader>nt", "<cmd>Neorg toc<cr>", desc = "Neorg TOC" },
      { "<leader>nl", "<cmd>Neorg workspace list<cr>", desc = "List workspaces" },
      { "<leader>nn", "<cmd>Neorg new<cr>", desc = "New note" },
    },
    opts = {
      load = {
        ["core.defaults"] = {},
        ["core.concealer"] = { config = { icon_preset = "diamond" } },
        ["core.keybinds"] = { config = { default_keybinds = true } },
        ["core.dirman"] = {
          config = {
            workspaces = {
              notes = "~/notes",
              work = "~/notes/work",
              personal = "~/notes/personal",
            },
            default_workspace = "notes",
          },
        },
        ["core.completion"] = { config = { engine = "nvim-cmp" } },
        ["core.journal"] = { config = { workspace = "notes" } },
        ["core.qo"] = { config = { quickfix = { enabled = true } } },
        ["core.looking-glass"] = {},
        ["core.presenter"] = { config = { zen_mode = true } },
      },
    },
  },

  -- Vimwiki: personal wiki with diary
  { "vimwiki/vimwiki",
    keys = {
      { "<leader>ww", "<cmd>VimwikiIndex<cr>", desc = "Vimwiki index" },
      { "<leader>wt", "<cmd>VimwikiTabmake<cr>", desc = "Vimwiki tab" },
      { "<leader>wi", "<cmd>VimwikiDiaryIndex<cr>", desc = "Vimwiki diary" },
      { "<leader>wd", "<cmd>VimwikiMakeDiaryNote<cr>", desc = "Today's diary" },
      { "<leader>wy", "<cmd>VimwikiMakeYesterdayDiaryNote<cr>", desc = "Yesterday's diary" },
    },
    config = function()
      vim.g.vimwiki_list = {
        { path = "~/vimwiki", syntax = "markdown", ext = ".md",
          diary_frequency = "daily", diary_rel_path = "diary/" },
      }
      vim.g.vimwiki_use_alt = 1
      vim.g.vimwiki_markdown_link_ext = 1
    end,
  },

  -- Orgmode: Emacs org-mode for Neovim
  -- { "nvim-orgmode/orgmode",
  --   ft = "org",
  --   dependencies = { "nvim-treesitter/nvim-treesitter" },
  --   keys = {
  --     { "<leader>oa", "<cmd>OrgCapture<cr>", desc = "Org capture" },
  --     { "<leader>oA", "<cmd>OrgAgenda<cr>", desc = "Org agenda" },
  --     { "<leader>oc", "<cmd>OrgClockIn<cr>", desc = "Clock in" },
  --     { "<leader>oC", "<cmd>OrgClockOut<cr>", desc = "Clock out" },
  --     { "<leader>of", "<cmd>OrgToggleCheckbox<cr>", desc = "Toggle checkbox" },
  --   },
  --   config = function()
  --     require("orgmode").setup_ts_grammar()
  --     require("orgmode").setup({
  --       org_agenda_files = { "~/org/**/*" },
  --       org_default_notes_file = "~/org/refile.org",
  --       org_todo_keywords = { "TODO", "WAITING", "|", "DONE", "CANCELLED" },
  --       org_capture_templates = {
  --         t = { description = "Task", template = "* TODO %?\n  %u\n  %a", target = "~/org/todo.org" },
  --         n = { description = "Note", template = "* %?\n  %u\n  %a", target = "~/org/notes.org" },
  --       },
  --     })
  --   end,
  -- },

  -- Neorg Telescope integration
  { "nvim-neorg/neorg",
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      load = {
        ["core.integrations.telescope"] = {},
      },
    },
  },

  -- Peek: markdown preview in browser
  { "toppair/peek.nvim",
    ft = "markdown",
    build = "deno task --quiet build:fast",
    keys = {
      { "<leader>mp", function() require("peek").open() end, desc = "Peek markdown" },
      { "<leader>mc", function() require("peek").close() end, desc = "Close peek" },
    },
    opts = { auto_load = false, app = "browser" },
  },

  -- Markdown-preview: real-time preview
  { "iamcco/markdown-preview.nvim",
    ft = "markdown",
    build = function() vim.fn["mkdp#util#install"]() end,
    keys = { { "<leader>mk", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview" } },
    opts = { auto_start = 0 },
  },

  -- Headlines: markdown headlines
  { "lukas-reineke/headlines.nvim",
    ft = "markdown",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require("headlines").setup({
        markdown = {
          fatheadlines_pattern = "^#{1,6} ",
          fatheadline_highlights = { "Headline1", "Headline2", "Headline3", "Headline4" },
        },
      })
    end,
  },

  -- Render-markdown: beautiful markdown rendering
  { "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown" } },
  },

  -- Todo-comments: highlight TODOs
  { "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
    },
    opts = { keywords = { TODO = { color = "info" }, NOTE = { color = "hint" }, HACK = { color = "warning" }, PERF = { color = "default" } } },
  },

  -- Zk-nvim: Zettelkasten with LSP
  -- { "mickael-menu/zk-nvim",
  --   ft = "markdown",
  --   dependencies = { "nvim-telescope/telescope.nvim" },
  --   keys = {
  --     { "<leader>zn", "<cmd>ZkNew { title = vim.fn.input('Title: ') }<cr>", desc = "New note" },
  --     { "<leader>zo", "<cmd>ZkNotes { sort = { 'modified' } }<cr>", desc = "Find notes" },
  --     { "<leader>zt", "<cmd>ZkTags<cr>", desc = "Find tags" },
  --     { "<leader>zf", "<cmd>ZkMatch<cr>", desc = "Find by match" },
  --     { "<leader>zl", "<cmd>ZkInsertLink<cr>", desc = "Insert link" },
  --   },
  --   config = function()
  --     require("zk").setup({ picker = "telescope" })
  --   end,
  -- },

  -- Wiki.vim: another wiki plugin
  -- { "lervag/wiki.vim",
  --   ft = "markdown",
  --   keys = {
  --     { "<leader>wx", "<cmd>WikiIndex<cr>", desc = "Wiki index" },
  --     { "<leader>wd", "<cmd>WikiDiaryYearIndex<cr>", desc = "Diary" },
  --   },
  --   config = function()
  --     vim.g.wiki_root = "~/wiki"
  --     vim.g.wiki_filetypes = { "markdown" }
  --   end,
  -- },
}
