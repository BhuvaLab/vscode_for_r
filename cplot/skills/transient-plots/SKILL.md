---
name: transient-plots
description: Use when the user asks to plot, visualise, show, or look at data during interactive exploration or model prototyping - displays plots in a VS Code gallery panel via cplot, and keeps the plotting code as an editable, versioned recipe.
---

# Transient plots (cplot)

Display plots in a live VS Code gallery during a session, and keep the plotting
code so "make the points smaller" edits and re-renders rather than starting over.

Works for R and Python. `cp()` is the only API either language needs.

## Start of session

Run once, before the first plot. Idempotent - safe to repeat.

```bash
cplot serve
```

This writes the gallery page, opens it as a VS Code webview panel, and opens the
live `_current.png` tab. There is no server and no port. If it reports it does not
know the workspace path, ask the user to make one plot in an R terminal (httpgd
writes the path), or to run `cplot config --wd <workspace folder>`.

**Do not call `cplot serve` or `cplot open` again during a session.** Each call
spawns another panel - the extension never reuses one. New versions reach the open
panel by polling on their own. Re-open only if the gallery page itself changed.

## Making a plot

1. `cplot new <name> --lang r|py [--env <conda env>]` scaffolds
   `.plots/<name>/recipe.{R,py}`.
2. **Write the actual code into that file** with Write/Edit.
3. `cplot run <name>` renders it and prints the PNG path.
4. **Read the PNG.** Always. Check axes, legend placement, overplotting, and that
   the data is actually there before reporting the plot is done.

The display window has no menus by design — it is a plotting surface, not a
browser. Navigation is ←/→ between plots, ↑/↓ between versions of one plot, `c`
for code, `[`/`]` to zoom out/in centered on the pointer, click to reset to fit.
Mention this once if the user seems to be hunting for buttons that aren't there.

### Never inline the code

Do NOT use `Rscript -e`, `python -c`, or heredocs to draw plots. Code that is not
in a recipe file cannot be edited or re-run, which defeats the point of the tool.

### Naming

Use a stable slug describing the plot, not the request: `umap-spanorm`,
`qc-counts-per-cell`, `survival-k3-sex`.

## Modifying a plot

Edit the existing `recipe.{R,py}` and re-run the **same name**. Versions
accumulate under one plot and the gallery shows a diff between them. Do not
create a new name for a variation of an existing plot.

## Recipe conventions

Front matter, all optional except on scaffolding:

```r
#| name: umap-spanorm
#| env:  latest-r      # conda env; resolves the interpreter
#| size: 9x7           # inches
#| dpi:  150
```

Recipes run in a **fresh process** with cwd at the project root, so relative
data paths work as in the project's own scripts. There is no session state.

`cp(plot)` emits under the recipe name. `cp(plot, "suffix")` emits a second plot
as `<name>-<suffix>`. `cp(plot, svg=TRUE)` also writes SVG.

R `cp()` accepts ggplot/patchwork objects, a zero-argument function for base
graphics, `recordPlot()` output, or anything printable.
Python `cp()` accepts a Figure, an Axes, `None` for the current figure, or a
plotnine object.

## Cost and caching

Every run re-executes the whole recipe. For an expensive chain (SpaNorm on CosMx,
large UMAPs) that costs real minutes on each replot.

- Run slow recipes in the background rather than blocking the session.
- Add caching **only when the user asks**, and write it visibly in the recipe as
  an explicit read-or-compute against `.plots/_cache/`. Never cache silently.

## Format

PNG by default. Only add SVG when the plot is going into a paper or the user asks
- a scatter of hundreds of thousands of cells becomes an unusably large SVG. To
rescale, re-render the recipe at a new size/dpi rather than resampling an image.

## Promoting a plot

```bash
cplot export <name> --to figures/fig2a.png --dpi 300 --size 12x8
```

## Other commands

`cplot list`, `cplot log <name>`, `cplot show <name> [vNNN] [--pin]`,
`cplot prune`, `cplot status`, `cplot open`.

`--pin` copies an old version into `_current.png`, so "go back to the previous
version" is answerable without the user clicking anything.

## Constraints worth knowing

- **Never serve plots over HTTP.** The VS Code server may run on a different
  compute node than the session (seen: server on bun113, session on bun149), so
  `localhost` inside the webview is not ours and the panel renders black. The
  gallery works because it is a local file on the shared filesystem.
- The panel request must carry a `wd` inside the VS Code window's workspace, and
  that path is whatever VS Code thinks it is - a different alias for the same
  directory is silently rejected with no error. `cplot` caches it from
  `~/.vscode-R/request.log`; do not take it from `~/.claude/ide/*.lock`, which
  reports a different alias.
- Panels are never reused; see the warning above.
