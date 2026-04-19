#!/bin/bash
# install-voice-control-command.sh
#
# Voice Control custom commands are not reliably installable via plist writes —
# Apple stores them in a private location that changes between macOS versions
# and the app refuses to load externally-written entries. This script instead
# opens the right Settings pane and NARRATES the steps, so a blind user can
# add the command himself hands-free.
#
# Wake phrase: "Start Claude voice"
# Action: run the app at ~/Applications/Claude Voice.app

set -u

APP_PATH="$HOME/Applications/Claude Voice.app"
say_it() { /usr/bin/say -r 200 "$1"; }

say_it "Installing the Voice Control command, start Claude voice."
sleep 1

# Open Voice Control Commands pane
say_it "Opening the Voice Control commands list now."
open "x-apple.systempreferences:com.apple.preference.universalaccess?VoiceControl" || \
	open "x-apple.systempreferences:com.apple.preference.universalaccess"
sleep 3

say_it "In the Voice Control window, click Commands, then the plus button to add a new command."
sleep 4
say_it "For the phrase, type, start Claude voice."
sleep 4
say_it "For while using, choose any application."
sleep 3
say_it "For perform, choose open finder item."
sleep 3
say_it "For the item to open, browse to your Applications folder, inside your home folder, and select Claude Voice dot app."
sleep 5
say_it "The full path is, slash Users slash your username slash Applications slash Claude Voice dot app."
sleep 4
say_it "Click done to save. The command is now active whenever Voice Control is listening."
sleep 2

if [ -d "$APP_PATH" ]; then
	say_it "The target app is present and ready."
	echo "Target app: $APP_PATH"
else
	say_it "Warning. The target app at Applications slash Claude Voice dot app was not found."
	echo "WARNING: $APP_PATH missing" >&2
fi

echo ""
echo "Voice Control setup: manual steps required (narrated above)."
echo "Phrase: 'Start Claude voice'"
echo "Action: Open Finder Item -> $APP_PATH"
