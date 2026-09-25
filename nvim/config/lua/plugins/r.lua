-- ============================================================================
--  R.nvim - R console, code sending, object browser.
--
--  The console runs in a TMUX PANE, not a Neovim terminal buffer. That means:
--    * quitting Neovim does NOT kill R (auto_quit defaults to false here)
--    * an SSH drop leaves R alive - reattach with `tmux attach` and your
--      loaded data frames are still in memory
--    * resize/zoom the console with normal tmux keys (prefix + z to zoom)
--
--  <LocalLeader> is \  (see lua/config/options.lua)
--  Full keymap list: :RMapsDesc
-- ============================================================================
return {
  {
    "R-nvim/R.nvim",
    lazy = false, -- R.nvim is a filetype plugin; it self-activates on R/qmd files
    opts = {
      -- ---------------------------------------------------------------
      -- Console location
      -- ---------------------------------------------------------------
      -- Open R in a tmux pane to the right, taking 40% of the window width.
      -- A percentage (not a fixed column count) so it adapts to your terminal:
      -- a fixed "-l 80" squeezes Neovim to nothing on a narrow window.
      -- Use "tmux split-window -vf" instead for a full-width pane below.
      external_term = "tmux split-window -h -l 40%",

      -- Use OUR ~/.tmux.conf (prefix C-a, the navigator bindings, the theme).
      -- Without this R.nvim substitutes its own minimal tmux config.
      config_tmux = false,

      -- ---------------------------------------------------------------
      -- Which R to run
      -- ---------------------------------------------------------------
      -- radian: better console - syntax highlighting, multiline editing,
      -- proper history. R_cmd stays plain R for background tasks that need
      -- a vanilla interpreter.
      R_app = "radian",
      R_cmd = "R",
      R_args = { "--quiet", "--no-save" },

      -- radian does its own highlighting, so Neovim must not double-colour it.
      -- (R.nvim also forces this off when R_app contains "radian".)
      hl_term = false,

      -- radian needs bracketed paste for multi-line blocks to arrive intact.
      bracketed_paste = true,

      -- ---------------------------------------------------------------
      -- Startup behaviour
      -- ---------------------------------------------------------------
      auto_start = "on startup", -- start R when you open the first R/qmd file
      objbr_auto_start = false,  -- open the object browser on demand (\ro)

      -- ---------------------------------------------------------------
      -- Editing
      -- ---------------------------------------------------------------
      pipe_version = "native",   -- |> rather than %>% on the pipe keymap
      -- Built-in editing shortcuts (no option needed, listed here as a note):
      --   <M-->  in insert mode writes " <- "
      --   <M-r>  in insert mode inserts a ```{r} chunk skeleton in .qmd/.Rmd
      min_editor_width = 80,     -- keep the script pane usable when R opens

      -- Object browser geometry
      objbr_place = "script,right",
      objbr_w = 40,

      -- ---------------------------------------------------------------
      -- Output handling
      -- ---------------------------------------------------------------
      -- Rendered HTML/PDF can't open a GUI viewer over SSH; "no" stops R.nvim
      -- trying. Preview rendered Quarto docs with \qp (see quarto.lua) or by
      -- forwarding a port - see the httpgd note in lua/plugins/quarto.lua.
      open_html = "no",
      open_pdf = "no",

      -- Built-in LSP features (Neovim 0.11+). This is what provides R
      -- completion, hover and go-to-definition - including inside Quarto
      -- chunks. r_language_server's completion is disabled in lsp.lua so the
      -- two don't produce duplicate menu entries.
      -- NOTE: the option key is `r_ls`, not `lsp`. These all default to true;
      -- they are spelled out so it is obvious what R.nvim's own LSP provides.
      -- Quarto YAML frontmatter completion additionally needs
      -- yaml-language-server (installed at ~/.local/bin/yaml-language-server).
      r_ls = {
        completion = true,
        hover = true,
        signature = true,
        definition = true,
        references = true,
        document_symbol = true,
        document_highlight = true,
        rename = true,
        -- Completion inside dplyr/ggplot calls knows the data frame's columns.
        fun_data_1 = { "select", "rename", "mutate", "filter", "arrange", "group_by", "summarise" },
        fun_data_2 = { ggplot = { "aes" }, with = { "*" } },
      },

      hook = {
        after_config = function()
          -- Highlight other references to the symbol under the cursor.
          vim.api.nvim_create_autocmd("CursorHold", {
            pattern = { "*.R", "*.r", "*.qmd", "*.Rmd" },
            callback = function() vim.lsp.buf.document_highlight() end,
          })
          vim.api.nvim_create_autocmd("CursorMoved", {
            pattern = { "*.R", "*.r", "*.qmd", "*.Rmd" },
            callback = function() vim.lsp.buf.clear_references() end,
          })
        end,
      },
    },
  },
}
