#!/usr/bin/env bash
# Claude Code statusline.
# Reads the session JSON on stdin and renders a single line.
# Glyphs: swap the glyph vars below if your font lacks them.
set -uo pipefail

BRANCH_GLYPH='⎇'
SEP='│'
BAR_FULL='█'      # rate-limit gauge, filled cell
BAR_EMPTY='░'     # rate-limit gauge, empty cell
BAR_CELLS=5       # gauge width
RESET_GLYPH='→'   # reads as "resets in"
# Nerd Font glyphs, as UTF-8 bytes (private use area, so literals are fragile)
OS_MAC=$'\xef\x85\xb9'    # U+F179 apple: host
OS_LINUX=$'\xef\x85\xbc'  # U+F17C tux: non-sandbox linux
OS_SANDBOX=$'\xef\x8c\x88' # U+F308 docker whale: sandbox guest (IS_SANDBOX=1)
OS_OTHER='?'

json=$(cat)

# ---- one jq pass -> tab-separated fields ----------------------------------
read -r -d '' JQ <<'JQ_EOF'
def epoch:
  if . == null then ""
  elif type == "number" then (if . > 1e12 then (. / 1000 | floor) else (. | floor) end)
  elif type == "string" then (try fromdateiso8601 catch "")
  else "" end;
def i: if . == null then "" else (. | round) end;

[ (.model.display_name // "?")
, (.effort.level // "")
, (.fast_mode // false)
, (.workspace.current_dir // .cwd // "")
, (.workspace.project_dir // "")
, (.context_window.used_percentage | i)
, (.context_window.total_input_tokens // 0)
, (.context_window.context_window_size // 0)
, (.cost.total_cost_usd // 0)
, (.cost.total_duration_ms // 0)
, (.cost.total_lines_added // 0)
, (.cost.total_lines_removed // 0)
, (.rate_limits.five_hour.used_percentage | i)
, (.rate_limits.five_hour.resets_at | epoch)
, (.rate_limits.seven_day.used_percentage | i)
, (.rate_limits.seven_day.resets_at | epoch)
, (.agent.name // "")
, (.output_style.name // "")
, (.worktree.name // "")
, (.pr.number // "")
, (.thinking.enabled // true)
] | map(tostring) | join("\u001f")
JQ_EOF

IFS=$'\x1f' read -r MODEL EFFORT FAST CWD PROJDIR CTXPCT CTXTOK CTXMAX \
  COST DURMS ADDED REMOVED FH_PCT FH_RESET SD_PCT SD_RESET \
  AGENT STYLE WORKTREE PR THINKING \
  < <(printf '%s' "$json" | jq -r "$JQ" 2>/dev/null)

[[ -z "${MODEL:-}" ]] && { printf 'claude'; exit 0; }

# ---- colors ---------------------------------------------------------------
R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
c() { printf '\033[38;5;%sm' "$1"; }
GRAY=$(c 245); BLUE=$(c 111); CYAN=$(c 80); PINK=$(c 176)
GREEN=$(c 114); YELLOW=$(c 221); RED=$(c 203); TAN=$(c 180)

# green under 60%, yellow under 85%, red above
heat() { local p=${1:-0}; if ((p >= 85)); then c 203; elif ((p >= 60)); then c 221; else c 114; fi; }

# fill gauge: filled cells in the heat color, remainder dim
bar() {
  local p=${1:-0} col=${2:-} filled i out
  ((p > 100)) && p=100; ((p < 0)) && p=0
  filled=$(( (p * BAR_CELLS + 50) / 100 ))          # round to nearest cell
  ((filled == 0 && p > 0)) && filled=1               # any usage shows something
  ((filled >= BAR_CELLS && p < 100)) && filled=$((BAR_CELLS - 1))  # full bar means spent
  ((filled > BAR_CELLS)) && filled=$BAR_CELLS
  out="$col"
  for ((i = 0; i < filled; i++)); do out+="$BAR_FULL"; done
  out+="${D}${GRAY}"
  for ((i = filled; i < BAR_CELLS; i++)); do out+="$BAR_EMPTY"; done
  printf '%s' "${out}${R}"
}

# ---- formatters -----------------------------------------------------------
fmt_k() { local n=${1:-0}
  if   ((n >= 10000000)); then printf '%dM'    $((n/1000000))
  elif ((n >= 1000000));  then printf '%d.%dM' $((n/1000000)) $(((n%1000000)/100000))
  elif ((n >= 100000));   then printf '%dk'    $((n/1000))
  elif ((n >= 1000));     then printf '%d.%dk' $((n/1000))    $(((n%1000)/100))
  else printf '%d' "$n"; fi; }

fmt_dur() { local s=$(( ${1:-0} / 1000 ))
  if   ((s >= 3600)); then printf '%dh%02dm' $((s/3600)) $((s%3600/60))
  elif ((s >= 60));   then printf '%dm' $((s/60))
  else printf '%ds' "$s"; fi; }

fmt_left() { # seconds remaining -> "2h14m" / "18m"
  local s=${1:-0}; ((s < 0)) && s=0
  if   ((s >= 86400)); then printf '%dd%02dh' $((s/86400)) $((s%86400/3600))
  elif ((s >= 3600));  then printf '%dh%02dm' $((s/3600))  $((s%3600/60))
  else printf '%dm' $(( (s+59)/60 )); fi; }

seg=()   # collected segments

# ---- OS symbol: tells the macOS host from the Linux sandbox at a glance ----
if [[ "${IS_SANDBOX:-}" == "1" ]]; then
  os="$(c 39)${OS_SANDBOX}${R}"                # docker blue
else
  case "$OSTYPE" in
    darwin*) os="$OS_MAC" ;;
    linux*)  os="$(c 220)${OS_LINUX}${R}" ;;   # bright yellow: the filled tux reads dark otherwise
    *)       os="$OS_OTHER" ;;
  esac
fi

if [[ "${IS_SANDBOX:-}" == "1" ]]; then   # sandbox name, right after the whale
  host="${HOSTNAME:-$(hostname 2>/dev/null)}"
  os+=" ${GRAY}(${host%%.*})${R}"
fi

# ---- OS + directory + git -------------------------------------------------
dir="${CWD##*/}"; [[ -z "$dir" ]] && dir="/"
d="${os} ${BLUE}${dir}${R}"
if br=$(git -C "$CWD" symbolic-ref --quiet --short HEAD 2>/dev/null) \
  || br=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null); then
  dirty=""
  [[ -n $(git -C "$CWD" status --porcelain --untracked-files=no 2>/dev/null | head -c1) ]] && dirty="${YELLOW}*${R}"
  d+=" ${D}${GRAY}${BRANCH_GLYPH}${R} ${PINK}${br}${R}${dirty}"
fi
[[ -n "$WORKTREE" ]] && d+=" ${D}${GRAY}wt:${WORKTREE}${R}"
[[ -n "$PR" ]] && d+=" ${D}${GRAY}#${PR}${R}"
seg+=("$d")

# ---- model / effort / mode ------------------------------------------------
m="${CYAN}${B}${MODEL}${R}"
[[ -n "$EFFORT" && "$EFFORT" != "null" ]] && m+="${D}${GRAY} ${EFFORT}${R}"
[[ "$FAST" == "true" ]] && m+=" ${YELLOW}⚡${R}"
[[ "$THINKING" == "false" ]] && m+=" ${D}${GRAY}nothink${R}"
[[ -n "$AGENT" ]] && m+=" ${PINK}@${AGENT}${R}"
[[ -n "$STYLE" && "$STYLE" != "default" && "$STYLE" != "null" ]] && m+=" ${D}${GRAY}${STYLE}${R}"
seg+=("$m")

# ---- context window -------------------------------------------------------
if [[ -n "$CTXPCT" && "$CTXMAX" -gt 0 ]]; then
  hc=$(heat "$CTXPCT")
  seg+=("${D}${GRAY}ctx${R} ${hc}${CTXPCT}%${R} ${D}${GRAY}$(fmt_k "$CTXTOK")/$(fmt_k "$CTXMAX")${R}")
fi

# ---- cost / duration / diff ----------------------------------------------
cst="${TAN}\$$(printf '%.2f' "$COST")${R} ${D}${GRAY}$(fmt_dur "$DURMS")${R}"
if ((ADDED > 0 || REMOVED > 0)); then
  cst+=" ${GREEN}+${ADDED}${R}${D}/${R}${RED}-${REMOVED}${R}"
fi
seg+=("$cst")

# ---- rate limits ----------------------------------------------------------
now=$(date +%s)
lim=""
for pair in "5h:$FH_PCT:$FH_RESET" "7d:$SD_PCT:$SD_RESET"; do
  IFS=: read -r label pct reset <<<"$pair"
  [[ -z "$pct" ]] && continue
  hc=$(heat "$pct")
  # %2d keeps the width stable so the line does not jitter as usage climbs
  part="${D}${GRAY}${label}${R} $(bar "$pct" "$hc") ${hc}$(printf '%2d' "$pct")%${R}"
  if [[ -n "$reset" && "$reset" =~ ^[0-9]+$ ]]; then
    part+=" ${D}${GRAY}${RESET_GLYPH}$(fmt_left $((reset - now)))${R}"
  fi
  [[ -n "$lim" ]] && lim+="  "
  lim+="$part"
done
[[ -n "$lim" ]] && seg+=("$lim")

# ---- join -----------------------------------------------------------------
out=""
for s in "${seg[@]}"; do
  [[ -n "$out" ]] && out+=" ${D}${GRAY}${SEP}${R} "
  out+="$s"
done
printf '%s' "$out"
