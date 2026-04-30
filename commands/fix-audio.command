#!/bin/bash
# fix-audio.command — fix frozen audio system by restarting coreaudiod.
# Also installs a passwordless sudo rule so this can be automated in the future.

echo "=== Fix Audio System ==="
echo ""

# Step 1: Install sudoers rule if not already present
if [[ ! -f /etc/sudoers.d/coreaudiod-restart ]]; then
    echo "Installing passwordless sudo rule for coreaudiod restart..."
    echo "This allows the voice watchdog to fix audio automatically in the future."
    CURRENT_USER="$(id -un)"
    sudo tee /etc/sudoers.d/coreaudiod-restart > /dev/null << EOF
$CURRENT_USER ALL=(root) NOPASSWD: /usr/bin/killall coreaudiod
EOF
    sudo chmod 0440 /etc/sudoers.d/coreaudiod-restart
    echo "Sudoers rule installed"
else
    echo "Sudoers rule already present"
fi

# Step 2: Restart coreaudiod
echo ""
echo "Restarting coreaudiod..."
sudo killall coreaudiod
sleep 3

# Step 3: Verify
if pgrep -x coreaudiod > /dev/null; then
    echo "coreaudiod restarted (new PID: $(pgrep -x coreaudiod))"
    if command -v SwitchAudioSource >/dev/null 2>&1; then
        # Reset to USB mic if available
        if SwitchAudioSource -a -t input 2>/dev/null | grep -Fxq "K66"; then
            SwitchAudioSource -s "K66" -t input 2>/dev/null
            echo "Input set to K66"
        fi
    fi
    say "Audio system fixed. Microphone should be working now."
else
    echo "coreaudiod didn't restart — try rebooting"
    say "Audio restart failed. You may need to reboot."
fi

echo ""
echo "Done. You can close this window."
