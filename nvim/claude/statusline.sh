#!/usr/bin/env bash
# Claude Code status line, styled after the herdr.dev hero mock:
#   ~/path > branch * ↑1              ctx ████──── 3% 31k/1M > Opus · high
# Reads the session JSON on stdin (see https://code.claude.com/docs/en/statusline).

input=$(cat)

cyan=$'\e[36m'; yellow=$'\e[33m'; green=$'\e[32m'; red=$'\e[31m'
magenta=$'\e[35m'; grey=$'\e[90m'; reset=$'\e[0m'

# \x1f separator: a tab would let `read` swallow an empty first field
IFS=$'\x1f' read -r dir pct used size model effort < <(jq -r '[
  .workspace.current_dir // .cwd // "",
  (.context_window.used_percentage // 0 | floor),
  (.context_window.total_input_tokens // 0),
  (.context_window.context_window_size // 200000),
  (.model.display_name // ""),
  (.effort.level // "")
] | map(tostring) | join("\u001f")' <<<"$input")
dir=${dir:-$PWD}

# Directory, with $HOME shortened to ~
shown=$dir
# Not ${dir/#$HOME/\~}: macOS's bash 3.2 keeps the backslash.
[[ $dir == "$HOME" || $dir == "$HOME"/* ]] && shown="~${dir#"$HOME"}"
out="${cyan}${shown}${reset}"

# Git branch, dirty marker, commits ahead/behind upstream
if branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null \
            || git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null); then
  dirty=""
  [[ -n $(git -C "$dir" --no-optional-locks status --porcelain -uno 2>/dev/null | head -1) ]] && dirty=" *"
  out+="${grey} > ${reset}${yellow}${branch}${dirty}${reset}"
  if counts=$(git -C "$dir" --no-optional-locks rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
    read -r behind ahead <<<"$counts"
    (( ahead > 0 )) && out+="${green} ↑${ahead}${reset}"
    (( behind > 0 )) && out+="${red} ↓${behind}${reset}"
  fi
fi

# Human-readable token counts: 31k, 1M
fmt() {
  local n=$1
  if (( n >= 1000000 )); then
    (( n % 1000000 )) && printf '%.1fM' "$(bc -l <<<"$n/1000000")" || printf '%dM' $((n / 1000000))
  elif (( n >= 1000 )); then printf '%dk' $((n / 1000))
  else printf '%d' "$n"; fi
}

# Context bar: 8 cells, green/yellow/red as the window fills
width=8
filled=$(( (pct * width + 50) / 100 ))
(( filled > width )) && filled=$width
if   (( pct >= 80 )); then colour=$red
elif (( pct >= 50 )); then colour=$yellow
else colour=$green; fi
full=""; empty=""
for ((i = 0; i < width; i++)); do
  if (( i < filled )); then full+="█"; else empty+="─"; fi
done
right="${grey}ctx ${reset}${colour}${full}${reset}${grey}${empty}${reset}"
right+=" ${colour}${pct}%${reset}${grey} $(fmt "$used")/$(fmt "$size")${reset}"

# Model and reasoning effort (effort is absent for models without it)
if [[ -n $model ]]; then
  right+="${grey} > ${reset}${magenta}${model}${reset}"
  [[ -n $effort ]] && right+="${grey} · ${effort}${reset}"
fi

# Inside herdr, publish model and effort as $model / $effort tokens on this
# pane's sidebar agent row. Only when they change: the status line runs often.
if [[ -n ${HERDR_PANE_ID:-} && -n $model ]] && command -v herdr >/dev/null; then
  # Keyed by the socket too: a new herdr server (next workbench job) starts
  # without the tokens, so the same pane id must publish again.
  key="${HERDR_SOCKET_PATH:-}-${HERDR_SESSION:-default}-$HERDR_PANE_ID"
  cache="${TMPDIR:-/tmp}/claude-statusline-$USER/${key//[^A-Za-z0-9]/_}"
  if [[ $(cat "$cache" 2>/dev/null) != "$model|$effort" ]]; then
    mkdir -p "${cache%/*}"
    args=(--token "model=$model")
    if [[ -n $effort ]]; then args+=(--token "effort=$effort"); else args+=(--clear-token effort); fi
    # macOS has no `timeout` (coreutils' is `gtimeout`); run bare without one.
    to=(); for t in timeout gtimeout; do command -v $t >/dev/null && { to=($t 2); break; }; done
    "${to[@]}" herdr pane report-metadata "$HERDR_PANE_ID" --source claude-statusline "${args[@]}" \
      >/dev/null 2>&1 && printf '%s' "$model|$effort" >"$cache"
  fi
fi

# Feed the same JSON to the usagebar plugin's statusLine bridge: its
# `rate_limits` are the only live source for the Ctrl-a u popup's 5h / weekly
# windows (otherwise it falls back to ~/.claude.json's cachedUsageUtilization,
# which Claude Code rarely refreshes). Backgrounded; its own output is unused.
for bridge in "$HOME"/.config/herdr/plugins/github/usagebar-*/bin/run-statusline.sh; do
  [[ -f $bridge ]] && { bash "$bridge" <<<"$input" >/dev/null 2>&1 & disown; }
  break
done

# Right-justify context/model. Claude Code captures stdout, so the width comes
# from $COLUMNS (which it sets). It reserves 2 built-in + `padding` (2) columns
# on EACH side - measured on a 185-col pane: 177 usable, overflow gets "…" -
# plus 1 spare. Keep `reserve` in step with "padding" in settings.json.
# Too narrow, or no width: one line.
reserve=9
visible() { local t; t=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$1"); printf '%d' "${#t}"; }
gap=$(( ${COLUMNS:-0} - reserve - $(visible "$out") - $(visible "$right") ))
if (( gap >= 3 )); then
  printf '%s%*s%s\n' "$out" "$gap" '' "$right"
else
  printf '%s\n' "$out${grey} > ${reset}$right"
fi
