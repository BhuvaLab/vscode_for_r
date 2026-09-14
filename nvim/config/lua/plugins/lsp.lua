-- ============================================================================
--  Language servers.
--
--  Uses Neovim 0.11+'s native vim.lsp.config / vim.lsp.enable API.
--  nvim-lspconfig is present only to supply the per-server default configs
--  (cmd, root markers, filetypes); it no longer does the enabling itself.
--
--  Servers:
--    r_language_server  R diagnostics (lintr) + formatting (styler).
--                       Its COMPLETION is switched off in on_attach because
--                       R.nvim ships its own R completion provider and two
--                       sources produce duplicate menu entries.
--    basedpyright       Python types, completion, go-to-definition.
--    ruff               Python lint + format (fast).
--    yamlls             Quarto _quarto.yml and YAML frontmatter.
-- ============================================================================

-- Resolve which Python the servers should introspect.
-- Priority: project .venv  ->  active conda env  ->  whatever is on PATH.
-- This is why `conda activate myenv && nvim` gives you that env's
-- packages without touching this config.
local function resolve_python()
  local cwd = vim.fn.getcwd()
  for _, venv in ipairs({ cwd .. "/.venv/bin/python", cwd .. "/venv/bin/python" }) do
    if vim.uv.fs_stat(venv) then return venv end
  end
  local conda = os.getenv("CONDA_PREFIX")
  if conda and vim.uv.fs_stat(conda .. "/bin/python") then
    return conda .. "/bin/python"
  end
  return vim.fn.exepath("python3")
end

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      local caps = require("blink.cmp").get_lsp_capabilities()

      -- ---------------------------------------------------------------
      -- Diagnostics display
      -- ---------------------------------------------------------------
      vim.diagnostic.config({
        virtual_text = { spacing = 2, prefix = "*" },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = true },
      })

      -- ---------------------------------------------------------------
      -- Per-server settings
      -- ---------------------------------------------------------------
      vim.lsp.config("*", { capabilities = caps })

      vim.lsp.config("r_language_server", {
        capabilities = caps,
        settings = {
          r = {
            lsp = {
              diagnostics = true,
              rich_documentation = false,
            },
          },
        },
        -- Strip completion so R.nvim is the single source of R completions.
        on_attach = function(client, _)
          client.server_capabilities.completionProvider = nil
        end,
      })

      vim.lsp.config("basedpyright", {
        capabilities = caps,
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "standard", -- "strict" is noisy on analysis code
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly", -- don't crawl /scratch projects
            },
          },
          python = { pythonPath = resolve_python() },
        },
      })

      vim.lsp.config("ruff", {
        capabilities = caps,
        on_attach = function(client, _)
          -- basedpyright owns hover; ruff would otherwise duplicate it.
          client.server_capabilities.hoverProvider = false
        end,
      })

      vim.lsp.config("yamlls", {
        capabilities = caps,
        settings = {
          yaml = { keyOrdering = false, schemaStore = { enable = true } },
        },
      })

      vim.lsp.enable({ "r_language_server", "basedpyright", "ruff", "yamlls" })

      -- ---------------------------------------------------------------
      -- Keymaps, bound only once a server actually attaches
      -- ---------------------------------------------------------------
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local function map(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = args.buf, desc = "LSP: " .. desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("gi", vim.lsp.buf.implementation, "Implementation")
          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
        end,
      })

      -- Report which interpreter was picked - useful when completions look wrong
      vim.api.nvim_create_user_command("PythonPath", function()
        vim.notify("LSP Python: " .. resolve_python(), vim.log.levels.INFO)
      end, { desc = "Show the Python interpreter the LSP is using" })
    end,
  },
}
