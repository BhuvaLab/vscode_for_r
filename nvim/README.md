# nvim: Neovim + tmux for R and Quarto

A terminal alternative to this repo's VS Code workflow, for the same job:
editing `.qmd` and `.R` files on Bunya with a live R console, completion,
diagnostics, and Quarto preview — over SSH, surviving dropped connections.

Use this instead of VS Code when you want a session that outlives your laptop
closing, or when a tunnel is more trouble than it's worth. The two setups are
independent: installing this changes nothing about your VS Code setup.

## What you get

- **Neovim 0.12** with [lazy.nvim](https://github.com/folke/lazy.nvim), configured from scratch — no distro to learn
- **[R.nvim](https://github.com/R-nvim/R.nvim)** — R console, send-chunk, object browser, `View()`, help
- **The R console runs in a tmux pane**, not inside Neovim: quitting the editor
  doesn't kill R, and an SSH drop leaves your data frames loaded
- **[quarto-nvim](https://github.com/quarto-dev/quarto-nvim) + [otter.nvim](https://github.com/jmbuhr/otter.nvim)** — completion and diagnostics *inside* ```` ```{r} ```` chunks, which is the part most ad-hoc setups miss
- **Python**: basedpyright + ruff, following whichever conda env is active
- **tmux** preconfigured with the settings Neovim needs (see below) and `Ctrl-a` prefix
- **`tmux-srun`** — one command for a named, persistent Slurm allocation with tmux inside it, rejoinable from any login node, for Claude Code or anything else

## Install

```bash
git clone https://github.com/BhuvaLab/vscode_for_r.git
cd vscode_for_r

bash nvim/install.sh --dry-run     # preview, writes nothing
bash nvim/install.sh               # configs only
```

That installs:

| Path | What |
|---|---|
| `~/.config/nvim/` | the Neovim config (13 Lua files + `CHEATSHEET.md`) |
| `~/.tmux.conf` | a **managed block** — your existing tmux settings are preserved |
| `~/.local/bin/tmux-srun` | the Slurm session launcher |
| `~/.bashrc`, `~/.zshrc` | a managed block putting `~/.local/bin` first on `PATH` |

It then **reports** which command-line tools are missing. To fetch them:

```bash
bash nvim/install.sh --with-tools
```

That downloads Neovim 0.12.5, ripgrep, fd, the tree-sitter CLI, and builds an
isolated venv for basedpyright / ruff / radian — about 450 MB, all under
`~/.local`, no sudo. Re-running any of this is safe: unchanged files are left
alone and the managed blocks are replaced in place, not appended twice.

Finally, open a new shell and start:

```bash
tmux
nvim report.qmd
```

R starts automatically in a tmux pane. `\cc` sends the current chunk.

### R packages

The installer checks for these and prints the install command if any are absent:

```r
install.packages(c("languageserver", "lintr", "styler", "httpgd"))
```

## Keymaps

Leader is `Space`, LocalLeader is `\`, tmux prefix is `Ctrl-a`.
Full reference: [`config/CHEATSHEET.md`](config/CHEATSHEET.md), also installed to
`~/.config/nvim/CHEATSHEET.md`. Inside Neovim, `:RMapsDesc` lists every R binding.

The ones you'll use constantly:

| Key | Action |
|---|---|
| `\rf` | start R |
| `\cc` | send the current chunk |
| `\l` | send the current line |
| `\ss` | send selection (visual mode) |
| `\qp` | Quarto preview |
| `\ro` | toggle the object browser |
| `\rv` | `View()` the data frame under the cursor |
| `Ctrl-h/j/k/l` | move between Neovim splits **and** tmux panes |

## tmux-srun: persistent Slurm sessions

Takes a **session name** (required), which becomes both the tmux session name
and the SLURM job name — that is how the session is found again, so it must be
unique among your jobs.

```bash
tmux-srun analysis                # 72h, 4 cores, 32 GB
tmux-srun bigfit --time 8:00:00 --cpus 8 --mem 64G
tmux-srun proj --dir /scratch/project_mnt/<PROJECT>/work
tmux-srun analysis --attach       # reattach only, never allocate
tmux-srun analysis --end          # cancel the job, free the cores
tmux-srun --status                # what's running (no name needed)
```

`--time`, `--cpus` and `--mem` override the defaults when the allocation is
**created**. A running allocation cannot be resized, so passing them while
reattaching to a live session prints a warning and reattaches unchanged — end
that job first (`tmux-srun <name> --end`) or use a different session name.

The job is submitted with `sbatch` and holds the node with `sleep infinity`.
tmux runs **inside that job, on the compute node**:

```
any login node                 compute node
+-------------------+
| your shell        |  srun --overlap --jobid=N
|                   | ----------->  tmux session
|                   |                 +------------------------+
+-------------------+                 | bash -> claude, R, ... |
                                      +------------------------+
```

**Reattaching works from any login node**, and from any machine: `tmux-srun
<name>` asks the scheduler where the job is and routes a new job step to it.
That is why the ordering is this way round. The earlier design ran tmux on the
login node, which tied the session to whichever node you happened to land on —
and `bunya.rcc.uq.edu.au` round-robins between bunya4 and bunya5, with bunya1–3
also reachable, so roughly half of all logins couldn't see the session.

Detach with `Ctrl-a d`, drop your connection, reconnect later and the job is
still running. Because the allocation is no longer a child of a terminal,
losing the login node no longer takes the job with it.

**The cost:** `sleep infinity` holds the cores for the full walltime whether
you use them or not. Keep the allocation small (the 4 core / 32 GB default is
deliberate) and end it when you're done with `tmux-srun <name> --end`. Real
compute still belongs in its own `sbatch` job.

A queued job is waited on for `TMUX_SRUN_WAIT` seconds (default 600); on
timeout the job stays queued and nothing is cancelled. Other defaults are
overridable per-run with the flags above, or persistently via `TMUX_SRUN_TIME`,
`TMUX_SRUN_CPUS`, `TMUX_SRUN_MEM`, `TMUX_SRUN_WORKDIR` and `TMUX_SRUN_ACCOUNT`
(default `a_frazer`, matching this repo's `vscode.sh` scripts).

## Plots over SSH

There's no `DISPLAY` on a login node, so R plots need a forwarded port. From
your **local** machine:

```bash
ssh -L 8080:localhost:8080 $USER@bunya.rcc.uq.edu.au
```

then in the R console:

```r
httpgd::hgd(port = 8080, host = "localhost")
httpgd::hgd_browse()
```

Open the printed URL locally; plots update live. If you'd rather have plots in a
VS Code panel, use [`cplot/`](../cplot/) with the VS Code workflow instead.

## Python interpreter

The language server follows the conda env active when Neovim launched:

```bash
conda activate myenv
nvim analysis.py        # completions come from myenv
```

`:PythonPath` shows which interpreter was picked; the active env also appears in
the statusline. A project-local `.venv/` takes priority.

## Gotchas this config already works around

These cost real debugging time on Bunya. They're handled, but worth knowing if
you change things:

- **`nvim-treesitter` must be the `main` branch, not `master`.** On Neovim 0.12
  the master branch crashes in its `set-lang-from-info-string!` directive —
  the handler for markdown fenced code blocks — because 0.12 returns query
  captures as a *list* of nodes. That silently kills all `.qmd` chunk LSP and
  breaks highlighting. `config/lua/plugins/treesitter.lua` pins `main`.
- **Install the tree-sitter CLI from its GitHub release, not npm.** The npm
  `tree-sitter-cli` binary needs glibc 2.35/2.39; Bunya (RHEL 9) has 2.34 and
  it fails with a GLIBC version error. `--with-tools` uses the static release.
- **Bunya's system Neovim is 0.8.0**, far too old for this config. The PATH
  block ensures `~/.local/bin/nvim` wins.
- **`r_language_server`'s completion is disabled deliberately.** R.nvim ships
  its own R completion provider (`r_ls`); running both gives duplicate menu
  entries. `lsp.lua` keeps r_language_server for lintr diagnostics and styler
  formatting only.
- **tmux defaults hurt Neovim**: a 500 ms `escape-time` lag leaving insert mode,
  no truecolor, no focus events. The managed block fixes all three.
- **Yanks need OSC 52** to reach your local clipboard — there's no `DISPLAY`, so
  `xsel` can't help. Set in both the tmux block and `options.lua`.

## If something breaks

```vim
:checkhealth            " general diagnosis
:Lazy                   " plugin manager; U updates, S syncs
:LspInfo                " which language servers attached
:RMapsDesc              " every R.nvim keybinding
:PythonPath             " which Python the LSP is using
```

If `.qmd` chunks have no completion, check that treesitter is on `main`
(`:Lazy`) and that the `markdown` parser is installed (`:checkhealth nvim-treesitter`).

To uninstall, delete `~/.config/nvim`, remove the managed blocks from
`~/.tmux.conf` and your shell rc, and delete `~/.local/bin/tmux-srun`.
