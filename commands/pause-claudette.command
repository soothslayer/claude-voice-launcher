#!/bin/zsh
# pause-claudette.command — send Escape to stop voicemode without killing the session.

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"

say "Pausing Claudette" &

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

say "Paused" &
exit 0
