# Neovim + R/Quarto + tmux - cheatsheet

Leader = `Space`   LocalLeader = `\`   tmux prefix = `Ctrl-a`

All R.nvim commands use `\` (LocalLeader). Full list inside Neovim: `:RMapsDesc`

---

## Starting up

    tmux                 # or: tmux attach
    nvim report.qmd      # R starts automatically (auto_start = "on startup")

The R console opens in a **tmux pane**, taking 40% of the window width.
Quitting Neovim does NOT kill R. If your SSH connection drops, reconnect and
`tmux attach` - your data frames are still loaded.

---

## R session

| Key    | Action                                  |
|--------|-----------------------------------------|
| `\rf`  | Start R                                 |
| `\rq`  | Quit R                                  |
| `\rw`  | Save workspace and quit R               |
| `\rr`  | Clear console                           |
| `\ro`  | Toggle Object Browser (data frames, envs)|

## Sending code to R

| Key         | Action                                        |
|-------------|-----------------------------------------------|
| `\l`        | Send current line                             |
| `\d`        | Send current line, then move down             |
| `\ss`       | Send selection (visual mode)                  |
| `\pp`       | Send paragraph                                |
| `\cc`       | **Send current chunk** (the one you'll use most in .qmd) |
| `\ch`       | Send all chunks from the top through this one |
| `\aa`       | Send the whole file                           |
| `\fc`       | Send the function under the cursor            |
| `\sc`       | Send a pipe chain (visual)                    |
| `\m}`       | Send from here to end of paragraph (motion)   |

## Quarto

| Key    | Action                                   |
|--------|------------------------------------------|
| `\qp`  | Quarto **preview** (live-reloading)      |
| `\qr`  | Quarto **render**                        |
| `\qs`  | Stop the Quarto preview server           |
| `\kn`  | Knit (Rmd)                               |
| `\gn`  | Jump to next chunk                       |
| `\gN`  | Jump to previous chunk                   |
| `Alt-r`| (insert mode) insert a new ```{r} chunk  |
| `Alt--`| (insert mode) insert ` <- `              |
| `,`    | (insert mode) insert the pipe `\|>`      |

## Inspecting objects

| Key   | Action                                 |
|-------|----------------------------------------|
| `\rh` | Help for the function under the cursor |
| `\rs` | `summary()` of the object              |
| `\rt` | `str()` of the object                  |
| `\rv` | **View the data frame**                |
| `\rg` | `plot()` the object                    |
| `\rn` | `names()` of the object                |
| `\ra` | Show function arguments                |
| `\re` | Show function examples                 |

---

## Editor (Space leader)

| Key          | Action                          |
|--------------|---------------------------------|
| `Space ff`   | Find files                      |
| `Space fg`   | Grep across the project         |
| `Space fb`   | Switch buffer                   |
| `Space fr`   | Recent files                    |
| `Space e`    | Toggle file tree                |
| `K`          | Hover documentation             |
| `gd`         | Go to definition                |
| `gr`         | References                      |
| `Space ca`   | Code action                     |
| `Space cf`   | Format buffer                   |
| `Space rn`   | Rename symbol                   |
| `]d` / `[d`  | Next / previous diagnostic      |
| `]c` / `[c`  | Next / previous git hunk        |
| `Space gp`   | Preview git hunk                |

Press `Space` alone and wait - which-key lists everything available.

## Python REPL (vim-slime -> tmux pane)

| Key         | Action                                    |
|-------------|-------------------------------------------|
| `Space sl`  | Send line (or selection in visual mode)   |
| `Space sp`  | Send paragraph                            |
| `Space sc`  | Choose which tmux pane to send to         |

Start a Python REPL yourself in a tmux pane first (`Ctrl-a |` then `python`),
then send to it. First send asks which pane; accept the default or give a
pane id from `tmux list-panes`.

---

## tmux

| Key            | Action                                     |
|----------------|--------------------------------------------|
| `Ctrl-a \|`     | Split vertically                           |
| `Ctrl-a -`     | Split horizontally                         |
| `Ctrl-h/j/k/l` | Move between panes **and** Neovim splits   |
| `Ctrl-a z`     | Zoom/unzoom the current pane (full screen) |
| `Ctrl-a H/J/K/L`| Resize the pane                           |
| `Ctrl-a d`     | Detach (leaves R running)                  |
| `Ctrl-a [`     | Copy mode (`v` select, `y` yank)           |
| `Ctrl-a r`     | Reload tmux.conf                           |
| `Ctrl-a I`     | Install tmux plugins                       |
| `Ctrl-a Ctrl-s`| Save session (resurrect)                   |
| `Ctrl-a Ctrl-r`| Restore session                            |

`tmux attach` reconnects after a dropped SSH session.

---

## Plots over SSH

R plots need a forwarded port. From your **local** machine:

    ssh -L 8080:localhost:8080 $USER@bunya.rcc.uq.edu.au

Then in the R console:

    httpgd::hgd(port = 8080, host = "localhost")
    httpgd::hgd_browse()

Open the printed URL in your local browser. Plots update live as you draw.

---

## Python interpreter

The language server follows the conda env that was active when you launched
Neovim:

    conda activate myenv
    nvim analysis.py          # completions come from myenv

Check which one it picked with `:PythonPath`. The current env also shows in
the statusline (bottom right). A project `.venv/` takes priority if present.

---

## Maintenance

| Command          | Action                                   |
|------------------|------------------------------------------|
| `:Lazy`          | Plugin manager (`U` updates, `S` syncs)  |
| `:checkhealth`   | Diagnose problems                        |
| `:RMapsDesc`     | Every R.nvim keybinding                  |
| `:PythonPath`    | Which Python the LSP is using            |

Config lives in `~/.config/nvim/`. Shell PATH and tmux backups are in
`~/.local/share/nvim-setup-backups/`.
