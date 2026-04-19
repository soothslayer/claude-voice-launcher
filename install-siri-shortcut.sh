#!/bin/bash
# install-siri-shortcut.sh
#
# Creates a Siri-triggerable Shortcut named "Start Claude Voice" that
# launches the Claude Voice app.
#
# Note: The `.shortcut` file format is a signed Apple bundle that can't be
# reliably generated outside of Shortcuts.app. This script therefore
# OPENS Shortcuts.app and narrates exactly what to click so a blind user
# can build the shortcut hands-free with VoiceOver.
#
# SIMPLER FALLBACK: macOS Siri natively supports "Hey Siri, open
# <AppName>". So "Hey Siri, open Claude Voice" will launch the app with
# no Shortcut needed. This installer is only required if the user wants
# a custom phrase like "Start Claude Voice".

set -u

say_it() { /usr/bin/say -r 200 "$1"; }

say_it "Setting up Siri trigger for Claude Voice."
sleep 1

say_it "Good news. macOS Siri can already launch apps by name. Try saying, hey Siri, open Claude Voice. That works without any setup."
sleep 5

say_it "If you want the phrase, hey Siri, start Claude voice, I will now open Shortcuts so you can create a Shortcut with that name."
sleep 4

open -a "Shortcuts"
sleep 2

say_it "In Shortcuts, press command N to create a new Shortcut."
sleep 3
say_it "Name the Shortcut, Start Claude Voice. That name becomes the Siri phrase."
sleep 4
say_it "Search for the action called, Run AppleScript, and add it."
sleep 4
say_it "Paste this AppleScript into the action."
sleep 2
say_it "tell application Claude Voice to launch."
sleep 3
say_it "Save the Shortcut with command S. You can now say, hey Siri, start Claude voice."

cat <<'EOF'

=== Manual Shortcut Setup ===
1. Open Shortcuts.app (just opened)
2. Cmd+N for new shortcut
3. Name it exactly: Start Claude Voice
4. Add action: "Run AppleScript"
5. Paste this AppleScript body:

   on run {input, parameters}
       tell application "Claude Voice" to launch
       return input
   end run

6. Cmd+S to save
7. Siri phrase is now: "Hey Siri, start Claude voice"

Alternative (zero setup): just say "Hey Siri, open Claude Voice"
EOF
