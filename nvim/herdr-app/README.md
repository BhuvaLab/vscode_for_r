# Herdr desktop app: rich agents sidebar

`nvim/herdr/config.toml` styles the **herdr TUI** (`herdr` / `herdr-srun`, e.g. on
Bunya or a Mac terminal). The **Herdr desktop app** (`herdr-app` + `herdr-core`/`hc`,
the Windows install) ignores that file: its sidebar is a JavaScript mod and
there is no `herdr pane report-metadata`. This folder gives the app the same
per-agent details.

| TUI piece | Desktop-app equivalent |
|---|---|
| `[ui.sidebar.agents.rows_by_agent] claude` rows | `mods/agents-rich` (shipped `agents` mod + a detail block) |
| `statusline.sh` → `herdr pane report-metadata` tokens | `statusline.sh` → `hc label $HC_TERMINAL_ID claude.*=…` |
| `status_indicators = "dots"` | built in (spinner = working, dot = done, ring = idle) |

Each Claude row reads:

```
~ · session title                 <1m ◌
Opus 5.5 · medium
⛁ 11% (107k)  $1.43   [cache 62% when < 80%]
```

and each Claude session shows the same status line as on the TUI:
`~/proj > main *     ctx █─────── 11% 107k/1M · cache 98% · $1.43 > Opus 5.5 · medium`.

## Install

Git Bash, with the Herdr app open:

```bash
winget install jqlang.jq     # then copy jq.exe onto a PATH dir Claude already sees:
cp "$LOCALAPPDATA"/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe ~/.local/bin/
bash nvim/herdr-app/install.sh
```

It installs `~/.claude/statusline.sh`, merges `statusLine` into
`~/.claude/settings.json` (backup kept), copies the mod into
`~/.config/herdr-app/mods/agents-rich`, and clones the shipped `main` layout
as `vscode-for-r` with the agents block pointed at the mod. Switch back any time with
`Ctrl-Shift-L` or `herdr-app do layout.switch '{"name":"main"}'`.

## Notes

- `mods/agents-rich/main.js` is a clone of Herdr 0.1.16's `agents` mod; the
  additions are `metaLine()` and the `labelsOf` lookup (search `vscode_for_r`).
  Shipped mods are replaced on app updates but clones are not, so after a big
  Herdr update re-clone `agents` and re-apply those two pieces if the sidebar
  misses new features.
- The status line runs under Git Bash on Windows: it converts `C:\…` paths with
  `cygpath`, strips jq.exe's CRLF, and avoids `bc` (not shipped with Git Bash).
