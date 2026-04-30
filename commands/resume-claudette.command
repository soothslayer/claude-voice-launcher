#!/bin/zsh
# resume-claudette.command — re-enter voice mode in an existing session.
# If the session is dead, starts fresh automatically.
#
# Session detection (uses ps instead of pgrep — macOS pgrep skips ancestor processes):
#   1. tmux "claudette" session → try sending voicemode command, verify it works
#   2. claude --print (phone) session running → announce and exit
#   3. Nothing → start fresh

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"
export VOICEMODE_STT_BASE_URLS="${VOICEMODE_STT_BASE_URLS:-http://127.0.0.1:8901/v1}"
export VOICEMODE_WHISPER_PORT="${VOICEMODE_WHISPER_PORT:-8901}"

PROJECT_DIR="${CLAUDE_VOICE_PROJECT_DIR:-$HOME}"

# --- Always clean up voicemode contention ---
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

# --- Restart coreaudiod to clear stale mic handles ---
if sudo -n killall coreaudiod 2>/dev/null; then
    sleep 2
fi

# --- Set up audio ---
if command -v SwitchAudioSource >/dev/null 2>&1; then
    if SwitchAudioSource -a -t output 2>/dev/null | grep -Fxq "DY106"; then
        SwitchAudioSource -s "DY106" -t output 2>/dev/null
    fi
    if SwitchAudioSource -a -t input 2>/dev/null | grep -Fxq "K66"; then
        SwitchAudioSource -s "K66" -t input 2>/dev/null
    fi
fi

# --- Check for phone (claude --print) session ---
PHONE_PIDS=$(ps ax -o pid,command | grep "claude --print" | grep -v grep | awk '{print $1}')
if [ -n "$PHONE_PIDS" ]; then
    say "Claudette is running on your phone. Use your phone, or say Talk to Claudette to switch to Terminal." &
    sleep 5
    exit 0
fi

# --- Check for existing tmux session ---
if tmux has-session -t claudette 2>/dev/null; then
    say "Restarting voice mode." &
    tmux send-keys -t claudette Escape
    sleep 3
    tmux send-keys -t claudette "/voicemode:converse" Enter
    sleep 5
    if ps ax | grep -q "[b]in/voice-mode\|[u]vx voice-mode"; then
        tmux list-clients -t claudette -F '#{client_tty}' | tail -n +2 | while read tty; do
            tmux detach-client -t "$tty" 2>/dev/null
        done
        osascript -e 'tell application "Terminal" to activate'
        sleep 1
        exit 0
    else
        say "Session is stale. Starting fresh." &
        ps ax -o pid,command | grep "claude --dangerously" | grep -v grep | awk '{print $1}' | xargs kill -TERM 2>/dev/null
        sleep 3
        ps ax -o pid,command | grep "claude --dangerously" | grep -v grep | awk '{print $1}' | xargs kill -9 2>/dev/null
        tmux kill-session -t claudette 2>/dev/null
        sleep 1
    fi
fi

# --- Start fresh ---
say "Starting Claudette fresh." &
HEARTBEAT="$PROJECT_DIR/Heartbeat.applescript"
[[ -f "$HEARTBEAT" ]] && osascript "$HEARTBEAT" &>/dev/null &

say "Voice mode is starting." &
tmux new-session -s claudette -c "$PROJECT_DIR" \
    "claude --dangerously-skip-permissions 'Start voice mode. Invoke /voicemode:converse right now.'"
