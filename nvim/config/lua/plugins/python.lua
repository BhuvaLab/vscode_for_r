-- ============================================================================
--  Python REPL via vim-slime, sending to a TMUX PANE.
--
--  Deliberately the same mental model as R: code goes to a real tmux pane that
--  outlives Neovim and survives an SSH drop.
--
--  First send prompts for a target pane. Answer with the pane id shown by
--  `tmux list-panes` (e.g. %1), or accept the default. Change it later with
--  :SlimeConfig.
--
--  Typical flow:
--    prefix + |          split a tmux pane
--    ipython / python    start a REPL there
--    <leader>sl          send the current line/selection from Neovim
-- ============================================================================
return {
  {
    "jpalardy/vim-slime",
    ft = { "python", "quarto", "markdown", "sh" },
    init = function()
      vim.g.slime_target = "tmux"
      vim.g.slime_bracketed_paste = 1 -- keep indentation intact in the REPL
      vim.g.slime_default_config = {
        socket_name = "default",
        target_pane = "{last}", -- the most recently used other pane
      }
      vim.g.slime_dont_ask_default = 0
      vim.g.slime_no_mappings = 1
    end,
    keys = {
      { "<leader>sl", "<Plug>SlimeLineSend", desc = "Slime: send line" },
      { "<leader>sl", "<Plug>SlimeRegionSend", mode = "v", desc = "Slime: send selection" },
      { "<leader>sp", "<Plug>SlimeParagraphSend", desc = "Slime: send paragraph" },
      { "<leader>sc", "<cmd>SlimeConfig<CR>", desc = "Slime: choose target pane" },
    },
  },
}
