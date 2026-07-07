# VS Code for R (local + HPC)

This guide is a cleaned and updated VS Code R setup, adapted from:
- https://github.com/DavisLaboratory/SAiGENCI_hpc

It includes an additional compatibility fix for R >= 4.6 where some users may see:

```r
Error in .vsc.attach() : could not find function ".vsc.attach"
```

## 1) Install VS Code extensions

Install these extensions in VS Code:
- R (REditorSupport.r)
- R Debugger (RDebugger.r-debugger)
- Quarto
- Remote - SSH
- Remote - SSH: Editing Configuration Files

Optional quality-of-life:
- Rainbow CSV
- Path Autocomplete

## 2) Install R packages used by VS Code R tooling

From an R session:

```r
install.packages(c("languageserver", "httpgd", "rstudioapi", "jsonlite", "rlang"))
```

For debugging support:

```r
install.packages("vscDebugger", repos = c("https://manuelhentschel.r-universe.dev", "https://cloud.r-project.org"))
```

## 3) Optional: install radian

If you want a richer R terminal:

```bash
pip install --user radian
```

In VS Code settings, point `r.rterm.mac` / `r.rterm.linux` / `r.rterm.windows` to your radian executable.

## 4) Configure ~/.Rprofile for VS Code

Add this to your `~/.Rprofile`:

```r
if (interactive() && Sys.getenv("RSTUDIO") == "") {
  Sys.setenv(TERM_PROGRAM = "vscode")
  source(file.path(Sys.getenv(
    if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"
  ), ".vscode-R", "init.R"))

  # R >= 4.6 workaround: in some environments the VS Code hook is assigned
  # but not executed, which leaves .vsc.attach unavailable.
  if (
    !exists(".vsc.attach", mode = "function") &&
      exists(".First.sys", envir = globalenv(), inherits = FALSE)
  ) {
    try(get(".First.sys", envir = globalenv())(), silent = TRUE)
  }
}

options(vsc.rstudioapi = TRUE)

options(languageserver.formatting_style = function(options) {
  style <- styler::tidyverse_style(indent_by = options$tabSize)
  style$token$force_assignment_op <- NULL
  style
})
```

## 5) HPC-focused notes

### Install packages on login nodes

Install R packages on login nodes, not compute nodes.

Example:

```bash
module use /apps/icl/modules/all
module load R
R --no-save
```

### Request an interactive allocation, then start R

```bash
salloc --partition saigenci_highmem --mem 128G --cpus-per-task 1 --time 24:00:00
# or
salloc --partition saigenci_normal --mem 24G --cpus-per-task 4 --time 24:00:00

ssh <allocated-node>
module use /apps/icl/modules/all
module load R
R --no-save   # or radian
```

### Helpful shell variables on HPC

In `~/.bashrc` (or shell equivalent):

```bash
export R_LIBS_USER='/hpcfs/users/$USER/local/RLibs'
export TERM_PROGRAM=vscode
```

## 6) Troubleshooting

### Symptom: `.vsc.attach()` not found

Run in the active R terminal:

```r
file.exists(file.path(Sys.getenv(if (.Platform$OS.type == "windows") "USERPROFILE" else "HOME"), ".vscode-R", "init.R"))
exists(".vsc.attach", mode = "function")
```

If `.vsc.attach` is `FALSE`:
- Confirm `~/.Rprofile` is loaded in your interactive shell/session.
- Ensure `TERM_PROGRAM` is `vscode` for sessions started from VS Code.
- Restart the R session after editing `~/.Rprofile`.
- If using radian from conda, verify VS Code points to the expected executable.

### Quick validation check

In a fresh VS Code R terminal:

```r
exists(".vsc.attach", mode = "function")
any(search() == "tools:vscode")
```

Both should return `TRUE`.

## References

- VS Code R quickstart: https://code.visualstudio.com/docs/languages/r
- VS Code R extension wiki: https://github.com/REditorSupport/vscode-R/wiki
- Source material: https://github.com/DavisLaboratory/SAiGENCI_hpc
