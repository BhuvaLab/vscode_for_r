-- ============================================================================
--  Treesitter - syntax highlighting plus the injected-language parsing that
--  lets otter.nvim find R/Python code inside ```{r} fences in .qmd files.
--
--  BRANCH NOTE: this pins `main`, not `master`. On Neovim 0.12 the master
--  branch crashes in its `set-lang-from-info-string!` directive - the handler
--  for markdown fenced code blocks - because 0.12 hands query captures back as
--  a LIST of nodes rather than a single node. That breaks exactly the
--  injection Quarto chunks rely on. The `main` rewrite is the 0.11+ supported
--  branch and handles this correctly.
--
--  `main` has a different API from `master`: no `highlight`/`indent` module
--  tables. Highlighting is started per-buffer with vim.treesitter.start().
-- ============================================================================
local ensure_installed = {
  "r", "python", "markdown", "markdown_inline", "yaml", "bash",
  "lua", "vim", "vimdoc", "query", "json", "toml", "csv",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})

      -- Install any parser that isn't present yet (no-op once warmed up).
      local installed = require("nvim-treesitter").get_installed("parsers")
      local have = {}
      for _, p in ipairs(installed) do have[p] = true end
      local missing = {}
      for _, p in ipairs(ensure_installed) do
        if not have[p] then missing[#missing + 1] = p end
      end
      if #missing > 0 then require("nvim-treesitter").install(missing) end

      -- Start highlighting + treesitter indent for the filetypes we care about.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "r", "rmd", "quarto", "python", "markdown", "yaml",
          "bash", "sh", "lua", "json", "toml", "csv", "vim",
        },
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
