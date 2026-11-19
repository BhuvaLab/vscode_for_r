#!/usr/bin/env bash
# Rich agents sidebar + Claude Code status line for the Herdr DESKTOP app
# (herdr-app + herdr-core `hc`, e.g. on Windows). The herdr TUI setup in
# nvim/herdr/config.toml does not apply there: the app has no TOML sidebar
# rows and no `herdr pane report-metadata`. Instead:
#   ~/.claude/statusline.sh  publishes model/effort/context/cost as `hc label`s
#   mods/agents-rich         the shipped agents mod plus a detail line from them
#   layouts/vscode-for-r     a clone of the shipped `main` layout using that mod
#
# Run from Git Bash (Windows) or a shell (macOS) while the Herdr app is open:
#   bash nvim/herdr-app/install.sh [--dry-run]
# Re-running is safe: files are replaced, settings.json is merged with jq
# (backup kept), and an existing layout clone is only re-pointed.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_NVIM="$(dirname -- "$HERE")"
APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
LAYOUT="vscode-for-r"
DRY=0
[[ ${1:-} == --dry-run || ${1:-} == -n ]] && DRY=1

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
do_() { if (( DRY )); then log "[dry-run] $*"; else "$@"; fi; }

command -v jq >/dev/null || die "needs jq (Windows: winget install jqlang.jq, then put jq.exe on PATH, e.g. ~/.local/bin)"
command -v herdr-app >/dev/null || die "herdr-app not on PATH"
[[ -d $APP_HOME ]] || die "no Herdr app home at $APP_HOME (start the app once)"

# 1. Status line script
do_ mkdir -p "$HOME/.claude"
if [[ -f $HOME/.claude/statusline.sh ]] && ! cmp -s "$HOME/.claude/statusline.sh" "$REPO_NVIM/claude/statusline.sh"; then
  do_ cp -p "$HOME/.claude/statusline.sh" "$HOME/.claude/statusline.sh.bak"
fi
do_ cp "$REPO_NVIM/claude/statusline.sh" "$HOME/.claude/statusline.sh"
log "installed: ~/.claude/statusline.sh"

# 2. statusLine in settings.json. `bash` explicitly: on Windows the command may
#    not run through a shell that honours the shebang.
settings="$HOME/.claude/settings.json"
want='{"type":"command","command":"bash ~/.claude/statusline.sh","padding":2}'
if [[ -f $settings ]] && jq -e --argjson w "$want" '.statusLine == $w' "$settings" >/dev/null; then
  log "unchanged: statusLine in $settings"
elif (( DRY )); then
  log "[dry-run] set statusLine in $settings"
else
  [[ -f $settings ]] || echo '{}' >"$settings"
  cp -p "$settings" "$settings.bak"
  tmp="$(mktemp)"
  jq --argjson w "$want" '.statusLine = $w' "$settings.bak" >"$tmp" && cat "$tmp" >"$settings"
  rm -f "$tmp"
  log "updated: statusLine in $settings (backup: $settings.bak)"
fi

# 3. The mod. Written straight into mods/ (a clone of the shipped `agents`);
#    the app hot-reloads it.
do_ mkdir -p "$APP_HOME/mods/agents-rich"
do_ cp "$HERE/mods/agents-rich/main.js" "$HERE/mods/agents-rich/mod.json" "$APP_HOME/mods/agents-rich/"
(( DRY )) || herdr-app check "$APP_HOME/mods/agents-rich"

# 4. The layout: clone the shipped `main` (so it tracks this app version) and
#    point its agents block at agents-rich. layout.clone also switches to it.
lfile="$APP_HOME/layouts/$LAYOUT.json"
if [[ ! -f $lfile ]]; then
  do_ herdr-app do layout.clone "{\"name\":\"main\",\"as\":\"$LAYOUT\"}" >/dev/null
fi
if (( DRY )); then
  log "[dry-run] point $lfile's agents block at agents-rich"
else
  tmp="$(mktemp)"
  jq '(.. | objects | select(.id? == "agents") | .content.mod) = "agents-rich"' "$lfile" >"$tmp" && cat "$tmp" >"$lfile"
  rm -f "$tmp"
  herdr-app do layout.switch "{\"name\":\"$LAYOUT\"}" >/dev/null
  log "layout: $LAYOUT (agents-rich sidebar) is now shown"
fi

log "Done. Claude sessions show the status line on their next refresh; the"
log "sidebar fills in per agent once its status line has run."
