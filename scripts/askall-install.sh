#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="${HOME}/.local/bin"

mkdir -p "$LOCAL_BIN"

rm -f "$LOCAL_BIN/askall" "$LOCAL_BIN/askall-config"
cp "$SCRIPT_DIR/askall" "$LOCAL_BIN/askall"
cp "$SCRIPT_DIR/askall-config" "$LOCAL_BIN/askall-config"
chmod +x "$LOCAL_BIN/askall" "$LOCAL_BIN/askall-config"

# Create default config if none exists
mkdir -p "$HOME/.config/askall"
if [[ ! -f "$HOME/.config/askall/config.env" ]]; then
  cat > "$HOME/.config/askall/config.env" <<'EOF'
# askall configuration
# Uncomment and edit to override defaults
# ASKALL_TOOLS=auto
# ASKALL_CLAUDE_MODEL=claude-sonnet-4-20250514
# ASKALL_GEMINI_MODEL=gemini-2.5-flash
# ASKALL_SGPT_MODEL=gpt-4.1
# ASKALL_DIR=~/askall-responses
EOF
fi

echo "askall installed to $LOCAL_BIN/"
echo ""
echo "  askall --config    Configure models & tools"
echo "  askall 'prompt'    Query all AIs in parallel"
echo "  askall -f file     Load prompt from file"
echo ""
echo "Ensure $LOCAL_BIN is in your PATH."
