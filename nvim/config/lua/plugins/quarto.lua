-- ============================================================================
--  Quarto support.
--
--  The important piece is otter.nvim. In a .qmd file the R and Python code
--  lives inside ```{r} fences, which to a language server looks like plain
--  markdown - so without otter you get NO completion or diagnostics inside
--  chunks. otter maintains a hidden buffer per embedded language and forwards
--  LSP requests to the right server.
--
--  PLOTS OVER SSH: httpgd (already in your R library) serves plots to a web
--  page. On a login node you need a forwarded port to see it. From your LOCAL
--  machine:
--      ssh -L 8080:localhost:8080 $USER@bunya.rcc.uq.edu.au
--  then in R:
--      httpgd::hgd(port = 8080, host = "localhost")
--      httpgd::hgd_browse()   # prints the URL - open it locally
-- ============================================================================
return {
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "markdown" },
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      lspFeatures = {
        enabled = true,
        chunks = "curly", -- only treat ```{r} fenced blocks as code
        languages = { "r", "python", "bash", "yaml" },
        diagnostics = { enabled = true, triggers = { "BufWritePost" } },
        completion = { enabled = true },
      },
      -- quarto-nvim's own code runner is DISABLED on purpose: R.nvim already
      -- provides chunk sending for .qmd files (\\rr run chunk, \\ra run all)
      -- and enabling both makes them fight over the same keymaps.
      -- Python chunks are sent with vim-slime instead - see plugins/python.lua.
      codeRunner = { enabled = false },
      keymap = {
        hover = "K",
        definition = "gd",
        rename = "<leader>rn",
        references = "gr",
      },
    },
    keys = {
      { "<leader>qp", function() require("quarto").quartoPreview() end, desc = "Quarto preview" },
      { "<leader>qq", function() require("quarto").quartoClosePreview() end, desc = "Quarto close preview" },
      { "<leader>qa", function() require("otter").activate() end, desc = "Otter activate (chunk LSP)" },
    },
  },

  {
    "jmbuhr/otter.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      lsp = {
        diagnostic_update_events = { "BufWritePost" },
      },
      buffers = {
        set_filetype = true,
        write_to_disk = false,
      },
      handle_leading_whitespace = true,
    },
  },
}
