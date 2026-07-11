local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>w", "<cmd>write<CR>")
map("n", "<leader>q", "<cmd>q<CR>")
map("n", "<leader>Q", "<cmd>qa<CR>")
map("n", "<leader>n", "<cmd>bnext<CR>")
map("n", "<leader>p", "<cmd>bprevious<CR>")
map("n", "<leader>bd", "<cmd>bd<CR>")
map("n", "<leader>u", "<cmd>Lazy<CR>")

-- LSP (available in all groups with LSP)
map("n", "<leader>ca", vim.lsp.buf.code_action)
map("n", "gd", vim.lsp.buf.definition)
map("n", "K", vim.lsp.buf.hover)
map("n", "<leader>rn", vim.lsp.buf.rename)
map("n", "<leader>D", vim.lsp.buf.type_definition)
map("n", "[d", vim.diagnostic.goto_prev)
map("n", "]d", vim.diagnostic.goto_next)

-- Yank to system clipboard
map({ "n", "v" }, "Y", [["+Y]])

-- Better navigation
map("n", "j", "gj", { desc = "Move down visually" })
map("n", "k", "gk", { desc = "Move up visually" })

-- Lazy-load safe: require only when pressed, silently skip if missing
local safe = function(mod, fn)
  return function()
    local ok, m = pcall(require, mod)
    if ok then fn(m) end
  end
end

map("n", "<leader>e", safe("oil", function(o) o.open() end))
map("n", "<leader>ff", safe("snacks", function(s) s.picker.files() end))
map("n", "<leader>fg", safe("snacks", function(s) s.picker.grep() end))
map("n", "<leader>fb", safe("snacks", function(s) s.picker.buffers() end))
map("n", "<leader>fh", safe("snacks", function(s) s.picker.help() end))
map("n", "<leader>sr", safe("snacks", function(s) s.picker.resume() end))
map("n", "<leader>gs", safe("snacks", function(s) s.picker.git_status() end))
map("n", "<leader>gc", safe("snacks", function(s) s.picker.git_log() end))
map("n", "<leader>gb", safe("snacks", function(s) s.picker.git_branches() end))
map("n", "<leader>d", safe("dial", function(d) d.augment.create() end), { expr = true })
map("n", "<leader>cf", safe("conform", function(c) c.format({ async = true, lsp_format = "fallback" }) end), { desc = "Format file" })
map("n", "<leader>li", safe("lint", function(l) l.try_lint() end), { desc = "Lint file" })

map({ "n", "x" }, "p", "<Plug>(yanky-paste-after)")
map({ "n", "x" }, "P", "<Plug>(yanky-paste-before)")
map("n", "y", "<Plug>(yanky-yank)")
map("n", "[y", "<Plug>(yanky-cycle-forward)")
map("n", "]y", "<Plug>(yanky-cycle-backward)")

map("t", "<Esc>", "<C-\\><C-n>")
