-- Claude Voice Launcher
-- Accessible AppleScript that starts Claude Code in voice-mode for a blind user.
-- Strategy:
--   1. Find any Terminal window already running Claude Code at an idle prompt.
--   2. If none, find a Terminal window running Claude but busy, and wait.
--   3. Otherwise, open a new Terminal window and start Claude Code fresh.
--   4. Once at the prompt, send "/voicemode:converse".
-- Every step is spoken aloud via `say`.

-- ---------- Config ----------
property claudeArgs : "--dangerously-skip-permissions"
property voiceCmd : "/voicemode:converse"
property sayRate : 220
property busyTimeoutSec : 30
property startupTimeoutSec : 25
property pollIntervalSec : 0.5

-- Claude TUI markers. These strings are what distinguish a Claude Code TUI
-- from a plain shell prompt.
property claudeFooterMarkers : {"? for shortcuts", "? shortcuts", "claude.ai/code"}
property claudeBusyMarkers : {"esc to interrupt", "Press esc", "(esc)"}
property claudeInputBoxMarker : "│ >"

-- ---------- Helpers ----------

on findClaudeBin()
	-- Resolve the `claude` binary at runtime so the launcher works on any
	-- Mac regardless of install location (Homebrew, ~/.local/bin, asdf, etc.).
	try
		-- Ensure PATH includes common locations that aren't inherited by
		-- GUI-launched processes.
		set pathPrefix to "export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; "
		return do shell script pathPrefix & "command -v claude"
	on error
		return "claude"
	end try
end findClaudeBin

on speak(msg)
	try
		do shell script "say -r " & sayRate & " " & quoted form of msg
	end try
end speak

on speakError(msg)
	-- Errors get spoken slower so he doesn't miss them.
	try
		do shell script "say -r 180 " & quoted form of ("Error. " & msg)
	end try
end speakError

on stringContains(haystack, needle)
	if haystack is missing value then return false
	if needle is "" then return false
	return haystack contains needle
end stringContains

on anyMarkerIn(haystack, markerList)
	repeat with m in markerList
		if stringContains(haystack, m as text) then return true
	end repeat
	return false
end anyMarkerIn

on classifyWindowContents(contentsText)
	-- Returns one of: "claude-idle", "claude-busy", "shell", "unknown"
	if contentsText is missing value then return "unknown"
	set hasFooter to anyMarkerIn(contentsText, claudeFooterMarkers)
	set hasBusy to anyMarkerIn(contentsText, claudeBusyMarkers)
	if hasBusy then return "claude-busy"
	if hasFooter then
		if stringContains(contentsText, claudeInputBoxMarker) then
			return "claude-idle"
		else
			-- Footer but no input box — probably still drawing. Treat as busy.
			return "claude-busy"
		end if
	end if
	-- Heuristic shell prompt detection: last non-empty line ends with % $ or #
	try
		set trimmed to do shell script "printf %s " & quoted form of contentsText & " | awk 'NF{last=$0} END{print last}'"
		if trimmed ends with "% " or trimmed ends with "$ " or trimmed ends with "# " or trimmed ends with "%" or trimmed ends with "$" or trimmed ends with "#" then
			return "shell"
		end if
	end try
	return "unknown"
end classifyWindowContents

on findClaudeWindow()
	-- Returns a record {winIndex: N, state: "..."} for the best matching window,
	-- or {winIndex: 0, state: "none"} if nothing useful found.
	-- Preference order: claude-idle > claude-busy > shell > nothing.
	set bestIdle to 0
	set bestBusy to 0
	set bestShell to 0
	tell application "Terminal"
		try
			set winCount to count of windows
		on error
			set winCount to 0
		end try
		repeat with i from 1 to winCount
			try
				set winContents to contents of tab 1 of window i
				set state to my classifyWindowContents(winContents)
				if state is "claude-idle" and bestIdle is 0 then set bestIdle to i
				if state is "claude-busy" and bestBusy is 0 then set bestBusy to i
				if state is "shell" and bestShell is 0 then set bestShell to i
			end try
		end repeat
	end tell
	if bestIdle > 0 then return {winIndex:bestIdle, state:"claude-idle"}
	if bestBusy > 0 then return {winIndex:bestBusy, state:"claude-busy"}
	if bestShell > 0 then return {winIndex:bestShell, state:"shell"}
	return {winIndex:0, state:"none"}
end findClaudeWindow

on activateTerminalWindow(winIndex)
	tell application "Terminal"
		activate
		try
			set index of window winIndex to 1
		end try
		try
			set frontmost of window winIndex to true
		end try
	end tell
	delay 0.4
end activateTerminalWindow

on sendKeystrokes(txt)
	tell application "System Events"
		keystroke txt
		delay 0.15
		key code 36 -- return
	end tell
end sendKeystrokes

on waitForClaudeIdle(winIndex, timeoutSec)
	-- Polls the given window until it reaches claude-idle or timeout.
	set elapsed to 0
	repeat while elapsed < timeoutSec
		try
			tell application "Terminal" to set c to contents of tab 1 of window winIndex
			if my classifyWindowContents(c) is "claude-idle" then return true
		end try
		delay pollIntervalSec
		set elapsed to elapsed + pollIntervalSec
	end repeat
	return false
end waitForClaudeIdle

on openNewTerminalAndStartClaude(claudeBin)
	-- Opens a new window, starts Claude, returns the window index.
	tell application "Terminal"
		activate
		do script "cd ~ && clear && " & (quoted form of claudeBin) & " " & claudeArgs
		delay 0.3
	end tell
	return 1
end openNewTerminalAndStartClaude

-- ---------- Main ----------

on run
	my speak("Starting Claude voice mode.")

	-- Resolve claude binary
	set claudeBin to my findClaudeBin()
	if claudeBin is "claude" or claudeBin is "" then
		my speakError("I could not find the Claude command on this computer. Please install Claude Code, then try again.")
		return
	end if

	-- Ensure Terminal is running.
	try
		if application "Terminal" is not running then
			my speak("Opening Terminal.")
			tell application "Terminal" to activate
			delay 1.5
		else
			tell application "Terminal" to activate
			delay 0.3
		end if
	on error errMsg
		my speakError("Could not open Terminal. " & errMsg)
		return
	end try

	-- Find the best existing window.
	set found to my findClaudeWindow()
	set winIdx to winIndex of found
	set state to state of found

	if state is "claude-idle" then
		my speak("Claude is ready in window " & winIdx & ". Entering voice mode.")
		try
			my activateTerminalWindow(winIdx)
			my sendKeystrokes(voiceCmd)
			my speak("Voice mode starting.")
		on error errMsg
			my speakError("Could not send the voice command. " & errMsg & ". Open System Settings, Privacy and Security, Automation, and allow this app to control System Events and Terminal.")
		end try
		return
	end if

	if state is "claude-busy" then
		my speak("Claude is busy in window " & winIdx & ". Waiting up to " & busyTimeoutSec & " seconds.")
		if my waitForClaudeIdle(winIdx, busyTimeoutSec) then
			try
				my activateTerminalWindow(winIdx)
				my sendKeystrokes(voiceCmd)
				my speak("Voice mode starting.")
				return
			on error errMsg
				my speakError("Could not send the voice command. " & errMsg)
				return
			end try
		else
			my speak("Claude is still busy. Opening a new window instead.")
			-- Fall through to the fresh-start branch.
		end if
	end if

	-- No idle Claude (or it stayed busy): open a new window and start fresh.
	my speak("Opening a new Terminal window and starting Claude Code.")
	try
		set newIdx to my openNewTerminalAndStartClaude(claudeBin)
	on error errMsg
		my speakError("Could not start Claude. " & errMsg)
		return
	end try

	my speak("Waiting for Claude to be ready.")
	if my waitForClaudeIdle(newIdx, startupTimeoutSec) then
		try
			my activateTerminalWindow(newIdx)
			my sendKeystrokes(voiceCmd)
			my speak("Voice mode starting.")
		on error errMsg
			my speakError("Could not send the voice command. " & errMsg & ". Open System Settings, Privacy and Security, Automation, and allow this app to control System Events and Terminal.")
		end try
	else
		my speakError("Claude did not reach its prompt within " & startupTimeoutSec & " seconds. Check the Terminal window.")
	end if
end run
