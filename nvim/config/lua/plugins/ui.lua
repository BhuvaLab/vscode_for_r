-- ============================================================================
--  Appearance. The tokyonight palette here is the same one used for the tmux
--  status bar in ~/.tmux.conf, so the two don't clash.
-- ============================================================================
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000, -- load before everything else so nothing flashes
    opts = {
      style = "night",
      transparent = false,
      styles = { comments = { italic = true }, keywords = { italic = false } },
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "tokyonight",
        globalstatus = true,
        section_separators = "",
        component_separators = "|",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          -- Show which conda env the LSP will introspect - catches the
          -- "why are my completions from the wrong env" problem early.
          {
            function()
              local c = os.getenv("CONDA_PREFIX")
              return c and ("conda:" .. vim.fn.fnamemodify(c, ":t")) or ""
            end,
          },
          "encoding",
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
}
