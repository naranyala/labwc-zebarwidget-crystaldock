-- ═══════════════════════════════════════════════════════════════
-- Group: Popup Everything
-- No notifications, no command-line, all UI in floating windows
-- Noice, dressing, fidget, notify, mini.pick, popup
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "catppuccin/nvim", priority = 1000, name = "catppuccin",
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
        integrations = { noice = true, mason = true, telescope = { enabled = true }, gitsigns = true },
      })
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },

  -- Snacks
  { "folke/snacks.nvim", priority = 950, lazy = false,
    opts = {
      notifier = { enabled = true, style = "compact", top_down = true },
      animate = { enabled = true },
      scroll = { enabled = true },
    },
  },

  -- Oil
  { "stevearc/oil.nvim", dependencies = { "echasnovski/mini.icons" },
    opts = { default_file_explorer = true, skip_confirm_for_simple_edits = true,
      float = { border = "rounded" },
    },
  },

  -- Lualine
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "catppuccin", section_separators = "", component_separators = "" } },
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
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP + Mason + Nvim-cmp
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      local caps = require("cmp_nvim_lsp").default_capabilities()
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do lspconfig[s].setup({ capabilities = caps }) end
    end,
  },
  { "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path", "L3MON4D3/LuaSnip" },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = { expand = function(a) require("luasnip").lsp_expand(a.body) end },
        mapping = cmp.mapping.preset.insert({ ["<CR>"] = cmp.mapping.confirm({ select = true }) }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" } }, { name = { "buffer" } }),
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
  },

  -- Git signs
  { "lewis6991/gitsigns.nvim",
    opts = { signs = { add = { text = "│" }, change = { text = "│" }, delete = { text = "_" } } },
  },

  -- ── Popup Everything Plugins ────────────────────────────────

  -- Noice: replace cmdline + messages + LSP progress with beautiful popups
  { "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = function()
      require("noice").setup({
        cmdline = {
          view = "cmdline",
          format = {
            cmdline = { icon = "" },
            search_down = { icon = "  " },
            search_up = { icon = "  " },
            lua = { icon = "" },
            help = { icon = "" },
          },
        },
        messages = { view = "notify", view_error = "notify", view_warn = "notify", view_history = "messages", view_search = "virtualtext" },
        popupmenu = { enabled = true, backend = "nui" },
        lsp = {
          progress = { enabled = true, format = "lsp_progress", format_done = "lsp_progress_done", view = "mini" },
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          lsp_doc_border = true,
        },
        routes = {
          { filter = { event = "msg_show", kind = "", find = "written" }, opts = { skip = true } },
        },
      })
    end,
  },

  -- Fidget: LSP progress spinner (mini notifications)
  { "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      notification = {
        window = { winblend = 0, border = "none" },
        configs = { default = require("fidget.notification").default_config },
      },
      progress = { suppress_on_insert = true },
    },
  },

  -- Dressing: beautiful vim.ui.select and vim.ui.input
  { "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {
      input = {
        enabled = true,
        default_prompt = "Input:",
        win_options = { winhighlight = "Normal:Normal" },
        border = "rounded",
        relative = "editor",
      },
      select = {
        enabled = true,
        backend = { "telescope" },
        telescope = {
          layout_strategy = "cursor",
          layout_config = { width = 0.5, height = 0.4, prompt_position = "top" },
        },
      },
    },
  },

  -- Notify: beautiful notifications
  { "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts = {
      timeout = 2000,
      max_height = function() return math.floor(vim.o.lines * 0.75) end,
      max_width = function() return math.floor(vim.o.columns * 0.75) end,
      stages = "fade_in_slide_out",
      background_colour = "Normal",
      render = "compact",
      top_down = true,
    },
  },

  -- Popui: popup input/select
  -- { "hood/popui.nvim",
  --   event = "VeryLazy",
  --   dependencies = { "Raimondi/delimitMate" },
  --   config = function()
  --     vim.ui.select = require("popui").input
  --     vim.ui.input = require("popui").input
  --   end,
  -- },

  -- Floating winbar
  { "b0o/incline.nvim",
    event = "VeryLazy",
    opts = {
      highlight = { groups = { InclineNormal = { guibg = "#3b4261", guifg = "#a6accd" } } },
      window = { options = { winblend = 0 } },
      render = function(props)
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":~:.")
        if filename == "" then filename = "[No Name]" end
        return { { " " .. filename .. " ", guifg = "#a6accd", guibg = "#3b4261" } }
      end,
    },
  },

  -- Telescope borders
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          border = true,
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          layout_strategy = "horizontal",
        },
      })
    end,
  },

  -- Mini.pick: floating picker
  { "echasnovski/mini.pick",
    keys = {
      { "<leader>fp", "<cmd>Pick files<cr>", desc = "Pick files" },
      { "<leader>fg", "<cmd>Pick grep_live<cr>", desc = "Grep live" },
      { "<leader>fb", "<cmd>Pick buffers<cr>", desc = "Buffers" },
    },
    config = function()
      require("mini.pick").setup({
        mappings = {
          choose = "<CR>",
          choose_marked = "<C-q>",
          move_down = "<C-j>",
          move_up = "<C-k>",
          move_start = "<C-g>",
        },
        window = {
          config = { border = "rounded" },
          prompt_pos = "top",
        },
      })
    end,
  },

  -- Notify: terminal notification
  { "rcarriga/nvim-notify",
    keys = {
      { "<leader>nd", function() require("notify").dismiss() end, desc = "Dismiss notifications" },
    },
  },
}
