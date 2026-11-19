#!/usr/bin/env bash
# Claude Code status line, styled after the herdr.dev hero mock:
#   ~/path > branch * ↑1        ctx ████──── 3% 31k/1M · cache 92% · $0.41
#                                                            Opus 5.5 · high
# Reads the session JSON on stdin (see https://code.claude.com/docs/en/statusline).

input=$(cat)

# Width maths below counts characters, so bash needs a UTF-8 locale or "█"
# counts as 3 and the right side lands short of the edge. Git Bash (Windows)
# runs status lines without one.
probe="█"
if (( ${#probe} != 1 )); then
  for loc in C.UTF-8 en_US.UTF-8 C.utf8 en_US.utf8; do
    LC_ALL=$loc; probe="█"; (( ${#probe} == 1 )) && break
  done
fi
export LC_ALL

cyan=$'\e[36m'; yellow=$'\e[33m'; green=$'\e[32m'; red=$'\e[31m'
magenta=$'\e[35m'; grey=$'\e[90m'; reset=$'\e[0m'

# \x1f separator: a tab would let `read` swallow an empty first field
IFS=$'\x1f' read -r dir pct used size model effort cost cread ccreate cin < <(jq -r '[
  .workspace.current_dir // .cwd // "",
  (.context_window.used_percentage // 0 | floor),
  (.context_window.total_input_tokens // 0),
  (.context_window.context_window_size // 200000),
  (.model.display_name // ""),
  (.effort.level // ""),
  (.cost.total_cost_usd // 0),
  (.context_window.current_usage.cache_read_input_tokens // 0),
  (.context_window.current_usage.cache_creation_input_tokens // 0),
  (.context_window.current_usage.input_tokens // 0)
] | map(tostring) | join("\u001f")' <<<"$input" | tr -d '\r')  # jq.exe on Windows ends lines with CRLF
dir=${dir:-$PWD}
# Windows (Git Bash): Claude Code reports C:\Users\..., which neither the ~
# shortening below nor every git build understands.
[[ $dir == [A-Za-z]:\\* ]] && command -v cygpath >/dev/null && dir=$(cygpath -u "$dir")

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
    # Integer maths, not bc: Git Bash on Windows ships without it.
    local t=$(( n / 100000 ))
    (( t % 10 )) && printf '%d.%dM' $((t / 10)) $((t % 10)) || printf '%dM' $((t / 10))
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

# Per-session cost and prompt-cache hit rate (share of the last request's input
# served from cache). Cache is only shown once there is a request to measure.
cost_txt=$(printf '$%.2f' "${cost:-0}")
total_in=$(( cread + ccreate + cin ))
if (( total_in > 0 )); then
  cache_pct=$(( cread * 100 / total_in ))
  if   (( cache_pct < 50 )); then ccol=$red
  elif (( cache_pct < 80 )); then ccol=$yellow
  else ccol=$green; fi
  right+="${grey} · cache ${reset}${ccol}${cache_pct}%${reset}"
fi
right+="${grey} · ${cost_txt}${reset}"

# Model and reasoning effort (effort is absent for models without it), on a
# second line under the context figures so the top line has room to breathe.
right2=""
if [[ -n $model ]]; then
  right2="${magenta}${model}${reset}"
  [[ -n $effort ]] && right2+="${grey} · ${effort}${reset}"
fi

# Inside herdr, publish model and effort as $model / $effort tokens on this
# pane's sidebar agent row. Only when they change: the status line runs often.
if [[ -n ${HERDR_PANE_ID:-} && -n $model ]] && command -v herdr >/dev/null; then
  # Keyed by the socket too: a new herdr server (next workbench job) starts
  # without the tokens, so the same pane id must publish again.
  key="${HERDR_SOCKET_PATH:-}-${HERDR_SESSION:-default}-$HERDR_PANE_ID"
  cache="${TMPDIR:-/tmp}/claude-statusline-$USER/${key//[^A-Za-z0-9]/_}"
  sig="$model|$effort|$cost_txt"
  if [[ $(cat "$cache" 2>/dev/null) != "$sig" ]]; then
    mkdir -p "${cache%/*}"
    args=(--token "model=$model" --token "cost=$cost_txt")
    if [[ -n $effort ]]; then args+=(--token "effort=$effort"); else args+=(--clear-token effort); fi
    # macOS has no `timeout` (coreutils' is `gtimeout`); run bare without one.
    to=(); for t in timeout gtimeout; do command -v $t >/dev/null && { to=($t 2); break; }; done
    "${to[@]}" herdr pane report-metadata "$HERDR_PANE_ID" --source claude-statusline "${args[@]}" \
      >/dev/null 2>&1 && printf '%s' "$sig" >"$cache"
  fi
fi

# Herdr desktop app (Windows/macOS GUI, herdr-core `hc`): there is no
# report-metadata, so publish the same facts as labels on this terminal. The
# `agents-rich` mod (herdr-app/mods/agents-rich) shows them on the agent row.
if [[ -n ${HC_TERMINAL_ID:-} && -n $model ]] && command -v hc >/dev/null; then
  ctx_txt="⛁ ${pct}% ($(fmt "$used"))"
  key="${HC_TERMINAL_SOCKET:-}-$HC_TERMINAL_ID"
  cache="${TMPDIR:-/tmp}/claude-statusline-${USER:-$USERNAME}/hc-${key//[^A-Za-z0-9]/_}"
  sig="$model|$effort|$ctx_txt|$cost_txt|${cache_pct:-}"
  if [[ $(cat "$cache" 2>/dev/null) != "$sig" ]]; then
    mkdir -p "${cache%/*}"
    to=(); command -v timeout >/dev/null && to=(timeout 2)
    "${to[@]}" hc label "$HC_TERMINAL_ID" "claude.model=$model" "claude.effort=$effort" \
      "claude.context=$ctx_txt" "claude.cost=$cost_txt" "claude.cache=${cache_pct:-}" \
      >/dev/null 2>&1 && printf '%s' "$sig" >"$cache"
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
# Second line: model and effort, right-justified to the same edge.
if [[ -n $right2 ]]; then
  pad=$(( ${COLUMNS:-0} - reserve - $(visible "$right2") ))
  if (( pad > 0 )); then printf '%*s%s\n' "$pad" '' "$right2"; else printf '%s\n' "$right2"; fi
fi
