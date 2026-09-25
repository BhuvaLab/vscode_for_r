-- ============================================================================
--  Editor behaviour: tmux navigation, file tree, git signs, which-key.
-- ============================================================================
return {
  -- Ctrl+h/j/k/l moves between Neovim splits AND tmux panes with one set of
  -- keys. The matching half of this lives in ~/.tmux.conf.
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    cmd = {
      "TmuxNavigateLeft", "TmuxNavigateDown",
      "TmuxNavigateUp", "TmuxNavigateRight", "TmuxNavigatePrevious",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Go to left split/pane" },
      { "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Go to below split/pane" },
      { "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Go to above split/pane" },
      { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Go to right split/pane" },
    },
  },

  -- File tree
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle file tree" },
    },
    opts = {
      close_if_last_window = true,
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = false, -- inotify is unreliable on networked FS
        filtered_items = { hide_dotfiles = false, hide_gitignored = true },
      },
      window = { width = 32 },
    },
  },

  -- Git change indicators in the sign column
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "^" },
        changedelete = { text = "~" },
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = bufnr, desc = "Git: " .. desc })
        end
        map("]c", function() gs.nav_hunk("next") end, "Next hunk")
        map("[c", function() gs.nav_hunk("prev") end, "Previous hunk")
        map("<leader>gp", gs.preview_hunk, "Preview hunk")
        map("<leader>gb", gs.blame_line, "Blame line")
        map("<leader>gr", gs.reset_hunk, "Reset hunk")
      end,
    },
  },

  -- Popup showing what keys are available after a prefix
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>q", group = "quarto" },
        { "<leader>s", group = "slime (python repl)" },
        { "<leader>w", group = "window" },
        { "<leader>x", group = "diagnostics" },
      },
    },
  },

  -- Auto-close brackets and quotes
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
}
