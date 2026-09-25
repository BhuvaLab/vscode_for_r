local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation.
-- NOTE: C-h/j/k/l are handled by vim-tmux-navigator (see lua/plugins/editor.lua)
-- so the same keys cross the Neovim/tmux boundary. Do not remap them here.

-- Buffers
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })

-- Splits
map("n", "<leader>|", "<C-w>v", { desc = "Split vertical" })
map("n", "<leader>-", "<C-w>s", { desc = "Split horizontal" })
map("n", "<leader>wd", "<C-w>c", { desc = "Close split" })

-- Move selected lines up/down, keeping indentation
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep the cursor centred when jumping
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Stay in indent mode when shifting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Diagnostics
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })

-- Quickfix
map("n", "<leader>xq", "<cmd>copen<CR>", { desc = "Open quickfix" })

-- Terminal: Esc leaves terminal mode (handy for the built-in terminal; the R
-- console lives in a tmux pane so you rarely need this)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
