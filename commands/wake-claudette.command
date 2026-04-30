#!/bin/zsh
# wake-claudette.command — smart session handler for blind voice-first use.
#
# States:
#   1. Phone session (claude --print) → announce and exit
#   2. Not running → start fresh
#   3. Running + thinking (CPU > 3%) → ask user: wait or start new
#      - Press 1 to wait
#      - Press 2 to start fresh
#      - Timeout (30s) defaults to waiting
#   4. Running + idle → start voice mode in existing session

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"
export VOICEMODE_STT_BASE_URLS="${VOICEMODE_STT_BASE_URLS:-http://127.0.0.1:8901/v1}"
export VOICEMODE_WHISPER_PORT="${VOICEMODE_WHISPER_PORT:-8901}"

PROJECT_DIR="${CLAUDE_VOICE_PROJECT_DIR:-$HOME}"

# --- Check for phone session first ---
PHONE_PIDS=$(ps ax -o pid,command | grep "claude --print" | grep -v grep | awk '{print $1}')
if [ -n "$PHONE_PIDS" ]; then
    say "Claudette is running on your phone." &
    sleep 3
    exit 0
fi

# --- Check for running Claude process ---
CLAUDE_PID=$(ps ax -o pid,command | grep "claude --dangerously" | grep -v grep | awk '{print $1}' | head -1)

if [ -z "$CLAUDE_PID" ]; then
    say "Starting Claudette."
    exec open ~/bin/start-claudette.command
fi

# --- Claude is running — check if thinking ---
CPU_RAW=$(ps -p "$CLAUDE_PID" -o %cpu= 2>/dev/null | tr -d ' ')
CPU=${CPU_RAW%.*}
CPU=${CPU:-0}

if [ "$CPU" -gt 3 ]; then
    say "Claudette is in the middle of something. Press 1 to wait for her, or 2 to start a new session."

    if read -k 1 -t 30 choice 2>/dev/null; then
        if [ "$choice" = "2" ]; then
            say "Starting a new session." &
            exec open ~/bin/start-claudette.command
        fi
    fi

    say "Waiting for Claudette to finish."
    WAIT_COUNT=0
    while [ "$WAIT_COUNT" -lt 150 ]; do
        CPU_RAW=$(ps -p "$CLAUDE_PID" -o %cpu= 2>/dev/null | tr -d ' ')
        CPU=${CPU_RAW%.*}
        CPU=${CPU:-0}
        if [ "$CPU" -le 3 ] || ! kill -0 "$CLAUDE_PID" 2>/dev/null; then
            break
        fi
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    if ! kill -0 "$CLAUDE_PID" 2>/dev/null; then
        say "Claudette stopped. Starting fresh."
        exec open ~/bin/start-claudette.command
    fi

    say "Claudette is ready."
fi

# --- Claude is idle — clean up voicemode and start it ---
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

# Restart coreaudiod if possible
if sudo -n killall coreaudiod 2>/dev/null; then
    sleep 2
fi

# Set up audio
if command -v SwitchAudioSource >/dev/null 2>&1; then
    if SwitchAudioSource -a -t output 2>/dev/null | grep -Fxq "DY106"; then
        SwitchAudioSource -s "DY106" -t output 2>/dev/null
    fi
    if SwitchAudioSource -a -t input 2>/dev/null | grep -Fxq "K66"; then
        SwitchAudioSource -s "K66" -t input 2>/dev/null
    fi
fi

# Send voicemode command to tmux session
if tmux has-session -t claudette 2>/dev/null; then
    tmux send-keys -t claudette Escape
    sleep 1
    tmux send-keys -t claudette "/voicemode:converse" Enter
    sleep 5
    if ps ax | grep -q "[b]in/voice-mode\|[u]vx voice-mode"; then
        osascript -e 'tell application "Terminal" to activate'
        say "Voice mode is active." &
        HEARTBEAT="$PROJECT_DIR/Heartbeat.applescript"
        [[ -f "$HEARTBEAT" ]] && osascript "$HEARTBEAT" &>/dev/null &
        exit 0
    else
        say "Voice mode failed. Starting a new session." &
        exec open ~/bin/start-claudette.command
    fi
else
    say "Starting a new session." &
    exec open ~/bin/start-claudette.command
fi
