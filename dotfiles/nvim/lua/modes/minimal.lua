-- ═══════════════════════════════════════════════════════════════
-- Group: Minimal
-- Core essentials: basic picker, explorer, statusline, LSP, git signs
-- ═══════════════════════════════════════════════════════════════
return {
  -- Colorscheme
  { "scottmckendry/cyberdream.nvim", priority = 1000,
    config = function()
      require("cyberdream").setup({ transparent = true, italic_comments = true, terminal_colors = true })
      vim.cmd.colorscheme("cyberdream")
    end,
  },

  -- Telescope: classic picker
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>" },
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

  -- Icons
  { "echasnovski/mini.icons", config = function() require("mini.icons").setup() end },

  -- Commenting
  { "echasnovski/mini.comment", config = function() require("mini.comment").setup() end },

  -- Increment/decrement
  { "monaqa/dial.nvim",
    config = function()
      local a = require("dial.augend")
      require("dial.config").augends:register_group({ default = {
        a.integer.alias.decimal, a.constant.alias.bool,
      } })
    end,
    keys = {
      { "<C-a>", function() require("dial").augend() end, mode = { "n", "x" } },
      { "<C-x>", function() require("dial").augend() end, mode = { "n", "x" } },
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

  -- LSP (no mason, no completion)
  { "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      for _, s in ipairs({ "lua_ls", "pyright", "gopls" }) do
        lspconfig[s].setup({})
      end
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("ocws-lsp-diagnostic", { clear = true }),
        callback = function()
          vim.diagnostic.config({ virtual_text = true, signs = true, underline = true, float = { border = "rounded" } })
        end,
      })
    end,
  },

  -- Git signs (minimal)
  { "lewis6991/gitsigns.nvim", opts = { signs = {
    add = { text = "│" }, change = { text = "│" }, delete = { text = "_" },
    topdelete = { text = "‾" }, changedelete = { text = "~" } },
    on_attach = function(b)
      local gs = package.loaded.gitsigns
      vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, { buffer = b })
      vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, { buffer = b })
    end,
  } },
}
