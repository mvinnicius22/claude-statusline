#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_CONFIG_DIR/settings.json"

# --- backup then strip statusLine ---
if [ -f "$SETTINGS" ]; then
  TS=$(date +%Y%m%d%H%M%S)
  cp "$SETTINGS" "${SETTINGS}.bak-${TS}"
  echo "Backup: ${SETTINGS}.bak-${TS}"
  TMP=$(mktemp)
  jq 'del(.statusLine)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "Removed statusLine from $SETTINGS"
fi

# --- remove script ---
if [ -f "$CLAUDE_CONFIG_DIR/statusline.sh" ]; then
  rm "$CLAUDE_CONFIG_DIR/statusline.sh"
  echo "Removed: $CLAUDE_CONFIG_DIR/statusline.sh"
fi

# --- remove token caches and session origin files ---
removed=0
for f in "$CLAUDE_CONFIG_DIR"/.tokcache-* "$CLAUDE_CONFIG_DIR"/.session-origin-*; do
  [ -f "$f" ] && rm "$f" && removed=$(( removed + 1 ))
done
[ "$removed" -gt 0 ] && echo "Removed $removed cache/origin file(s)"

echo "Done."
