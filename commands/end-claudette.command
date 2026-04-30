#!/bin/zsh
# end-claudette.command — stop Claude Code and close the session.

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"

say "Closing voice mode" &

if tmux has-session -t claudette 2>/dev/null; then
    tmux send-keys -t claudette Escape
    sleep 0.5
    tmux send-keys -t claudette C-c
    sleep 0.5
    tmux send-keys -t claudette C-c
    sleep 1
    tmux kill-session -t claudette 2>/dev/null
else
    pkill -f 'claude --dangerously-skip-permissions' 2>/dev/null
    osascript -e 'tell application "Terminal" to try' -e 'close front window saving no' -e 'end try' 2>/dev/null
fi

say "Goodbye" &
exit 0
