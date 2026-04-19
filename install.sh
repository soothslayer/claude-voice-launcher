#!/bin/bash
# install.sh — one-shot installer for Claude Voice Launcher
#
# Clone the repo, cd into it, then run:   bash install.sh
#
# Prerequisites:
#   - macOS 13 Ventura or newer
#   - Claude Code installed on PATH (`claude --version` works)
#     Install from https://docs.anthropic.com/claude/docs/claude-code
#   - VoiceMode skill available to Claude Code (provides /voicemode:converse)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"
APP_DIR="$HOME/Applications"
APP_PATH="$APP_DIR/Claude Voice.app"
DESKTOP_LINK="$HOME/Desktop/Claude Voice.app"

echo "==> Claude Voice installer starting"

for f in \
	"$SCRIPT_DIR/claude-voice-launcher.applescript" \
	"$SCRIPT_DIR/claude-voice-setup.command" \
	"$SCRIPT_DIR/install-voice-control-command.sh" \
	"$SCRIPT_DIR/install-siri-shortcut.sh"
do
	if [ ! -f "$f" ]; then
		echo "ERROR: missing source file: $f" >&2
		exit 1
	fi
done

if ! command -v claude >/dev/null 2>&1; then
	echo "ERROR: 'claude' not on PATH. Install Claude Code first." >&2
	/usr/bin/say -r 180 "Claude Code is not installed. Please install it first, then run this installer again."
	exit 1
fi

mkdir -p "$BIN_DIR" "$APP_DIR"

# Copy scripts into ~/bin so they're easy to find and invoke later
cp "$SCRIPT_DIR/claude-voice-launcher.applescript" "$BIN_DIR/"
cp "$SCRIPT_DIR/claude-voice-setup.command"        "$BIN_DIR/"
cp "$SCRIPT_DIR/install-voice-control-command.sh"  "$BIN_DIR/"
cp "$SCRIPT_DIR/install-siri-shortcut.sh"          "$BIN_DIR/"

chmod +x \
	"$BIN_DIR/claude-voice-setup.command" \
	"$BIN_DIR/install-voice-control-command.sh" \
	"$BIN_DIR/install-siri-shortcut.sh"

# Compile .app bundle
echo "==> Compiling $APP_PATH"
rm -rf "$APP_PATH"
/usr/bin/osacompile -o "$APP_PATH" "$BIN_DIR/claude-voice-launcher.applescript"

# Set bundle id for stable Automation/Accessibility permission tracking
/usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.$(id -un).claudevoice" "$APP_PATH/Contents/Info.plist"

# Desktop shortcut (symlink)
rm -f "$DESKTOP_LINK"
ln -s "$APP_PATH" "$DESKTOP_LINK"

echo "==> Install complete"
echo "    App:     $APP_PATH"
echo "    Desktop: $DESKTOP_LINK"
echo ""
echo "==> Launching permissions setup (interactive, voice-narrated)..."
sleep 1
exec "$BIN_DIR/claude-voice-setup.command"
