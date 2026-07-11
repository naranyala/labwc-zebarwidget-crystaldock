-- ═══════════════════════════════════════════════════════════════
-- Group: Motion & Text Objects
-- Hop, flash, mini.ai, nvim-treesitter-textobjects, mini.move
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
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do lspconfig[s].setup({}) end
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

  -- ── Motion & Text Object Plugins ────────────────────────────

  -- Hop: quick jump to any position
  { "smoka7/hop.nvim",
    keys = {
      { "s", "<cmd>HopChar1<cr>", desc = "Hop char" },
      { "S", "<cmd>HopWord<cr>", desc = "Hop word" },
      { "<leader>hw", "<cmd>HopWord<cr>", desc = "Hop word" },
      { "<leader>hl", "<cmd>HopLine<cr>", desc = "Hop line" },
      { "<leader>hp", "<cmd>HopPattern<cr>", desc = "Hop pattern" },
      { "<leader>hj", "<cmd>HopVertical<cr>", desc = "Hop vertical" },
      { "<leader>hc", "<cmd>HopChar2<cr>", desc = "Hop 2 chars" },
    },
    opts = { keys = "etovxqpdygfblzhckisuran" },
  },

  -- Flash: modern search & jump
  { "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
      { "s", function() require("flash").jump() end, desc = "Flash jump" },
      { "S", function() require("flash").treesitter() end, desc = "Flash treesitter" },
      { "r", function() require("flash").remote() end, desc = "Flash remote" },
      { "R", function() require("flash").treesitter_search() end, desc = "Flash treesitter search" },
      { "<c-s>", function() require("flash").toggle() end, desc = "Toggle Flash" },
    },
    opts = {
      search = { mode = "fuzzy" },
      jump = { autojump = true },
      label = { after = false, before = true },
      highlight = { backdrop = false },
    },
  },

  -- Mini.ai: improved text objects
  { "echasnovski/mini.ai",
    dependencies = { "echasnovski/mini.icons" },
    event = "CursorMoved",
    opts = {
      n_lines = 500,
      custom_textobjects = {
        f = false,
        d = false,
        b = false,
      },
      mappings = {
        around = "a",
        inside = "i",
        around_next = "an",
        inside_next = "in",
        around_last = "al",
        inside_last = "il",
        move_left = "<M-h>",
        move_right = "<M-l>",
        move_down = "<M-j>",
        move_up = "<M-k>",
      },
    },
  },

  -- Mini.move: move lines/blocks with alt keys
  { "echasnovski/mini.move",
    opts = {
      mappings = {
        left = "<A-h>", right = "<A-l>", down = "<A-j>", up = "<A-k>",
        line_left = "<A-h>", line_right = "<A-l>", line_down = "<A-j>", line_up = "<A-k>",
      },
    },
  },

  -- Mini.splitjoin: split/join arguments
  { "echasnovski/mini.splitjoin",
    opts = { mappings = { split = "gS", join = "gJ" } },
  },

  -- Mini.bracketed: bracket motions
  { "echasnovski/mini.bracketed",
    opts = {
      buffer = { suffix = "b", options = {} },
      comment = { suffix = "c", options = {} },
      conflict = { suffix = "x", options = {} },
      diagnostic = { suffix = "d", options = {} },
      file = { suffix = "f", options = {} },
      indent = { suffix = "i", options = {} },
      jump = { suffix = "j", options = {} },
      location = { suffix = "l", options = {} },
      oldfile = { suffix = "o", options = {} },
      quickfix = { suffix = "q", options = {} },
      treesitter = { suffix = "t", options = {} },
      undo = { suffix = "u", options = {} },
      window = { suffix = "w", options = {} },
      yank = { suffix = "y", options = {} },
    },
  },

  -- Mini.operators: operator extensions
  { "echasnovski/mini.operators",
    opts = {
      evaluate = { prefix = "g=" },
      exchange = { prefix = "gx" },
      multiply = { prefix = "gm" },
      replace = { prefix = "gr" },
      sort = { prefix = "gs" },
    },
  },

  -- Surround: add/delete/change surrounding chars
  { "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  -- Trailblazer: multiple cursor marks
  { "LeonHeidelbach/trailblazer.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>mm", function() require("trailblazer").toggle_trail_mark_stacks() end, desc = "Toggle trail marks" },
      { "<leader>md", function() require("trailblazer").delete_all_trail_marks() end, desc = "Delete all marks" },
      { "<leader>ml", "<cmd>Telescope trailblazer trail_mark_list<cr>", desc = "List marks" },
      { "<M-n>", function() require("trailblazer").next_trail_mark() end, desc = "Next mark" },
      { "<M-p>", function() require("trailblazer").previous_trail_mark() end, desc = "Prev mark" },
    },
    opts = { trail_options = { mark_symbol = "•", newest_mark_symbol = "◉", cursor_mark_symbol = "◈" } },
  },

  -- Yank highlighting
  { "miversik33/yank.nvim",
    event = "TextYankPost",
    opts = { highlight = { timer = 200 } },
  },

  -- Mini.hipatterns: highlight patterns (TODOs, colors, etc.)
  { "echasnovski/mini.hipatterns",
    event = "CursorMoved",
    opts = {
      highlighters = {
        fixme = { pattern = "%FIXME", group = "MiniHipatternsFixme" },
        hack = { pattern = "%HACK", group = "MiniHipatternsHack" },
        todo = { pattern = "%TODO", group = "MiniHipatternsTodo" },
        note = { pattern = "%NOTE", group = "MiniHipatternsNote" },
        hex_color = require("mini.hipatterns").gen_highlighter.hex_color(),
      },
    },
  },
}
