#!/bin/bash
# Claude Voice — One-time Permissions & Environment Setup
#
# Run this ONCE on a new Mac. Double-click it in Finder, or run from Terminal.
# Every step is spoken aloud so a blind user can follow without sight.

set -u

APP_PATH="$HOME/Applications/Claude Voice.app"
SENTINEL="$HOME/.claude/.voice-launcher-setup-complete"
SAY_RATE=210
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say_slow() { /usr/bin/say -r 180 "$1"; }
say_it()   { /usr/bin/say -r "$SAY_RATE" "$1"; }
pause()    { sleep "${1:-1}"; }

say_it "Claude Voice setup is starting. I will speak each step. Listen carefully."
pause 1

# ---------- Step 1: verify claude CLI ----------
say_it "Step one. Checking that the Claude Code command is installed."
if ! command -v claude >/dev/null 2>&1; then
	say_slow "The Claude command was not found on this computer. Please install Claude Code first, then run this setup again."
	echo "ERROR: 'claude' not on PATH. Install from https://claude.com/claude-code" >&2
	exit 1
fi
CLAUDE_BIN="$(command -v claude)"
CLAUDE_VER="$(claude --version 2>/dev/null | head -1)"
say_it "Claude is installed. Version detected."
echo "Found claude at: $CLAUDE_BIN"
echo "Version: $CLAUDE_VER"
pause 1

# ---------- Step 2: verify launcher app ----------
say_it "Step two. Checking the Claude Voice launcher app."
if [ ! -d "$APP_PATH" ]; then
	say_slow "The Claude Voice app was not found at Applications, Claude Voice dot app. The installation is incomplete."
	echo "ERROR: $APP_PATH does not exist." >&2
	exit 1
fi
say_it "Launcher app found."
pause 1

# ---------- Step 3: trigger Automation consent ----------
say_it "Step three. Asking macOS to grant automation permission. A dialog may appear. Please say yes or press allow."
pause 2

/usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Terminal"
	activate
	try
		count of windows
	end try
end tell
tell application "System Events"
	try
		get name of every process
	end try
end tell
APPLESCRIPT

pause 1
say_it "If you saw a permission dialog, please make sure you chose allow or OK."
pause 1

# ---------- Step 4: open System Settings panes ----------
say_it "Step four. I will now open System Settings to the Automation pane. Please look for Claude Voice, Terminal, and Script Editor in the list, and ensure System Events is enabled underneath each one."
pause 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" || open "x-apple.systempreferences:com.apple.preference.security?Privacy"
pause 4

say_it "Next, opening the Accessibility pane. Please ensure Terminal, Script Editor, and Claude Voice are enabled here."
pause 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || open "x-apple.systempreferences:com.apple.preference.security?Privacy"
pause 4

say_it "Next, opening the Voice Control pane. If you want to trigger Claude by saying start Claude voice, toggle Voice Control on here."
pause 2
open "x-apple.systempreferences:com.apple.preference.universalaccess?VoiceControl" || open "x-apple.systempreferences:com.apple.preference.universalaccess"
pause 4

say_it "Finally, opening Siri and Spotlight. If you want to trigger Claude by saying, hey Siri start Claude voice, ensure Listen for Hey Siri is enabled."
pause 2
open "x-apple.systempreferences:com.apple.preference.speech" || open "x-apple.systempreferences:com.apple.Siri-Settings.extension"
pause 3

# ---------- Step 5: install Voice Control command ----------
VC_INSTALLER="$SCRIPT_DIR/install-voice-control-command.sh"
if [ -x "$VC_INSTALLER" ]; then
	say_it "Step five. Installing the Voice Control command, start Claude voice."
	"$VC_INSTALLER" || say_slow "The Voice Control command installer reported an issue. You can still use Siri or double click the app."
else
	say_it "Skipping Voice Control installer because it was not found."
fi
pause 1

# ---------- Step 6: Siri shortcut guidance ----------
SIRI_INSTALLER="$SCRIPT_DIR/install-siri-shortcut.sh"
if [ -x "$SIRI_INSTALLER" ]; then
	say_it "Step six. Setting up Siri."
	"$SIRI_INSTALLER" || true
else
	say_it "Skipping Siri setup because the installer was not found. Note, you can always say, hey Siri, open Claude Voice. macOS supports that natively."
fi
pause 1

# ---------- Step 7: sentinel ----------
mkdir -p "$HOME/.claude"
date > "$SENTINEL"

say_it "Setup is complete. You can now say, hey Siri, start Claude voice. Or say, start Claude voice, if Voice Control is enabled. Or double click the Claude Voice icon on your desktop. Goodbye."
echo ""
echo "Setup complete. Sentinel written to: $SENTINEL"
