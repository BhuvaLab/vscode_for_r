#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
NVIM_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
WITH_TOOLS=0
WITH_HERDR_PLUGINS=0

TMUX_BEGIN="# >>> vscode_for_r managed block >>>"
TMUX_END="# <<< vscode_for_r managed block <<<"
SH_BEGIN="# >>> vscode_for_r managed block >>>"
SH_END="# <<< vscode_for_r managed block <<<"

# Pinned versions for --with-tools.
NVIM_VERSION="0.12.5"
TREE_SITTER_VERSION="0.25.10"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--with-tools] [--with-herdr-plugins] [--dry-run]

Installs the Neovim + tmux setup for R/Quarto:
  ~/.config/nvim/                     Neovim config (lazy.nvim, R.nvim, Quarto, LSP)
  ~/.tmux.conf                        managed block (prefix C-a, Neovim-safe settings)
  ~/.local/bin/tmux-srun              persistent Slurm workbench launcher (tmux)
  ~/.local/bin/herdr-srun             persistent Slurm workbench launcher (herdr)
  ~/.config/herdr/config.toml         herdr config, only if you have none
  ~/.config/herdr-automatic-rename/config.sh
                                      rename plugin config, only if you have none
  ~/.config/herdr/plugins/config/usagebar/config.toml
                                      usagebar plugin config, only if you have none
  ~/.claude/statusline.sh             Claude Code status line, only if you have none
  ~/.bashrc / ~/.zshrc                managed block adding ~/.local/bin to PATH

Options:
  --with-tools   Also download the binary toolchain (Neovim $NVIM_VERSION, ripgrep,
                 fd, tree-sitter CLI, herdr) and build the Python LSP venv. Roughly
                 450 MB. Without this flag the installer only REPORTS what is
                 missing.
  --with-herdr-plugins
                 Also install the herdr plugins listed in nvim/herdr/plugins.txt,
                 each pinned to its reviewed commit. Needs herdr on PATH.
  --dry-run, -n  Preview actions without writing files.
  --help, -h     Show this help text.
EOF
}

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --with-tools) WITH_TOOLS=1 ;;
    --with-herdr-plugins) WITH_HERDR_PLUGINS=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'ERROR: Unknown argument: %s\n' "$arg" >&2; usage >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Shared helpers (same semantics as the repo root install.sh)
# ---------------------------------------------------------------------------
strip_managed_block() {
  local file="$1" begin_marker="$2" end_marker="$3"
  [[ -f "$file" ]] || return 0
  awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker { in_block = 1; next }
    in_block && $0 == end_marker { in_block = 0; next }
    !in_block { lines[++n] = $0 }
    END {
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) { n-- }
      for (i = 1; i <= n; i++) { print lines[i] }
    }
  ' "$file"
}

write_file_if_changed() {
  local target="$1" staged_file="$2" existed=0
  if [[ -f "$target" ]]; then
    existed=1
    if cmp -s "$target" "$staged_file"; then
      log "unchanged: $target"
      return 0
    fi
  fi
  if (( DRY_RUN )); then
    (( existed )) && log "[dry-run] update: $target" || log "[dry-run] create: $target"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  cat "$staged_file" > "$target"
  (( existed )) && log "updated: $target" || log "created: $target"
}

install_managed_block() {
  local target="$1" template="$2" begin_marker="$3" end_marker="$4"
  local tmp_base tmp_out
  [[ -f "$template" ]] || die "Missing template: $template"
  tmp_base="$(mktemp)"; tmp_out="$(mktemp)"
  strip_managed_block "$target" "$begin_marker" "$end_marker" > "$tmp_base"
  {
    if [[ -s "$tmp_base" ]]; then cat "$tmp_base"; printf '\n'; fi
    printf '%s\n' "$begin_marker"
    cat "$template"
    printf '%s\n' "$end_marker"
  } > "$tmp_out"
  write_file_if_changed "$target" "$tmp_out"
  rm -f "$tmp_base" "$tmp_out"
}

install_file() {
  local src="$1" dst="$2" exe="${3:-0}"
  [[ -f "$src" ]] || die "Missing source file: $src"
  # Compare before writing so re-running reports "unchanged" rather than
  # rewriting every file - same semantics as the repo root install.sh.
  write_file_if_changed "$dst" "$src"
  if (( exe )) && (( ! DRY_RUN )); then chmod +x "$dst"; fi
}

# ---------------------------------------------------------------------------
# 1. Neovim config
# ---------------------------------------------------------------------------
log "== Neovim config =="
CONFIG_DST="$HOME/.config/nvim"
while IFS= read -r rel; do
  install_file "$NVIM_ROOT/config/$rel" "$CONFIG_DST/$rel"
done < <(cd "$NVIM_ROOT/config" && find . -type f | sed 's|^\./||' | sort)

# ---------------------------------------------------------------------------
# 2. tmux managed block
# ---------------------------------------------------------------------------
log ""
log "== tmux =="
if [[ -f "$HOME/.tmux.conf" ]] && ! grep -Fq "$TMUX_BEGIN" "$HOME/.tmux.conf" \
   && grep -Eq '^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+prefix' "$HOME/.tmux.conf"; then
  warn "Your ~/.tmux.conf already sets a prefix key."
  warn "The managed block rebinds it to C-a and will take precedence."
  warn "Edit the block out afterwards if you want to keep your own prefix."
fi
install_managed_block "$HOME/.tmux.conf" "$NVIM_ROOT/tmux/tmux.conf.block" "$TMUX_BEGIN" "$TMUX_END"

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  if (( DRY_RUN )); then
    log "[dry-run] clone tpm into ~/.tmux/plugins/tpm"
  elif command -v git >/dev/null; then
    git clone -q --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
      && log "installed: ~/.tmux/plugins/tpm" || warn "tpm clone failed (tmux still works; plugins will not load)"
  else
    warn "git not found - skipping tpm. Install it for session save/restore."
  fi
else
  log "unchanged: ~/.tmux/plugins/tpm"
fi

# ---------------------------------------------------------------------------
# 3. Slurm workbench launchers
# ---------------------------------------------------------------------------
log ""
log "== Slurm launchers =="
install_file "$NVIM_ROOT/bin/tmux-srun" "$HOME/.local/bin/tmux-srun" 1
install_file "$NVIM_ROOT/bin/herdr-srun" "$HOME/.local/bin/herdr-srun" 1

# herdr configs: a starting point only. Unlike the managed blocks there is no
# marker syntax to merge into, so an existing config is left untouched.
install_if_absent() {
  local rel="$1" dst="$2" exe="${3:-0}"
  if [[ -f "$dst" ]]; then
    cmp -s "$dst" "$NVIM_ROOT/$rel" \
      && log "unchanged: $dst" \
      || log "kept existing: $dst (template: nvim/$rel)"
  else
    install_file "$NVIM_ROOT/$rel" "$dst" "$exe"
  fi
}
install_if_absent herdr/config.toml "$HOME/.config/herdr/config.toml"
# Read by the herdr-automatic-rename plugin (--with-herdr-plugins); harmless without it.
install_if_absent herdr/automatic-rename.config.sh "$HOME/.config/herdr-automatic-rename/config.sh"
# usagebar (--with-herdr-plugins): show plan limits as % used, not % remaining.
install_if_absent herdr/usagebar.config.toml "$HOME/.config/herdr/plugins/config/usagebar/config.toml"

# Claude session restore needs herdr's Claude integration. It edits
# ~/.claude/settings.json, so it is suggested rather than done here.
if command -v herdr >/dev/null && command -v claude >/dev/null \
   && ! grep -q herdr-agent-state "$HOME/.claude/settings.json" 2>/dev/null; then
  log "-> for Claude session restore in herdr-srun, run once:  herdr integration install claude"
fi

# Claude Code status line (dir > branch, right-justified context bar, model,
# effort). Turning it on edits ~/.claude/settings.json, so that is suggested.
install_if_absent claude/statusline.sh "$HOME/.claude/statusline.sh" 1
if ! grep -q '"statusLine"' "$HOME/.claude/settings.json" 2>/dev/null; then
  log '-> to use the Claude status line, add to ~/.claude/settings.json:'
  log '     "statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 2}'
fi

# Migration: this launcher used to be called tmux-claude. Remove the old copy
# so an upgraded install does not leave two diverging scripts on PATH.
if [[ -f "$HOME/.local/bin/tmux-claude" ]]; then
  if (( DRY_RUN )); then
    log "[dry-run] remove superseded: $HOME/.local/bin/tmux-claude"
  else
    rm -f "$HOME/.local/bin/tmux-claude"
    log "removed superseded: $HOME/.local/bin/tmux-claude (renamed to tmux-srun)"
  fi
fi

# herdr plugins: third-party code that runs unsandboxed as you, so never
# installed without asking. Each is pinned to the commit that was reviewed;
# a plugin already installed at another ref is reported, not replaced.
HERDR_PLUGINS="$NVIM_ROOT/herdr/plugins.txt"
if (( WITH_HERDR_PLUGINS )); then
  command -v herdr >/dev/null || die "--with-herdr-plugins needs herdr (install with --with-tools)"
  INSTALLED="$(herdr plugin list 2>/dev/null || true)"
  while read -r id repo ref digest; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    if grep -Fq "[github:$repo@$ref]" <<<"$INSTALLED"; then
      log "unchanged: herdr plugin $id"
      continue
    elif grep -Eq "^- $id " <<<"$INSTALLED"; then
      warn "herdr plugin $id is installed at a different ref; leaving it (pinned: $ref)"
      continue
    fi
    if (( DRY_RUN )); then
      log "[dry-run] herdr plugin install $repo --ref $ref"
      continue
    fi
    herdr plugin install "$repo" --ref "$ref" --yes >/dev/null \
      || { warn "herdr plugin $id failed to install"; continue; }
    # A plugin whose own installer does not verify its download: check the
    # built binary against the digest recorded at review time.
    if [[ -n "${digest:-}" ]]; then
      if find "$HOME"/.config/herdr/plugins/github/"$id"-*/ -type f -size +1M -exec sha256sum {} + 2>/dev/null \
         | grep -q "^$digest "; then
        log "installed: herdr plugin $id (binary digest verified)"
      else
        herdr plugin uninstall "$id" >/dev/null 2>&1 || true
        warn "herdr plugin $id: binary does not match the reviewed digest - uninstalled"
      fi
    else
      log "installed: herdr plugin $id"
    fi
  done < "$HERDR_PLUGINS"
  # reviewr's build links ~/.local/bin/herdr-reviewr into the temporary
  # checkout, which herdr then moves: re-point a dangling link.
  if (( ! DRY_RUN )) && [[ -L "$HOME/.local/bin/herdr-reviewr" && ! -e "$HOME/.local/bin/herdr-reviewr" ]]; then
    ln -sfn "$(ls -d "$HOME"/.config/herdr/plugins/github/persiyanov.reviewr-*/bin/herdr-reviewr | head -1)" \
      "$HOME/.local/bin/herdr-reviewr" && log "repaired: $HOME/.local/bin/herdr-reviewr link"
  fi
elif command -v herdr >/dev/null; then
  log "-> reviewed herdr plugins (nvim/herdr/plugins.txt):  bash $SCRIPT_NAME --with-herdr-plugins"
fi

# ---------------------------------------------------------------------------
# 4. PATH block in whichever shells the user actually has
# ---------------------------------------------------------------------------
log ""
log "== shell PATH =="
PATH_BLOCK="$(mktemp)"
cat > "$PATH_BLOCK" <<'BLOCK'
# User-local binaries: Neovim, ripgrep, fd, ruff, basedpyright, radian,
# tmux-srun. Placed after any conda init so ~/.local/bin wins over an older
# system nvim (Bunya ships 0.8.0, too old for this config).
#
# Any existing occurrence is removed first, then it is prepended. That keeps
# it FIRST (a stock Bunya .bashrc already adds it, but conda init then puts
# miniconda ahead of it), and stops PATH growing each time this file is
# re-sourced.
PATH=":$PATH:"
PATH="${PATH//:$HOME\/.local\/bin:/:}"
PATH="${PATH#:}"
PATH="${PATH%:}"
export PATH="$HOME/.local/bin:$PATH"
BLOCK
RC_FOUND=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ -f "$rc" ]]; then
    RC_FOUND=1
    install_managed_block "$rc" "$PATH_BLOCK" "$SH_BEGIN" "$SH_END"
  else
    log "absent, skipped: $rc"
  fi
done
# With no shell rc at all, nothing would put ~/.local/bin on PATH and the whole
# install would be inert. Create ~/.bashrc rather than leave it broken.
if (( ! RC_FOUND )); then
  warn "No ~/.bashrc or ~/.zshrc found; creating ~/.bashrc so ~/.local/bin is on PATH."
  install_managed_block "$HOME/.bashrc" "$PATH_BLOCK" "$SH_BEGIN" "$SH_END"
fi
rm -f "$PATH_BLOCK"

# ---------------------------------------------------------------------------
# 5. Toolchain: report, or install with --with-tools
# ---------------------------------------------------------------------------
log ""
log "== toolchain =="

nvim_ok() {
  command -v nvim >/dev/null || return 1
  local v; v="$(nvim --version | head -1 | sed -E 's/^NVIM v//')"
  local maj min; maj="${v%%.*}"; min="$(printf '%s' "$v" | cut -d. -f2)"
  (( maj > 0 || min >= 10 ))
}

MISSING=()
nvim_ok || MISSING+=("neovim>=0.10 (found: $(command -v nvim >/dev/null && nvim --version | head -1 || echo none))")
command -v rg           >/dev/null || MISSING+=("ripgrep")
command -v fd           >/dev/null || MISSING+=("fd")
command -v tree-sitter  >/dev/null || MISSING+=("tree-sitter-cli")
command -v basedpyright >/dev/null || MISSING+=("basedpyright")
command -v ruff         >/dev/null || MISSING+=("ruff")
command -v radian       >/dev/null || MISSING+=("radian")
command -v tmux         >/dev/null || MISSING+=("tmux (ask your sysadmin; on Bunya it is preinstalled)")
command -v herdr        >/dev/null || MISSING+=("herdr (for herdr-srun)")

if (( ! WITH_TOOLS )); then
  if (( ${#MISSING[@]} )); then
    log "Missing tools:"
    for m in "${MISSING[@]}"; do log "  - $m"; done
    log ""
    log "-> run: bash $SCRIPT_NAME --with-tools"
  else
    log "All tools present."
  fi
else
  BIN="$HOME/.local/bin"
  SRC="$HOME/.local/src"
  if (( DRY_RUN )); then
    log "[dry-run] would download Neovim $NVIM_VERSION, ripgrep, fd, tree-sitter $TREE_SITTER_VERSION, herdr"
    log "[dry-run] would create the Python LSP venv at ~/.local/share/nvim-tools"
  else
    mkdir -p "$BIN" "$SRC"

    if ! nvim_ok; then
      log "downloading Neovim $NVIM_VERSION..."
      curl -fsSL --retry 3 -o "$SRC/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
      tar xzf "$SRC/nvim.tar.gz" -C "$SRC"
      rm -rf "$HOME/.local/nvim"
      mv "$SRC/nvim-linux-x86_64" "$HOME/.local/nvim"
      ln -sf "$HOME/.local/nvim/bin/nvim" "$BIN/nvim"
      rm -f "$SRC/nvim.tar.gz"
      log "installed: $BIN/nvim ($("$BIN/nvim" --version | head -1))"
    fi

    if ! command -v rg >/dev/null; then
      log "downloading ripgrep..."
      RG_TAG="$(curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
      curl -fsSL --retry 3 -o "$SRC/rg.tar.gz" \
        "https://github.com/BurntSushi/ripgrep/releases/download/${RG_TAG}/ripgrep-${RG_TAG}-x86_64-unknown-linux-musl.tar.gz"
      tar xzf "$SRC/rg.tar.gz" -C "$SRC"
      cp "$SRC/ripgrep-${RG_TAG}-x86_64-unknown-linux-musl/rg" "$BIN/rg"
      chmod +x "$BIN/rg"; rm -rf "$SRC/rg.tar.gz" "$SRC/ripgrep-${RG_TAG}"*
      log "installed: $BIN/rg"
    fi

    if ! command -v fd >/dev/null; then
      log "downloading fd..."
      FD_TAG="$(curl -fsSL https://api.github.com/repos/sharkdp/fd/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
      curl -fsSL --retry 3 -o "$SRC/fd.tar.gz" \
        "https://github.com/sharkdp/fd/releases/download/v${FD_TAG}/fd-v${FD_TAG}-x86_64-unknown-linux-musl.tar.gz"
      tar xzf "$SRC/fd.tar.gz" -C "$SRC"
      cp "$SRC/fd-v${FD_TAG}-x86_64-unknown-linux-musl/fd" "$BIN/fd"
      chmod +x "$BIN/fd"; rm -rf "$SRC/fd.tar.gz" "$SRC/fd-v${FD_TAG}"*
      log "installed: $BIN/fd"
    fi

    # NOTE: deliberately the GitHub release, NOT `npm i -g tree-sitter-cli`.
    # The npm build links against glibc 2.35/2.39; Bunya (RHEL 9) has 2.34,
    # so the npm binary fails with a GLIBC version error. This one is static.
    if ! command -v tree-sitter >/dev/null; then
      log "downloading tree-sitter CLI $TREE_SITTER_VERSION..."
      curl -fsSL --retry 3 -o "$SRC/ts.gz" \
        "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/tree-sitter-linux-x64.gz"
      gunzip -f "$SRC/ts.gz"
      mv "$SRC/ts" "$BIN/tree-sitter"; chmod +x "$BIN/tree-sitter"
      log "installed: $BIN/tree-sitter"
    fi

    # herdr ships a static binary, so the glibc 2.34 caveat above does not
    # apply. Its own installer picks the platform build and puts it in $BIN.
    if ! command -v herdr >/dev/null; then
      log "installing herdr..."
      curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR="$BIN" sh >/dev/null \
        && log "installed: $BIN/herdr ($("$BIN/herdr" --version))" \
        || warn "herdr install failed (only herdr-srun needs it)"
    fi

    # Python LSP tools in their own venv so they never pollute an analysis env.
    if ! command -v basedpyright >/dev/null || ! command -v ruff >/dev/null || ! command -v radian >/dev/null; then
      log "building Python tool venv (basedpyright, ruff, radian)..."
      PYBIN="$(command -v python3)" || die "python3 not found"
      "$PYBIN" -m venv "$HOME/.local/share/nvim-tools"
      "$HOME/.local/share/nvim-tools/bin/pip" install --quiet --upgrade pip
      "$HOME/.local/share/nvim-tools/bin/pip" install --quiet basedpyright ruff radian
      for t in basedpyright basedpyright-langserver ruff radian; do
        [[ -x "$HOME/.local/share/nvim-tools/bin/$t" ]] && ln -sf "$HOME/.local/share/nvim-tools/bin/$t" "$BIN/$t"
      done
      log "installed: basedpyright, ruff, radian -> $BIN"
    fi

    if command -v npm >/dev/null && ! command -v yaml-language-server >/dev/null; then
      log "installing yaml-language-server (Quarto frontmatter completion)..."
      npm config set prefix "$HOME/.local" >/dev/null 2>&1 || true
      npm install -g --silent yaml-language-server >/dev/null 2>&1 \
        && log "installed: $BIN/yaml-language-server" || warn "yaml-language-server install failed (optional)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 6. R packages
# ---------------------------------------------------------------------------
log ""
log "== R packages =="
if command -v Rscript >/dev/null; then
  MISSING_R="$(Rscript -e 'p <- c("languageserver","lintr","styler","httpgd"); cat(paste(setdiff(p, rownames(installed.packages())), collapse=" "))' 2>/dev/null || true)"
  if [[ -n "$MISSING_R" ]]; then
    log "Missing R packages: $MISSING_R"
    log "-> install with:  Rscript -e 'install.packages(c($(printf '"%s",' $MISSING_R | sed 's/,$//')))'"
  else
    log "All R packages present (languageserver, lintr, styler, httpgd)."
  fi
else
  warn "Rscript not found - activate your R environment, then re-run to check R packages."
fi

log ""
if (( DRY_RUN )); then
  log "(dry run - nothing was written)"
else
  log "Done. Open a new shell, then:  tmux  ->  nvim report.qmd"
  log "Keymaps: ~/.config/nvim/CHEATSHEET.md"
fi
