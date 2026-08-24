# cplot

Transient plot display for Claude Code sessions in VS Code + R, built on the
session-watcher setup this repo already covers.

Ask Claude Code something like *"transform the counts, compute a UMAP, plot it"*
and the plot shows up in a VS Code panel automatically — no temp files to open by
hand, no `httpgd`-style server or port. Works for R and Python from the same
panel. Plotting code is kept as an editable, versioned "recipe", so a follow-up
like *"make the points smaller"* edits and re-renders rather than starting over.

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

## Usage

```bash
cplot serve                                        # once per project: opens the panel
cplot new umap-spanorm --lang r --env latest-r      # scaffold .plots/umap-spanorm/recipe.R
# edit the recipe, then:
cplot run umap-spanorm                              # renders; the open panel picks it up
```

**Only call `cplot serve` / `cplot open` once per session.** The VS Code webview API
always opens a *new* panel — it does not refresh an existing one — so calling it again
leaves you with duplicate panels to close by hand rather than one that updates. `cplot
run` never touches the panel; the open panel polls `.plots/_manifest.json` on its own
and picks up new versions automatically, which is how it stays live without needing to
be re-opened.

`cplot serve` also opens `.plots/_current.png` as a normal VS Code image tab — drag
that into a bottom editor group once and it keeps refreshing in place on every render,
independent of the gallery panel.

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

## Other commands

```
cplot list                 # every plot and its version count
cplot log <name>           # version history for one plot
cplot show <name> [vNNN] [--pin]   # --pin also puts it in the live tab
cplot export <name> --to figures/fig1.png --dpi 300 --size 12x8
cplot prune [--keep N]     # trim old versions (default: keep last 20)
cplot status               # what cplot currently knows about this project
```
