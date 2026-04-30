#!/bin/zsh
# start-claudette.command — ALWAYS start a fresh Claude Code voice session.
# Opens Terminal, kills old sessions, starts claude in tmux with voice mode.
#
# Environment:
#   CLAUDE_VOICE_PROJECT_DIR  Working directory for Claude (default: $HOME)
#   VOICEMODE_STT_BASE_URLS   STT endpoint (default: http://127.0.0.1:8901/v1)

export PATH="/opt/homebrew/bin:$HOME/bin:$PATH"
export VOICEMODE_STT_BASE_URLS="${VOICEMODE_STT_BASE_URLS:-http://127.0.0.1:8901/v1}"
export VOICEMODE_WHISPER_PORT="${VOICEMODE_WHISPER_PORT:-8901}"

PROJECT_DIR="${CLAUDE_VOICE_PROJECT_DIR:-$HOME}"

say "Starting Claudette." &

# --- Kill EVERYTHING from prior sessions ---
# Graceful shutdown: SIGTERM first, SIGKILL only after 3s timeout
# (Force-killing voice-mode leaves stale audio handles in coreaudiod, freezing the mic)
pkill -TERM -f "bin/voice-mode" 2>/dev/null
pkill -TERM -f "uvx voice-mode" 2>/dev/null
rm -f ~/.voicemode/conch

# Kill phone sessions
ps ax -o pid,command | grep "claude --print" | grep -v grep | awk '{print $1}' | xargs kill -TERM 2>/dev/null

# Kill old Terminal Claude processes
ps ax -o pid,command | grep "claude --dangerously" | grep -v grep | awk '{print $1}' | xargs kill -TERM 2>/dev/null

# Wait for graceful shutdown, then SIGKILL ONLY processes that survived SIGTERM
sleep 3
if pgrep -f "bin/voice-mode" >/dev/null 2>&1; then
    pkill -9 -f "bin/voice-mode" 2>/dev/null
fi
if pgrep -f "uvx voice-mode" >/dev/null 2>&1; then
    pkill -9 -f "uvx voice-mode" 2>/dev/null
fi
for pattern in "claude --print" "claude --dangerously"; do
    survivors=$(ps ax -o pid,command | grep "$pattern" | grep -v grep | awk '{print $1}')
    if [[ -n "$survivors" ]]; then
        echo "$survivors" | xargs kill -9 2>/dev/null
    fi
done

# Kill old tmux session
tmux kill-session -t claudette 2>/dev/null
sleep 1

# --- Restart coreaudiod if mic is likely frozen ---
if sudo -n killall coreaudiod 2>/dev/null; then
    sleep 2
    echo "Restarted coreaudiod (clears stale mic handles)"
fi

# --- Set up audio ---
# Prefer headset for output if connected; use USB mic for input if available.
# Device names: customize for your hardware.
if command -v SwitchAudioSource >/dev/null 2>&1; then
    if SwitchAudioSource -a -t output 2>/dev/null | grep -Fxq "DY106"; then
        SwitchAudioSource -s "DY106" -t output 2>/dev/null
        SwitchAudioSource -s "DY106" -t input 2>/dev/null
    fi
    if SwitchAudioSource -a -t input 2>/dev/null | grep -Fxq "K66"; then
        SwitchAudioSource -s "K66" -t input 2>/dev/null
    fi
fi

# Start heartbeat if available
HEARTBEAT="$PROJECT_DIR/Heartbeat.applescript"
[[ -f "$HEARTBEAT" ]] && osascript "$HEARTBEAT" &>/dev/null &

say "Voice mode is starting." &

# Run claude inside tmux — attach so this Terminal tab shows the session
tmux new-session -s claudette -c "$PROJECT_DIR" \
    "claude --dangerously-skip-permissions 'Start voice mode. Invoke /voicemode:converse right now.'"
