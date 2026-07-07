# VS Code for R (local + UQ Bunya)

This guide focuses on local VS Code + R setup, plus UQ Bunya launch workflows for VS Code tunnel sessions.

It includes a compatibility fix for R >= 4.6 where some sessions fail to expose `.vsc.attach()`.

## Quick install (mode based)

This repository now includes an installer that can apply either HPC or local profiles.

```bash
bash install.sh hpc --dry-run
bash install.sh hpc

# Later, switch to local profile mode
bash install.sh local
```

Mode behavior:
- `hpc`: installs/updates managed blocks in `~/.bashrc`, `~/.bash_aliases`, `~/.vimrc`, and `~/.Rprofile`; installs managed `~/vscode.sh`, `~/vscode_big.sh`, and `~/vscode_gpu.sh`.
- `local`: installs/updates managed blocks in the same dotfiles using local templates; removes only installer-managed HPC launcher scripts.

Safety behavior:
- Dotfiles are merged using managed block markers, so unmanaged user content is preserved.
- If an existing launcher script is unmanaged, installer writes `*.vscode_for_r.new` instead of overwriting.
- `--dry-run` previews actions without writing files.

## 1) Install VS Code extensions

Install these extensions in VS Code:
- R (REditorSupport.r)
- R Debugger (RDebugger.r-debugger)
- Quarto
- Remote - SSH
- Remote - SSH: Editing Configuration Files

Optional:
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

Then set your VS Code R terminal path (`r.rterm.mac` / `r.rterm.linux` / `r.rterm.windows`) to the radian executable.

## 4) Configure ~/.Rprofile for VS Code (R >= 4.6 safe)

Add this to `~/.Rprofile`:

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

## 5) UQ Bunya: start VS Code sessions with Slurm

When you run `bash install.sh hpc`, these scripts are installed to your home directory.

You can also copy them manually if preferred.

### ~/vscode.sh

```bash
#!/bin/bash --login
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=256G
#SBATCH --job-name=vscc
#SBATCH --time=12:00:00
#SBATCH --qos=normal
#SBATCH --partition=general
#SBATCH --account=a_frazer
#SBATCH -o vscc-%j.output
#SBATCH -e vscc-%j.error
#SBATCH --exclude=bun013

# Parameters to chanage
# --cpus-per-task: logical CPUS/threads -> Requests more phyiscal cores as needed
# --mem: 8 / 16 / 32 / 64 / 128 / 256 / 512 / 1000G subdivs are nice
# --job-name: if u want
# --time: 2:00:00 is 2h, 0:30:00 is 30mins
# --account: Change if ur dharmesh and have ur own sacct

srun --export=PATH,TERM,HOME,LANG --pty /bin/bash -l -c "module load vscode/1.87.0 && code tunnel"
```

### ~/vscode_big.sh

```bash
#!/bin/bash --login
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=512G
#SBATCH --job-name=vscc
#SBATCH --time=24:00:00
#SBATCH --qos=normal
#SBATCH --partition=general
#SBATCH --account=a_frazer
#SBATCH -o vscc-%j.output
#SBATCH -e vscc-%j.error

# Parameters to chanage
# --cpus-per-task: logical CPUS/threads -> Requests more phyiscal cores as needed
# --mem: 8 / 16 / 32 / 64 / 128 / 256 / 512 / 1000G subdivs are nice
# --job-name: if u want
# --time: 2:00:00 is 2h, 0:30:00 is 30mins
# --account: Change if ur dharmesh and have ur own sacct

srun --export=PATH,TERM,HOME,LANG --pty /bin/bash -l -c "module load vscode/1.87.0 && code tunnel"
```

### ~/vscode_gpu.sh

```bash
#!/bin/bash --login
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=512G
#SBATCH --job-name=vscc
#SBATCH --time=24:00:00
#SBATCH --qos=normal
#SBATCH --partition=general
#SBATCH --account=a_frazer
#SBATCH -o vscc-%j.output
#SBATCH -e vscc-%j.error

# Parameters to chanage
# --cpus-per-task: logical CPUS/threads -> Requests more phyiscal cores as needed
# --mem: 8 / 16 / 32 / 64 / 128 / 256 / 512 / 1000G subdivs are nice
# --job-name: if u want
# --time: 2:00:00 is 2h, 0:30:00 is 30mins
# --account: Change if ur dharmesh and have ur own sacct

srun --export=PATH,TERM,HOME,LANG --pty /bin/bash -l -c "module load vscode/1.87.0 && code tunnel"
```

### Submit jobs manually

```bash
sbatch ~/vscode.sh
sbatch ~/vscode_big.sh
sbatch ~/vscode_gpu.sh
```

After submission, use `squeue -u $USER` to monitor jobs and `tail -f vscc-<jobid>.output` for tunnel output.

## 6) Shell and editor templates

### ~/.bashrc (HPC)

```bash
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# R / VS Code environment
export TERM_PROGRAM=vscode

# User aliases and functions
if [ -e ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi
```

### ~/.bash_aliases (HPC)

```bash
# Queue helper
alias q="squeue -u $USER"

# Common ls aliases
alias ll="ls -lhrt"
alias la='ls -Al'
alias lx='ls -lXB'
alias lk='ls -lSr'
alias lc='ls -ltcr'
alias lu='ls -ltur'
alias lt='ls -ltr'
alias lm='ls -al | less'
alias lr='ls -lR | less'
alias tree='tree -Csu | less'

# VS Code Slurm launcher
# Usage:
#   vscode        -> submits ~/vscode.sh
#   vscode big    -> submits ~/vscode_big.sh
#   vscode gpu    -> submits ~/vscode_gpu.sh
vscode() {
  case "${1:-}" in
    "")
      sbatch "$HOME/vscode.sh"
      ;;
    big)
      sbatch "$HOME/vscode_big.sh"
      ;;
    gpu)
      sbatch "$HOME/vscode_gpu.sh"
      ;;
    *)
      echo "Usage: vscode [big|gpu]"
      return 1
      ;;
  esac
}
```

### ~/.bash_aliases (laptop)

```bash
alias ..="cd .."
alias ~="cd ~"

# Replace with your Bunya login host
alias bunya="ssh $USER@bunya.hpc.uq.edu.au"

# Common ls aliases
alias ll="ls -l"
alias la='ls -Al'
alias lx='ls -lXB'
alias lk='ls -lSr'
alias lc='ls -ltcr'
alias lu='ls -ltur'
alias lt='ls -ltr'
alias lm='ls -al | less'
alias lr='ls -lR | less'
alias tree='tree -Csu | less'
```

### ~/.vimrc (HPC and laptop)

```vim
"set how many lines of history to remember
set history=700

"------------------VIM Interface------------------
set ruler "always show current position
set cmdheight=2 "commandbar height

"set backspace config
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

set ignorecase "ignore case when searching
set smartcase " if there are caps, go case-sensitive

set hlsearch "highlight search things
set magic "set magic on, for regexps
set showmatch "show matching braces

"no sound on errors
set noerrorbells
set novisualbell

set cursorline "highlight current line
set incsearch " BUT do highlight as you type your search phrase
set lazyredraw "do not redraw while running macros

set number "turn on line numbers
set numberwidth=5 " we are good upto 5 digit numbers ie 99999

"-----------------Color and fonts-----------------
syntax enable "enable syntax hl

"---------------text, tab and indent--------------
set expandtab "no real tabs
set shiftwidth=4 " auto-indent amount when using cindent,>>, << and stuff like that
set tabstop=4 "set the spaces for tab
set smarttab

set ai "set auto indentation
set si "smart indent
set wrap "wrap lines

"------------------spell checking-----------------
"pressing ,ss will toggle and untoggle spell checking
map <leader>ss :setlocal spell!<cr>

"shortcuts using <leader>
map <leader>sn ]s
map <leader>sp [s
map <leader>sa zg
map <leader>s? z=

"-----------------------Misc----------------------
"set status line
set statusline=%F%m%r%h%w[%L][%{&ff}]%y[%p%%][%04l,%04v]
```

## 7) Troubleshooting

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
