#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_ROOT="$REPO_ROOT/templates"

DRY_RUN=0
MODE=""

BASH_BEGIN="# >>> vscode_for_r managed block >>>"
BASH_END="# <<< vscode_for_r managed block <<<"
VIM_BEGIN="\" >>> vscode_for_r managed block >>>"
VIM_END="\" <<< vscode_for_r managed block <<<"
SCRIPT_MARKER="# vscode_for_r managed file"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <hpc|local> [--dry-run]

Arguments:
  hpc            Install HPC-oriented managed blocks and Bunya launcher scripts.
  local          Install local-oriented managed blocks and remove managed HPC scripts.

Options:
  --dry-run, -n  Preview actions without writing files.
  --help, -h     Show this help text.
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  local arg

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  for arg in "$@"; do
    case "$arg" in
      hpc|local)
        if [[ -n "$MODE" && "$MODE" != "$arg" ]]; then
          die "Mode specified more than once ($MODE, $arg)."
        fi
        MODE="$arg"
        ;;
      --dry-run|-n)
        DRY_RUN=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $arg"
        ;;
    esac
  done

  if [[ -z "$MODE" ]]; then
    die "Mode is required: hpc or local"
  fi

  if [[ ! -d "$TEMPLATES_ROOT/$MODE" ]]; then
    die "Missing templates for mode '$MODE' at $TEMPLATES_ROOT/$MODE"
  fi
}

strip_managed_block() {
  local file="$1"
  local begin_marker="$2"
  local end_marker="$3"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  awk -v begin_marker="$begin_marker" -v end_marker="$end_marker" '
    $0 == begin_marker {
      in_block = 1
      next
    }
    in_block && $0 == end_marker {
      in_block = 0
      next
    }
    !in_block {
      lines[++n] = $0
    }
    END {
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) {
        n--
      }
      for (i = 1; i <= n; i++) {
        print lines[i]
      }
    }
  ' "$file"
}

write_file_if_changed() {
  local target="$1"
  local staged_file="$2"
  local existed=0

  if [[ -f "$target" ]]; then
    existed=1
    if cmp -s "$target" "$staged_file"; then
      log "unchanged: $target"
      return 0
    fi
  fi

  if (( DRY_RUN )); then
    if (( existed )); then
      log "[dry-run] update: $target"
    else
      log "[dry-run] create: $target"
    fi
    return 0
  fi

  cat "$staged_file" > "$target"

  if (( existed )); then
    log "updated: $target"
  else
    log "created: $target"
  fi
}

install_managed_block() {
  local target="$1"
  local template="$2"
  local begin_marker="$3"
  local end_marker="$4"
  local tmp_base
  local tmp_out

  [[ -f "$template" ]] || die "Missing template: $template"

  tmp_base="$(mktemp)"
  tmp_out="$(mktemp)"

  strip_managed_block "$target" "$begin_marker" "$end_marker" > "$tmp_base"

  {
    if [[ -s "$tmp_base" ]]; then
      cat "$tmp_base"
      printf '\n'
    fi
    printf '%s\n' "$begin_marker"
    cat "$template"
    printf '%s\n' "$end_marker"
  } > "$tmp_out"

  write_file_if_changed "$target" "$tmp_out"

  rm -f "$tmp_base" "$tmp_out"
}

is_managed_script() {
  local target="$1"
  [[ -f "$target" ]] || return 1
  grep -Fqx "$SCRIPT_MARKER" "$target"
}

render_managed_script() {
  local template="$1"
  cat "$template"
  printf '\n%s\n' "$SCRIPT_MARKER"
}

install_hpc_script() {
  local target="$1"
  local template="$2"
  local candidate
  local tmp_out

  [[ -f "$template" ]] || die "Missing script template: $template"

  tmp_out="$(mktemp)"
  render_managed_script "$template" > "$tmp_out"

  if [[ -f "$target" ]] && ! is_managed_script "$target"; then
    candidate="${target}.vscode_for_r.new"
    write_file_if_changed "$candidate" "$tmp_out"
    if (( !DRY_RUN )); then
      chmod +x "$candidate"
    fi
    warn "Preserved unmanaged file: $target"
    warn "Wrote managed candidate instead: $candidate"
    rm -f "$tmp_out"
    return 0
  fi

  write_file_if_changed "$target" "$tmp_out"
  if (( !DRY_RUN )); then
    chmod +x "$target"
  fi
  rm -f "$tmp_out"
}

remove_managed_script_if_present() {
  local target="$1"

  if [[ ! -f "$target" ]]; then
    log "absent: $target"
    return 0
  fi

  if ! is_managed_script "$target"; then
    log "kept unmanaged: $target"
    return 0
  fi

  if (( DRY_RUN )); then
    log "[dry-run] remove managed script: $target"
    return 0
  fi

  rm -f "$target"
  log "removed managed script: $target"
}

main() {
  local home_dir
  local mode_dir

  parse_args "$@"

  home_dir="${HOME:?HOME is not set}"
  mode_dir="$TEMPLATES_ROOT/$MODE"

  log "Mode: $MODE"
  if (( DRY_RUN )); then
    log "Dry run: enabled"
  else
    log "Dry run: disabled"
  fi

  install_managed_block "$home_dir/.bashrc" "$mode_dir/bashrc.block" "$BASH_BEGIN" "$BASH_END"
  install_managed_block "$home_dir/.bash_aliases" "$mode_dir/bash_aliases.block" "$BASH_BEGIN" "$BASH_END"
  install_managed_block "$home_dir/.vimrc" "$mode_dir/vimrc.block" "$VIM_BEGIN" "$VIM_END"
  install_managed_block "$home_dir/.Rprofile" "$mode_dir/Rprofile.block" "$BASH_BEGIN" "$BASH_END"

  if [[ "$MODE" == "hpc" ]]; then
    install_hpc_script "$home_dir/vscode.sh" "$mode_dir/vscode.sh"
    install_hpc_script "$home_dir/vscode_big.sh" "$mode_dir/vscode_big.sh"
    install_hpc_script "$home_dir/vscode_gpu.sh" "$mode_dir/vscode_gpu.sh"
  else
    remove_managed_script_if_present "$home_dir/vscode.sh"
    remove_managed_script_if_present "$home_dir/vscode_big.sh"
    remove_managed_script_if_present "$home_dir/vscode_gpu.sh"
  fi

  log "Installation workflow complete."
}

main "$@"
