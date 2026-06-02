#!/usr/bin/env bash
set -euo pipefail

CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_CONFIG_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- detect OS ---
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macOS" ;;
  Linux)  PLATFORM="Linux/WSL" ;;
  *)      echo "Unsupported OS: $OS. Only macOS and Linux/WSL are supported." >&2; exit 1 ;;
esac
echo "Platform: $PLATFORM"

# --- check bash version ---
if [ "${BASH_VERSINFO[0]:-0}" -lt 3 ]; then
  echo "bash 3.2+ required (found $BASH_VERSION)." >&2; exit 1
fi

# --- check required dependencies (jq) ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Missing required dependency: jq" >&2
  case "$PLATFORM" in
    macOS)     echo "  Install: brew install jq" >&2 ;;
    Linux/WSL)
      if command -v apt-get >/dev/null 2>&1; then echo "  Install: sudo apt install jq" >&2
      elif command -v dnf >/dev/null 2>&1; then echo "  Install: sudo dnf install jq" >&2
      elif command -v pacman >/dev/null 2>&1; then echo "  Install: sudo pacman -S jq" >&2
      else echo "  Install jq via your package manager" >&2; fi ;;
  esac
  exit 1
fi

# --- git is optional: warn only (the git segment is hidden when absent) ---
if ! command -v git >/dev/null 2>&1; then
  echo "Note: git not found — the git segment will be hidden."
fi

# --- install script ---
mkdir -p "$CLAUDE_CONFIG_DIR"
cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_CONFIG_DIR/statusline.sh"
chmod +x "$CLAUDE_CONFIG_DIR/statusline.sh"
echo "Installed: $CLAUDE_CONFIG_DIR/statusline.sh"

# --- backup settings.json ---
TS=$(date +%Y%m%d%H%M%S)
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "${SETTINGS}.bak-${TS}"
  echo "Backup: ${SETTINGS}.bak-${TS}"
else
  echo '{}' > "$SETTINGS"
  echo "Created: $SETTINGS"
fi

# --- inject statusLine ---
STATUSLINE_CMD="bash $CLAUDE_CONFIG_DIR/statusline.sh"
TMP=$(mktemp)
jq --arg cmd "$STATUSLINE_CMD" \
  '.statusLine = {type: "command", command: $cmd, padding: 0, refreshInterval: 5}' \
  "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
echo "Configured statusLine in $SETTINGS"

echo ""
echo "Done. Open a new Claude Code tab or run /statusline to see it."
echo ""
echo "Optional: set SL_ICONS=nerd in the command for Nerd Font glyphs:"
echo "  \"command\": \"SL_ICONS=nerd $CLAUDE_CONFIG_DIR/statusline.sh\""
