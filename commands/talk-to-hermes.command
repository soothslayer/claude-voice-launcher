#!/bin/zsh
# talk-to-hermes.command — pause Claudette voicemode, launch hermes-voice.
# Requires: hermes CLI on $PATH.

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"

say "Switching to Hermes." &

# Pause voicemode
if tmux has-session -t claudette 2>/dev/null; then
    tmux send-keys -t claudette Escape
else
    osascript <<'EOF'
tell application "Terminal"
    repeat with w in windows
        repeat with t in tabs of w
            if "claude" is in processes of t then
                do script (ASCII character 27) in t
                return
            end if
        end repeat
    end repeat
end tell
EOF
fi

sleep 1

if ! command -v hermes-voice >/dev/null 2>&1; then
    say "Hermes is not installed." &
    exit 1
fi

say "Hermes is starting." &
hermes-voice
