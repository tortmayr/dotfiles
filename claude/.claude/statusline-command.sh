#!/usr/bin/env bash
command -v jq >/dev/null 2>&1 || { echo "statusline: jq not found" >&2; exit 1; }

readonly CYAN='\033[36m' BLUE='\033[34m' GREEN='\033[32m'
readonly YELLOW='\033[33m' RED='\033[31m' GRAY='\033[90m' RESET='\033[0m'
readonly SEPARATOR=" · "

parse_input() {
  local input
  input=$(cat)
  IFS=$'\t' read -r model dir cost pct five_pct week_pct effort < <(
    echo "$input" | jq -r '[
      .model.display_name,
      .workspace.current_dir,
      (.cost.total_cost_usd // 0 | tostring),
      (.context_window.used_percentage // 0 | floor | tostring),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.effort.level // "")
    ] | @tsv' 2>/dev/null
  ) || { echo "statusline: failed to parse input" >&2; exit 1; }
}

format_bar() {
  local filled empty segments=20
  if [ "$pct" -ge 90 ]; then bar_color="$RED"
  elif [ "$pct" -ge 70 ]; then bar_color="$YELLOW"
  else bar_color="$GREEN"; fi
  filled=$((pct / 5)); empty=$((segments - filled))
  printf -v bar_filled "%${filled}s"; printf -v bar_empty "%${empty}s"
  bar_filled="${bar_filled// /█}"; bar_empty="${bar_empty// /█}"
}

render_statusline() {
  local branch=""
  git rev-parse --git-dir >/dev/null 2>&1 && branch=" $(git branch --show-current 2>/dev/null)"

  local cost_fmt
  cost_fmt=$(printf '$%.2f' "$cost")

  local rate_limits=""
  if [ -n "$five_pct" ] && [ "$five_pct" != "null" ]; then
    local fr fr_color
    fr=$(printf '%.0f' "$(echo "$five_pct" | awk '{print 100 - $1}')")
    if [ "$fr" -le 20 ]; then fr_color="$RED"
    elif [ "$fr" -le 40 ]; then fr_color="$YELLOW"
    else fr_color="$GREEN"; fi
    rate_limits+="${SEPARATOR}5h: ${fr_color}${fr}%${RESET}"
  fi
  if [ -n "$week_pct" ] && [ "$week_pct" != "null" ]; then
    local wr wr_color
    wr=$(printf '%.0f' "$(echo "$week_pct" | awk '{print 100 - $1}')")
    if [ "$wr" -le 20 ]; then wr_color="$RED"
    elif [ "$wr" -le 40 ]; then wr_color="$YELLOW"
    else wr_color="$GREEN"; fi
    rate_limits+="${SEPARATOR}7d: ${wr_color}${wr}%${RESET}"
  fi

  local model_seg="${CYAN}${model}${RESET}"
  if [ -n "$effort" ] && [ "$effort" != "null" ]; then
    model_seg+="${SEPARATOR}${CYAN}${effort}${RESET}"
  fi

  printf '%b\n' "${model_seg}${SEPARATOR}${BLUE}${dir##*/}${RESET}${SEPARATOR}${branch}"
  printf '%b\n' "${bar_color}${bar_filled}${GRAY}${bar_empty}${RESET} ${pct}%${rate_limits}${SEPARATOR}${YELLOW}${cost_fmt}${RESET}"
}

parse_input
format_bar
render_statusline
