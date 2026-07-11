local opt = vim.opt

opt.backup = false
opt.swapfile = false
opt.undofile = true
opt.hlsearch = false
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.mousemodel = "extend"
opt.hidden = true
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.signcolumn = "yes"
opt.number = true
opt.relativenumber = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.showmode = false
opt.cmdheight = 0
opt.updatetime = 250
opt.timeoutlen = 300
opt.shortmess:append({ c = true, I = true })

vim.g.mapleader = " "
vim.g.maplocalleader = " "
