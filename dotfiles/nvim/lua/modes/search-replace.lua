-- ═══════════════════════════════════════════════════════════════
-- Group: Search & Replace
-- Spectre, telescope, hop, flash, grug-far, ripgrep
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

  -- Git signs
  { "lewis6991/gitsigns.nvim",
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } } },
  },

  -- ── Search & Replace Plugins ────────────────────────────────

  -- Telescope: find files, grep, etc.
  { "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-live-grep-args.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
      { "<leader>fw", "<cmd>Telescope lsp_workspace_symbols<cr>", desc = "Workspace symbols" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>fc", "<cmd>Telescope commands<cr>", desc = "Commands" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
      { "<leader>fo", "<cmd>Telescope vim_options<cr>", desc = "Options" },
      { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Git commits" },
      { "<leader>gb", "<cmd>Telescope git_branches<cr>", desc = "Git branches" },
      { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Git status" },
      { "<leader>fl", "<cmd>Telescope resume<cr>", desc = "Resume last search" },
      { "<leader>fy", "<cmd>Telescope highlights<cr>", desc = "Highlights" },
      { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "Marks" },
      { "<leader>f/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Fuzzy find in buffer" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/", "target/" },
          layout_strategy = "horizontal",
          layout_config = { horizontal = { preview_width = 0.55 } },
        },
        pickers = {
          find_files = { hidden = true, follow = true },
          live_grep = { additional_args = function() return { "--hidden" } end },
        },
        extensions = {
          fzf = { fuzzy = true, override_generic_sorter = true, override_file_sorter = true, case_mode = "smart_case" },
          live_grep_args = { auto_quoting = true },
          file_browser = { hidden = true, grouped = true },
        },
      })
      telescope.load_extension("fzf")
      telescope.load_extension("live_grep_args")
      telescope.load_extension("file_browser")
    end,
  },

  -- Hop: quick jump to any position
  { "smoka7/hop.nvim",
    keys = {
      { "s", "<cmd>HopChar1<cr>", desc = "Hop char" },
      { "S", "<cmd>HopWord<cr>", desc = "Hop word" },
      { "<leader>hw", "<cmd>HopWord<cr>", desc = "Hop word" },
      { "<leader>hl", "<cmd>HopLine<cr>", desc = "Hop line" },
      { "<leader>hp", "<cmd>HopPattern<cr>", desc = "Hop pattern" },
    },
    opts = { keys = "etovxqpdygfblzhckisuran" },
  },

  -- Flash: modern search & jump (hop successor)
  { "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
      { "s", function() require("flash").jump() end, desc = "Flash jump" },
      { "S", function() require("flash").treesitter() end, desc = "Flash treesitter" },
      { "<leader>fs", function() require("flash").treesitter() end, desc = "Flash treesitter" },
      { "<leader>fw", function() require("flash").grep() end, desc = "Flash grep" },
      { "<leader>fr", function() require("flash").treesitter_search() end, desc = "Flash treesitter search" },
    },
    opts = {
      search = { mode = "fuzzy" },
      jump = { autojump = true },
      highlight = { backdrop = false },
    },
  },

  -- Spectre: search & replace across project
  { "nvim-pack/nvim-spectre",
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Replace in project" },
      { "<leader>sp", function() require("spectre").open_visual({ select_word = true }) end, desc = "Replace word" },
      { "<leader>sw", function() require("spectre").open_file_search({ select_word = true }) end, desc = "Replace in file" },
    },
    opts = {
      color_devicons = true,
      live_update = false,
      line_sep_start = "┌───────────────────────────────────────",
      result_padding = "│  ",
      line_sep_end = "└───────────────────────────────────────",
    },
  },

  -- Grug-far: better search & replace (modern spectre)
  { "MagicDuck/grug-far.nvim",
    keys = {
      { "<leader>sg", "<cmd>GrugFar<cr>", desc = "Grug Far (project)" },
      { "<leader>sf", "<cmd>GrugFarFilter<cr>", desc = "Grug Far filter" },
    },
    opts = {
      replacement_window = "current",
      keymaps = { replace = "<leader>r", replaceAll = "<leader>R", close = "<leader>q", refresh = "<leader>f" },
    },
  },

  -- Abolish: smarter substitution (cr* for camelCase, cr- for kebab-case)
  { "tpope/vim-abolish", event = "VeryLazy" },

  -- Substitute: substitute word with motion
  { "gbprod/substitute.nvim",
    keys = {
      { "s", function() require("substitute").operator() end, desc = "Substitute" },
      { "ss", function() require("substitute").line() end, desc = "Substitute line" },
      { "S", function() require("substitute").visual() end, mode = "v", desc = "Substitute visual" },
      { "sx", function() require("substitute").exchange() end, desc = "Exchange" },
    },
    opts = {},
  },

  -- Word-join: join lines with gJ (no spaces)
  { "Wansmer/treesj",
    keys = {
      { "gJ", function() require("treesj").toggle() end, desc = "Toggle split/join" },
      { "gS", function() require("treesj").toggle({ split = { recursive = true } }) end, desc = "Toggle split/join recursive" },
    },
    opts = { use_default_keymaps = false, max_join_length = 150 },
  },

  -- Window commands (resize, swap, etc.)
  { "willothy/flatten.nvim",
    ft = "toggleterm",
    opts = {},
  },
}
