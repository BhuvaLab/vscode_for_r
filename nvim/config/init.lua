-- ============================================================================
--  Neovim config - R / Quarto first, Python second. Built for tmux over SSH.
--  Layout:
--    lua/config/options.lua   editor settings + leader keys
--    lua/config/lazy.lua      plugin manager bootstrap
--    lua/config/keymaps.lua   non-plugin keymaps
--    lua/plugins/*.lua        one file per concern
-- ============================================================================

require("config.options") -- must run first: sets leader before lazy loads
require("config.lazy")
require("config.keymaps")
