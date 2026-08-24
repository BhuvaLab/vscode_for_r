#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--dry-run]

Installs:
  ~/.local/bin/cplot                              the CLI
  ~/.local/share/cplot/{gallery.html,shim.R,boot.py}   R/Python plotting shims
  ~/.claude/skills/transient-plots/SKILL.md       Claude Code skill (only if ~/.claude exists)

Options:
  --dry-run, -n  Preview actions without writing files.
  --help, -h     Show this help text.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

install_file() {
  local src="$1" dst="$2" exe="${3:-0}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would install: $dst"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  if [[ "$exe" -eq 1 ]]; then chmod +x "$dst"; fi
  echo "installed: $dst"
}

install_file "$REPO_ROOT/bin/cplot" "$HOME/.local/bin/cplot" 1
install_file "$REPO_ROOT/share/gallery.html" "$HOME/.local/share/cplot/gallery.html"
install_file "$REPO_ROOT/share/shim.R" "$HOME/.local/share/cplot/shim.R"
install_file "$REPO_ROOT/share/boot.py" "$HOME/.local/share/cplot/boot.py"

if [[ -d "$HOME/.claude" ]]; then
  install_file "$REPO_ROOT/skills/transient-plots/SKILL.md" "$HOME/.claude/skills/transient-plots/SKILL.md"
else
  echo "note: ~/.claude not found, skipping Claude Code skill (not detected on this machine)"
fi

echo
if [[ "$DRY_RUN" -eq 0 ]]; then
  echo "Done. Make sure ~/.local/bin is on PATH, then try: cplot status"
else
  echo "(dry run - nothing was written)"
fi
