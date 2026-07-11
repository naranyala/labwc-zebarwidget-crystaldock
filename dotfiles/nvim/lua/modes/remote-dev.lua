-- ═══════════════════════════════════════════════════════════════
-- Group: Remote dev
-- SSH, Docker, containers, remote editing, devcontainers
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
      ensure_installed = { "lua", "vim", "query", "python", "rust", "go", "typescript", "javascript", "dockerfile", "yaml", "hcl" },
      auto_install = true, highlight = { enable = true }, indent = { enable = true },
    },
  },

  -- LSP
  { "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({ ensure_installed = { "lua_ls", "pyright", "gopls", "dockerls", "yamlls", "tfls" }, automatic_installation = true })
      local lspconfig = require("lspconfig")
      lspconfig.dockerls.setup({})
      lspconfig.yamlls.setup({})
      lspconfig.tfls.setup({})
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

  -- ── Remote / Container Plugins ──────────────────────────────

  -- SSH config: manage SSH keys and hosts
  { "huy-hng/ssh-nvim",
    ft = "ssh",
    opts = {
      ssh_config = "~/.ssh/config",
      known_hosts = "~/.ssh/known_hosts",
    },
  },

  -- Docker: Dockerfile support
  { "huy-hng/dockerfile.nvim",
    ft = { "dockerfile", "docker-compose" },
    opts = {},
  },

  -- Docker compose: syntax highlighting and completion
  { "huy-hng/docker-compose.nvim",
    ft = { "yaml", "yml" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },

  -- Terraform: HCL, Terraform, Terragrunt support
  { "hashivim/vim-terraform",
    ft = { "terraform", "tf", "hcl" },
    opts = { terraform_fmt_on_save = true },
  },

  -- Ansible: playbooks, roles, templates
  { "pearofducks/ansible-vim",
    ft = "yaml",
    opts = {
      yaml_indent_less = 2,
      indent_jinja_template = 1,
      explicit_yaml = 1,
    },
  },

  -- Kubernetes: YAML support for k8s manifests
  { "cuducos/yaml.nvim",
    ft = "yaml",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<leader>ky", "<cmd>Telescope yaml_schema<cr>", desc = "YAML schema" },
    },
    opts = { schemas = {
      kubernetes = "k8s-*.yaml",
      ["https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/v1.28.0/all.json"] = "k8s-*.yaml",
      ["https://json.schemastore.org/docker-compose.json"] = "docker-compose*.{yml,yaml}",
    } },
  },

  -- DevContainers: open files in container
  -- { "huy-hng/devcontainer.nvim",
  --   ft = { "dockerfile", "yaml" },
  --   opts = {},
  -- },

  -- Remote-nvim: edit remote machines via SSH
  -- { "amitds1997/remote-nvim.nvim",
  --   keys = {
  --     { "<leader>rs", "<cmd>RemoteStart<cr>", desc = "Remote start" },
  --     { "<leader>rc", "<cmd>RemoteConnect<cr>", desc = "Remote connect" },
  --     { "<leader>rd", "<cmd>RemoteStop<cr>", desc = "Remote stop" },
  --   },
  --   opts = {},
  -- },

  -- Toggleterm: terminal for SSH, Docker, etc.
  { "akinsho/toggleterm.nvim", version = "*",
    keys = {
      { "<C-\\>", function() require("toggleterm").toggle(0) end, desc = "Toggle terminal" },
      { "<leader>tf", function() require("toggleterm").toggle(0, 15, "float") end, desc = "Floating terminal" },
    },
    opts = {
      size = 15,
      direction = "float",
      float_opts = { border = "curved" },
      shade_terminals = true,
    },
  },

  -- Lazygit: git UI in terminal
  { "kdheepak/lazygit.nvim",
    keys = { { "<leader>gg", "<cmd>LazyGit<cr>", desc = "Lazygit" } },
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
