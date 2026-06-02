#!/usr/bin/env bash
# Claude Code statusline — aligned, multi-line, color-coded.
#
#   🪨 CAVEMAN │ 🤖 Opus 4.8 ⚡high · default │ 📁 proj on 🌿 branch (N changed)
#   ctx █░░░░░░░░░  11% · 890k left · $4.92
#   5h  ██████░░░░  66% · 34% left · ↺ 15:50 (3h04m) →
#   7d  ██░░░░░░░░  26% · 74% left · ↺ Fri 11:00
#   tok fresh 24.9k · write 252k · read 9.3M · out 175k · hit 92%
#
# 5h/7d come from the subscription's rate_limits in stdin (Pro/Max). The pace
# arrow projects end-of-window usage: → on pace, ↑ will exhaust early, ↓ slack.
#
# Hide any segment with an env var in the statusLine command, e.g.
#   "command": "SL_TOKENS=0 SL_CAVEMAN=0 ~/.claude/statusline.sh"
# Toggles: SL_CAVEMAN SL_GIT SL_CTX SL_LIMITS SL_7D SL_TOKENS SL_DRIFT  (set to 0 to hide)
# Icons:   SL_ICONS=emoji (default) | nerd (Nerd Font glyphs) | none

CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

input=$(cat)

# --- portability: GNU vs BSD ---
_GNU_DATE=0; date --version >/dev/null 2>&1 && _GNU_DATE=1
_GNU_STAT=0; stat --version >/dev/null 2>&1 && _GNU_STAT=1
epoch_fmt() { if [ "$_GNU_DATE" = 1 ]; then date -d "@$1" "+$2"; else date -r "$1" "+$2"; fi; }
file_mtime() { if [ "$_GNU_STAT" = 1 ]; then stat -c %Y "$1" 2>/dev/null; else stat -f %m "$1" 2>/dev/null; fi; }

# --- icon set ---
case "${SL_ICONS:-emoji}" in
  nerd)
    IC_MODEL="󰚩 "; IC_DIR=" "; IC_BRANCH=" "
    ;;
  none)
    IC_MODEL=""; IC_DIR=""; IC_BRANCH=""
    ;;
  *)
    IC_MODEL="🤖 "; IC_DIR="📁 "; IC_BRANCH="🌿 "
    ;;
esac

# --- ANSI ---
R=$'\033[0m'; B=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'
BLU=$'\033[34m'; MAG=$'\033[35m'; CYN=$'\033[36m'; GRY=$'\033[90m'
ORANGE=$'\033[38;5;172m'
SEP="${GRY} │ ${R}"

# --- graceful fallback if jq missing ---
if ! command -v jq >/dev/null 2>&1; then
  MODEL=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | cut -d'"' -f4)
  DIR=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -z "$DIR" ] && DIR=$(echo "$input" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
  printf '%b\n' "${IC_MODEL}${MODEL:-?} │ ${IC_DIR}${DIR##*/}"
  exit 0
fi

# --- one jq pass ---
IFS=$'\t' read -r MODEL EFFORT STYLE CUR_DIR CTX_USED CTX_SIZE COST \
        H5_PCT H5_RESET D7_PCT D7_RESET TRANSCRIPT < <(
  echo "$input" | jq -r '
    [ .model.display_name // "?",
      (.effort.level // "-"),
      (.output_style.name // "default"),
      (.workspace.current_dir // .cwd // "?"),
      (.context_window.total_input_tokens // 0),
      (.context_window.context_window_size // 200000),
      (.cost.total_cost_usd // 0),
      (.rate_limits.five_hour.used_percentage // -1 | floor),
      (.rate_limits.five_hour.resets_at // 0),
      (.rate_limits.seven_day.used_percentage // -1 | floor),
      (.rate_limits.seven_day.resets_at // 0),
      (.transcript_path // "")
    ] | @tsv'
)

DIR_NAME="${CUR_DIR##*/}"
NOW=$(date +%s)
PCT=0; [ "$CTX_SIZE" -gt 0 ] 2>/dev/null && PCT=$(( CTX_USED * 100 / CTX_SIZE ))

# --- session drift: detect cwd changes since session started ---
DRIFT_NAME=""
if [ -n "$TRANSCRIPT" ] && [ "${SL_DRIFT:-1}" != 0 ]; then
  SID=$(basename "$TRANSCRIPT" .jsonl)
  OFILE="$CLAUDE_CONFIG_DIR/.session-origin-$SID"
  if [ ! -f "$OFILE" ]; then
    printf '%s\n' "$CUR_DIR" > "$OFILE"
  else
    SESSION_ORIGIN=$(head -1 "$OFILE" 2>/dev/null)
    [ "$CUR_DIR" != "$SESSION_ORIGIN" ] && [ -n "$SESSION_ORIGIN" ] && DRIFT_NAME="${SESSION_ORIGIN##*/}"
  fi
fi

human() { local n=$1; if [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n/1000000)) $(((n%1000000)/100000)); elif [ "$n" -ge 1000 ]; then printf '%d.%dk' $((n/1000)) $(((n%1000)/100)); else printf '%d' "$n"; fi; }

# 10-cell bar, filled colored by percent, empty dimmed
bar() {
  local p=$1 f e i out="" c
  f=$(( p/10 )); [ "$f" -gt 10 ] && f=10; [ "$f" -lt 0 ] && f=0; e=$(( 10-f ))
  if   [ "$p" -ge 80 ]; then c="$RED"; elif [ "$p" -ge 60 ]; then c="$YEL"; else c="$GRN"; fi
  for ((i=0;i<f;i++)); do out="${out}█"; done
  printf '%s%s%s' "$c" "$out" "$DIM"
  out=""; for ((i=0;i<e;i++)); do out="${out}░"; done
  printf '%s%s' "$out" "$R"
}

countdown() { local s=$(( $1 - NOW )); [ "$s" -lt 0 ] && s=0; printf '%dh%02dm' $((s/3600)) $(((s%3600)/60)); }

# pace arrow: project window-end usage from elapsed fraction
pace() {
  local used=$1 reset=$2 dur=$3 elapsed proj
  elapsed=$(( NOW - (reset - dur) ))
  [ "$elapsed" -le 0 ] && return
  proj=$(( used * dur / elapsed ))
  if   [ "$proj" -gt 115 ]; then printf '%s↑%s' "$RED" "$R"
  elif [ "$proj" -gt 85  ]; then printf '%s→%s' "$YEL" "$R"
  else printf '%s↓%s' "$GRN" "$R"; fi
}

# ---------- LINE 1: identity ----------
SEG1=()
if [ "${SL_CAVEMAN:-1}" != 0 ]; then
  FLAG="$CLAUDE_CONFIG_DIR/.caveman-active"
  if [ -f "$FLAG" ] && [ ! -L "$FLAG" ]; then
    M=$(head -c 32 "$FLAG" | tr -cd 'a-z0-9-')
    if [ -n "$M" ] && [ "$M" != off ]; then
      [ "$M" = full ] && BADGE="🪨 CAVEMAN" || BADGE="🪨 CAVEMAN:$(printf '%s' "$M" | tr a-z A-Z)"
      SEG1+=("${ORANGE}${B}${BADGE}${R}")
    fi
  fi
fi
case "$EFFORT" in
  max|xhigh) EFC="$RED";; high) EFC="$MAG";; medium) EFC="$YEL";; low) EFC="$GRN";; *) EFC="$GRY";;
esac
SEG1+=("${B}${CYN}${IC_MODEL}${MODEL}${R} ${EFC}⚡${EFFORT}${R} ${DIM}${STYLE}${R}")

GIT=""
if [ "${SL_GIT:-1}" != 0 ] && git -C "$CUR_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$CUR_DIR" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$CUR_DIR" rev-parse --short HEAD 2>/dev/null)
  # compact per-type counts: A added · M modified · D deleted · R renamed · ? untracked
  COUNTS=$(git -C "$CUR_DIR" status --porcelain -uall 2>/dev/null | awk '
    /^\?\?/{u++;next} /^R|^.R/{r++;next} /^D|^.D/{d++;next}
    /^A|^.A/{a++;next} /^M|^.M/{m++;next} {m++}
    END{printf "%d %d %d %d %d", a+0,m+0,d+0,r+0,u+0}')
  read -r CA CM CD CR CU <<< "$COUNTS"
  CH=""
  [ "${CA:-0}" -gt 0 ] && CH="${CH} ${GRN}A${CA}${R}"
  [ "${CM:-0}" -gt 0 ] && CH="${CH} ${YEL}M${CM}${R}"
  [ "${CD:-0}" -gt 0 ] && CH="${CH} ${RED}D${CD}${R}"
  [ "${CR:-0}" -gt 0 ] && CH="${CH} ${BLU}R${CR}${R}"
  [ "${CU:-0}" -gt 0 ] && CH="${CH} ${GRY}?${CU}${R}"
  AB=$(git -C "$CUR_DIR" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  AH=$(echo "$AB"|awk '{print $2}'); BH=$(echo "$AB"|awk '{print $1}'); AR=""
  [ -n "$AH" ] && [ "$AH" -gt 0 ] 2>/dev/null && AR="${AR} ${GRN}↑$AH${R}"
  [ -n "$BH" ] && [ "$BH" -gt 0 ] 2>/dev/null && AR="${AR} ${RED}↓$BH${R}"
  GIT="${GRY}on${R} ${MAG}${IC_BRANCH}${BRANCH}${R}${CH}${AR}"
fi
DRIFT_SEG=""
[ -n "$DRIFT_NAME" ] && DRIFT_SEG=" ${GRY}← ${DRIFT_NAME}${R}"
SEG1+=("${BLU}${IC_DIR}${DIR_NAME}${R} ${GIT}${DRIFT_SEG}")

OUT=""
for i in "${!SEG1[@]}"; do [ "$i" -gt 0 ] && OUT="${OUT}${SEP}"; OUT="${OUT}${SEG1[$i]}"; done
printf '%b\n' "$OUT"

# ---------- LINE 2: context ----------
if [ "${SL_CTX:-1}" != 0 ]; then
  LEFT_H=$(human $(( CTX_SIZE - CTX_USED )))
  printf '%b\n' "$(printf '%-3s' ctx) $(bar "$PCT") $(printf '%3d' "$PCT")% ${GRY}·${R} ${LEFT_H} ${GRY}left${R} ${GRY}·${R} ${GRN}$(printf '$%.2f' "$COST")${R}"
fi

# ---------- LINE 3-4: subscription limits ----------
if [ "${SL_LIMITS:-1}" != 0 ] && [ "$H5_PCT" -ge 0 ] 2>/dev/null; then
  R5=$(( 100 - H5_PCT )); EXTRA=""
  [ "$H5_RESET" -gt 0 ] 2>/dev/null && EXTRA=" ${GRY}·${R} ${GRY}↺ $(epoch_fmt "$H5_RESET" '%H:%M') ($(countdown "$H5_RESET"))${R} $(pace "$H5_PCT" "$H5_RESET" 18000)"
  printf '%b\n' "$(printf '%-3s' 5h) $(bar "$H5_PCT") $(printf '%3d' "$H5_PCT")% ${GRY}·${R} ${R5}% ${GRY}left${R}${EXTRA}"
fi
if [ "${SL_LIMITS:-1}" != 0 ] && [ "${SL_7D:-1}" != 0 ] && [ "$D7_PCT" -ge 0 ] 2>/dev/null; then
  R7=$(( 100 - D7_PCT )); EXTRA=""
  [ "$D7_RESET" -gt 0 ] 2>/dev/null && EXTRA=" ${GRY}·${R} ${GRY}↺ $(epoch_fmt "$D7_RESET" '%a %H:%M')${R}"
  printf '%b\n' "$(printf '%-3s' 7d) $(bar "$D7_PCT") $(printf '%3d' "$D7_PCT")% ${GRY}·${R} ${R7}% ${GRY}left${R}${EXTRA}"
fi

# ---------- LINE 5: token breakdown (cached by transcript mtime) ----------
if [ "${SL_TOKENS:-1}" != 0 ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  MT=$(file_mtime "$TRANSCRIPT")
  TC="$CLAUDE_CONFIG_DIR/.tokcache-$(basename "$TRANSCRIPT" .jsonl)"
  if [ -f "$TC" ] && [ "$(head -1 "$TC" 2>/dev/null)" = "$MT" ]; then
    read -r FRESH CW CR TOUT < <(tail -1 "$TC")
  else
    read -r FRESH CW CR TOUT < <(
      jq -rn 'reduce (inputs.message.usage // empty) as $u
        ([0,0,0,0];
         [ .[0]+($u.input_tokens//0), .[1]+($u.cache_creation_input_tokens//0),
           .[2]+($u.cache_read_input_tokens//0), .[3]+($u.output_tokens//0) ]) | @tsv' \
        "$TRANSCRIPT" 2>/dev/null | tr '\t' ' '
    )
    printf '%s\n%s %s %s %s\n' "$MT" "${FRESH:-0}" "${CW:-0}" "${CR:-0}" "${TOUT:-0}" > "$TC"
  fi
  # cache hit rate = cache reads / total input (fresh + write + read).
  # High is good: reads cost 0.1x vs 1x fresh / 1.25x write.
  IN_TOTAL=$(( ${FRESH:-0} + ${CW:-0} + ${CR:-0} ))
  HIT=0; [ "$IN_TOTAL" -gt 0 ] && HIT=$(( ${CR:-0} * 100 / IN_TOTAL ))
  if   [ "$HIT" -ge 70 ]; then HITC="$GRN"; elif [ "$HIT" -ge 40 ]; then HITC="$YEL"; else HITC="$RED"; fi
  printf '%b\n' "$(printf '%-3s' tok) ${CYN}fresh${R} $(human "${FRESH:-0}") ${GRY}·${R} ${MAG}write${R} $(human "${CW:-0}") ${GRY}·${R} ${BLU}read${R} $(human "${CR:-0}") ${GRY}·${R} ${GRN}out${R} $(human "${TOUT:-0}") ${GRY}·${R} ${HITC}hit ${HIT}%${R}"
fi
