# cplot

Transient plot display for Claude Code sessions in VS Code + R, built on the
session-watcher setup this repo already covers.

Ask Claude Code something like *"transform the counts, compute a UMAP, plot it"*
and the plot shows up in a VS Code panel automatically — no temp files to open by
hand, no `httpgd`-style server or port. Works for R and Python from the same
panel. Plotting code is kept as an editable, versioned "recipe", so a follow-up
like *"make the points smaller"* edits and re-renders rather than starting over.

Everything is scoped to **one Claude session**: plots live outside the project
entirely, in a per-session cache directory, and disappear once that session ends
(and something next touches `cplot` — see [Session scoping](#session-scoping)
below). Two Claude sessions in the same project each get their own plots and
their own panel.

Working in the terminal instead (a `herdr-srun` workbench on Bunya)? The same
recipes and commands work there — see [In a terminal (herdr)](#in-a-terminal-herdr).

## How it works

vscode-R's session watcher (the same `~/.vscode-R/init.R` / `.vsc.attach()`
machinery this repo's `.Rprofile` fix targets) supports opening a **local file**
as a VS Code webview panel — no `httpgd`, no port, no port-forwarding. `cplot`
piggybacks on that: it writes a small HTML gallery to disk and asks the watcher
to open it, entirely through a JSON file drop (`~/.vscode-R/request.log` +
`request.lock`), the same protocol `httpgd` itself uses.

Two consequences worth knowing before you rely on it:

- **The R session watcher must be active in that VS Code window** — this is
  exactly what section 4 of the main README's `.Rprofile` block sets up. If
  `.vsc.attach` doesn't exist per that README's troubleshooting section, `cplot`
  won't be able to open its panel either.
- **The panel loads the gallery file over the shared filesystem**, not a
  network request. On Bunya (GPFS, same setup this repo targets) that's a
  non-issue. If you're driving a VS Code server on a machine that can't see the
  session's filesystem at all, this won't work — everything here assumes the
  same environment the rest of this repo assumes.

## Install

```bash
bash cplot/install.sh --dry-run
bash cplot/install.sh
```

Installs `~/.local/bin/cplot` (make sure that's on `PATH`), the R/Python
plotting shims under `~/.local/share/cplot/`, and — if `~/.claude` exists — the
`transient-plots` Claude Code skill, so Claude picks this up automatically
instead of writing plots to temp files.

Requires `conda` (or `mamba`) to be resolvable — either on `PATH` or via
`$CONDA_EXE` (which `conda init` sets up in your shell already). `cplot` uses
`conda env list --json` to find environments, so it works with any conda
distribution and any environment location, including ones outside the default
`envs_dirs`.

## Session scoping

Nothing `cplot` writes lives inside the project. Everything goes under:

```
~/.cache/cplot/<project-slug>-<hash>/<session-id>/
```

keyed to `$CLAUDE_CODE_SESSION_ID` — one directory per Claude session, per
project. `cplot status` prints the exact path for the session you're in.

Cleanup happens by liveness, not a hook: every `cplot` invocation (from any
session, in any project) checks sibling session directories against
`$CLAUDE_PID` and deletes any whose process has exited. So a session's plots
disappear once it ends and *something* next runs `cplot` — usually close to
immediate in practice, not guaranteed to be the exact instant the session closes.
Run outside Claude Code (no `$CLAUDE_CODE_SESSION_ID` set) and everything falls
back to a single shared `default` scope, kept until you clear it by hand.

Because scoping is per-session, two Claude sessions working the same project get
separate plots and separate panels automatically — nothing to configure.

## Usage

```bash
cplot serve                                        # once per session: opens the panel
cplot new umap-spanorm --lang r --env latest-r      # scaffold this session's recipe
# edit the recipe, then:
cplot run umap-spanorm                              # renders; the open panel picks it up
```

**Only call `cplot serve` / `cplot open` once per session.** The VS Code webview API
always opens a *new* panel — it does not refresh an existing one — so calling it again
leaves you with duplicate panels to close by hand rather than one that updates. `cplot
run` never touches the panel; the open panel polls this session's manifest on its own
and picks up new versions automatically, which is how it stays live without needing to
be re-opened.

`cplot serve` also opens this session's `_current.png` as a normal VS Code image tab —
drag that into a bottom editor group once and it keeps refreshing in place on every
render, independent of the gallery panel.

A recipe is a plain script with a small front-matter block:

```r
#| name: umap-spanorm
#| env:  latest-r
#| title:   UMAP after SpaNorm
#| caption: One concise sentence on what the plot shows.
#| size: 9x7
#| dpi:  150

sce <- readRDS("data/sce.rds")
p <- ggplot(...) + geom_point(size = 0.2)
cp(p)
```

`cp()` is the whole API in R and Python — pass a ggplot/Figure/Axes and it
renders under the recipe's name, versioned (`v001.png`, `v002.png`, …) each time
you re-run it. Nothing is cached between runs unless the recipe explicitly does
so — every run is a fresh process, on purpose.

## In the panel

| Key / action | Effect |
|---|---|
| `←` / `→` | switch between plots |
| `↑` / `↓` | step through versions of the current plot |
| `c` | toggle the recipe's code, diffed against the previous version |
| `[` / `]` | zoom out / in, centered on the pointer |
| click | reset to fit |

No menus by design — it's meant to sit as a plotting window inside the editor,
not a browser tab.

## In a terminal (herdr)

Inside a [herdr](../nvim/README.md) pane — locally, or in a `herdr-srun`
workbench on a Bunya compute node — `cplot serve` opens a `cplot` pane to the
right instead of a VS Code panel. That pane runs `cplot view`, which draws each
plot with the Kitty graphics protocol. The image bytes travel inside the
terminal stream itself, so they follow the same ssh → login node → `srun` →
herdr hop your text does: still no server, no port, no tunnel.

```
+---------------------------+-----------------------------+
| claude                    | cplot                       |
|                           |  umap-spanorm  v003 (3/3)   |
|  > make the points        |  +-----------------------+  |
|    smaller                |  |        (the plot)     |  |
|                           |  +-----------------------+  |
|                           |  ←→ plot ↑↓ version c code  |
+---------------------------+-----------------------------+
```

Unlike the VS Code panel, the pane is **reused**: its id is remembered for the
session, so calling `cplot serve` again just reports the pane that's already
open. It follows new renders on its own and closes itself once the session's
plots are swept.

| Key | Effect |
|---|---|
| `←` / `→` (or `h` / `l`) | switch between plots |
| `↑` / `↓` (or `k` / `j`) | step through versions (scrolls in code view) |
| `c` | toggle the recipe's code, diffed against the previous version |
| `z` | zoom the pane to full window and back (herdr) |
| `r` | redraw |
| `q` | close the viewer |

Requirements:

- **A Kitty-graphics terminal on your own machine** — Ghostty, kitty or WezTerm.
  macOS Terminal.app can't show the images, and iTerm2 currently doesn't through
  herdr. None of these need admin: `brew install --cask --appdir="$HOME/Applications" ghostty`.
- **herdr's `[terminal] kitty_graphics = true`** (the default; set explicitly in
  [`nvim/herdr/config.toml`](../nvim/herdr/config.toml)).
- **ssh, not mosh** — mosh drops the graphics.

The footer shows how the viewer is drawing: `[kitty]`, or `[chafa]` / `[text]`
when the terminal doesn't answer the Kitty graphics query (character-art via
`chafa` if installed, otherwise just the PNG path). Outside herdr you can run the
viewer by hand in any Kitty-graphics terminal: `cplot view` (this session) or
`cplot view --dir <path from cplot status>`. `--term` / `--vscode` on `serve`
force one display or the other.

The pane is smaller than the webview; for a full-resolution look, `cplot export`
the plot, or `z` to zoom the pane.

## Other commands

```
cplot list                 # every plot and its version count
cplot log <name>           # version history for one plot
cplot show <name> [vNNN] [--pin]   # --pin also puts it in the live tab
cplot export <name> --to figures/fig1.png --dpi 300 --size 12x8
cplot prune [--keep N]     # trim old versions (default: keep last 20)
cplot status               # session id, cache path, what cplot currently knows
```

## Deleting plots

```bash
cplot clear <name>                  # delete a whole plot, every version
cplot clear <name> --version vNNN   # delete just one version
cplot clear --all                   # delete every plot in this session
```

There's no delete control in the panel itself — it's a passive local file with no
way to write back to disk, so deletion is always a command.
