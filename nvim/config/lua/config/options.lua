-- Leader keys. Must be set before lazy.nvim loads any plugin.
--
-- <leader>      = Space  (general editor commands)
-- <localleader> = \      (R.nvim commands - kept at the R.nvim default so the
--                         upstream docs and :RMapsDesc match what you type)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

-- Appearance
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"        -- stop the text jitter when diagnostics appear
opt.termguicolors = true      -- truecolor; tmux.conf passes it through
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.showmode = false          -- the statusline already shows it
opt.laststatus = 3            -- one global statusline, not one per split
opt.splitbelow = true
opt.splitright = true
opt.conceallevel = 2          -- render markdown/quarto markup

-- Indentation: 2 spaces, the tidyverse/Quarto convention
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Files: undo survives restarts, no swap/backup clutter on networked storage
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.updatetime = 250          -- faster CursorHold -> diagnostics, doc highlight
opt.timeoutlen = 400

-- Autoread: tmux focus-events makes this fire when you switch panes, so a file
-- changed by an R script or git pull refreshes without prompting.
opt.autoread = true

-- Completion behaviour
opt.completeopt = { "menu", "menuone", "noselect" }

-- OSC 52 clipboard. This host has no DISPLAY, so xsel cannot reach a
-- clipboard. OSC 52 pushes yanks through tmux and SSH to your LOCAL machine.
-- Paired with `set -g set-clipboard on` in ~/.tmux.conf.
vim.g.clipboard = {
  name = "OSC52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    -- OSC 52 reads are widely blocked by terminals for security, so paste
    -- falls back to Neovim's own register contents.
    ["+"] = function() return vim.split(vim.fn.getreg("") or "", "\n") end,
    ["*"] = function() return vim.split(vim.fn.getreg("") or "", "\n") end,
  },
}
opt.clipboard = "unnamedplus"

-- Treat Quarto files as their own filetype (R.nvim and quarto-nvim key off it)
vim.filetype.add({ extension = { qmd = "quarto" } })
