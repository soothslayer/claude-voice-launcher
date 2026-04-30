#!/bin/zsh
# back-to-claudette.command — kill hermes-voice, resume voicemode in existing session.

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"

say "Switching back to Claudette." &

# Kill hermes processes
pkill -f 'hermes_voice.py' 2>/dev/null
pkill -f 'hermes-voice' 2>/dev/null
sleep 0.5

# Clean up voicemode contention
pkill -TERM -f "bin/voice-mode" 2>/dev/null
pkill -TERM -f "uvx voice-mode" 2>/dev/null
rm -f ~/.voicemode/conch
sleep 3
if pgrep -f "bin/voice-mode" >/dev/null 2>&1; then
    pkill -9 -f "bin/voice-mode" 2>/dev/null
fi
if pgrep -f "uvx voice-mode" >/dev/null 2>&1; then
    pkill -9 -f "uvx voice-mode" 2>/dev/null
fi

# Resume voicemode — prefer tmux, then check Terminal tabs
if tmux has-session -t claudette 2>/dev/null; then
    tmux send-keys -t claudette "/voicemode:converse" Enter
    say "Claudette should be back." &
elif pgrep -f "claude --print" >/dev/null 2>&1; then
    say "Claudette is on your phone. Use your phone to talk to her." &
else
    osascript <<'EOF'
tell application "Terminal"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            if "claude" is in processes of t then
                do script "/voicemode:converse" in t
                return
            end if
        end repeat
    end repeat
end tell
EOF
    say "Claudette should be back." &
fi
exit 0
