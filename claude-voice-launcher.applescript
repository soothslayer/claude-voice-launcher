-- Claude Voice Launcher
-- Finds a Terminal window whose title contains "Claude Code" and activates it,
-- or opens a new Terminal window if none exists. Then sends "/voicemode:converse".

property claudeArgs : "--dangerously-skip-permissions"
property voiceCmd : "/voicemode:converse"
property titleMarker : "Claude Code"
property sayRate : 220
property startDirConfig : "$HOME/.claude-voice-launcher-dir"

on findStartDir()
	-- Reads the startup directory from startDirConfig (one path per file, ~ allowed).
	-- Falls back to $HOME if the file is missing, empty, or points to a missing dir.
	try
		set dir to do shell script "f=" & startDirConfig & "; if [ -r \"$f\" ]; then raw=$(head -n 1 \"$f\" | tr -d '\\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); eval expanded=\"$raw\"; if [ -n \"$expanded\" ] && [ -d \"$expanded\" ]; then printf %s \"$expanded\"; exit; fi; fi; printf %s \"$HOME\""
		return dir
	on error
		return (do shell script "echo $HOME")
	end try
end findStartDir

on speak(msg)
	try
		do shell script "say -r " & sayRate & " " & quoted form of msg
	end try
end speak

on speakError(msg)
	try
		do shell script "say -r 180 " & quoted form of ("Error. " & msg)
	end try
end speakError

on findClaudeBin()
	try
		set pathPrefix to "export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; "
		return do shell script pathPrefix & "command -v claude"
	on error
		return "claude"
	end try
end findClaudeBin

on findClaudeWindow()
	-- Returns the id of the first Terminal window whose title contains titleMarker,
	-- or missing value if none found.
	tell application "Terminal"
		try
			set winCount to count of windows
		on error
			set winCount to 0
		end try
		repeat with i from 1 to winCount
			try
				set w to window i
				set wName to name of w
				if wName contains titleMarker then return id of w
			end try
		end repeat
	end tell
	return missing value
end findClaudeWindow

on activateTerminalWindow(wID)
	tell application "Terminal"
		activate
		try
			if miniaturized of window id wID then
				set miniaturized of window id wID to false
			end if
		end try
		try
			set index of window id wID to 1
		end try
		try
			set frontmost of window id wID to true
		end try
	end tell
	delay 0.5
	try
		tell application "System Events"
			tell process "Terminal" to set frontmost to true
		end tell
	end try
	delay 0.4
end activateTerminalWindow

on sendKeystrokes(txt)
	set priorClip to missing value
	try
		set priorClip to the clipboard
	end try
	
	try
		tell application "System Events"
			if not (frontmost of process "Terminal") then
				tell application "Terminal" to activate
				delay 0.4
				tell process "Terminal" to set frontmost to true
				delay 0.3
			end if
		end tell
	end try
	
	set the clipboard to txt
	delay 0.2
	
	set pasteOK to false
	try
		tell application "System Events"
			tell process "Terminal"
				keystroke "v" using command down
				delay 0.25
				key code 36
			end tell
		end tell
		set pasteOK to true
	end try
	
	if not pasteOK then
		try
			tell application "System Events"
				tell process "Terminal"
					keystroke txt
					delay 0.15
					key code 36
				end tell
			end tell
		end try
	end if
	
	delay 0.5
	if priorClip is not missing value then
		try
			set the clipboard to priorClip
		end try
	end if
end sendKeystrokes

on openNewTerminalAndStartClaude(claudeBin, reuseFrontWindow)
	-- If reuseFrontWindow is true, run the command in the existing front window
	-- (avoids opening a second window when Terminal just launched with an empty one).
	set startDir to my findStartDir()
	set cmd to "cd " & quoted form of startDir & " && clear && " & (quoted form of claudeBin) & " " & claudeArgs & " " & quoted form of voiceCmd
	tell application "Terminal"
		activate
		if reuseFrontWindow then
			try
				set newTab to do script cmd in front window
			on error
				set newTab to do script cmd
			end try
		else
			set newTab to do script cmd
		end if
		delay 0.3
		try
			set newWinID to id of (first window whose tabs contains newTab)
		on error
			set newWinID to id of front window
		end try
	end tell
	return newWinID
end openNewTerminalAndStartClaude

on run
	my speak("Starting Claude voice mode.")
	
	set terminalWasRunning to true
	try
		if application "Terminal" is not running then
			set terminalWasRunning to false
		else
			tell application "Terminal" to activate
			delay 0.3
		end if
	on error errMsg
		my speakError("Could not reach Terminal. " & errMsg)
		return
	end try
	
	if terminalWasRunning then
		set wID to my findClaudeWindow()
	else
		set wID to missing value
	end if
	
	if wID is missing value then
		my speak("No Claude Code window found. Opening a new one.")
		set claudeBin to my findClaudeBin()
		if claudeBin is "claude" or claudeBin is "" then
			my speakError("I could not find the Claude command on this computer.")
			return
		end if
		try
			set wID to my openNewTerminalAndStartClaude(claudeBin, false)
		on error errMsg
			my speakError("Could not start Claude. " & errMsg)
			return
		end try
		try
			my activateTerminalWindow(wID)
			my speak("Voice mode starting.")
		on error errMsg
			my speakError("Could not focus the Claude window. " & errMsg)
		end try
	else
		my speak("Found Claude Code window. Bringing it to the front.")
		try
			my activateTerminalWindow(wID)
			my sendKeystrokes(voiceCmd)
			my speak("Voice mode starting.")
		on error errMsg
			my speakError("Could not send the voice command. " & errMsg)
		end try
	end if
end run
