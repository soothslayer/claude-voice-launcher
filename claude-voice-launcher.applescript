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
	-- Returns {winID: N, state: "..."} for the best matching window, where
	-- winID is the STABLE Terminal window id (not the positional index — the
	-- index shifts as soon as we reorder windows, making later references
	-- point to the wrong window).
	-- Preference order: claude-idle > claude-busy > shell > nothing.
	set bestIdle to missing value
	set bestBusy to missing value
	set bestShell to missing value
	tell application "Terminal"
		try
			set winCount to count of windows
		on error
			set winCount to 0
		end try
		repeat with i from 1 to winCount
			try
				set w to window i
				set wID to id of w
				set winContents to contents of tab 1 of w
				set state to my classifyWindowContents(winContents)
				if state is "claude-idle" and bestIdle is missing value then set bestIdle to wID
				if state is "claude-busy" and bestBusy is missing value then set bestBusy to wID
				if state is "shell" and bestShell is missing value then set bestShell to wID
			end try
		end repeat
	end tell
	if bestIdle is not missing value then return {winID:bestIdle, state:"claude-idle"}
	if bestBusy is not missing value then return {winID:bestBusy, state:"claude-busy"}
	if bestShell is not missing value then return {winID:bestShell, state:"shell"}
	return {winID:missing value, state:"none"}
end findClaudeWindow

on activateTerminalWindow(wID)
	-- Bring the window with the given id to the absolute front and ensure
	-- Terminal is the frontmost application. Uses window id (stable) rather
	-- than window index (shifts as windows reorder).
	tell application "Terminal"
		activate
		try
			-- Unminimize if needed, so activation actually reveals the window.
			if miniaturized of window id wID then
				set miniaturized of window id wID to false
			end if
		end try
		-- Raise to top of window stack
		set index of window id wID to 1
		-- Mark as key window
		set frontmost of window id wID to true
	end tell
	delay 0.5
	-- Double-confirm at the process level: System Events is what actually
	-- routes keystrokes, so Terminal's process must be frontmost here too.
	try
		tell application "System Events"
			tell process "Terminal" to set frontmost to true
		end tell
	end try
	delay 0.3
end activateTerminalWindow

on waitForClaudeIdleByID(wID, timeoutSec)
	-- Like waitForClaudeIdle but uses window id.
	set elapsed to 0
	repeat while elapsed < timeoutSec
		try
			tell application "Terminal" to set c to contents of tab 1 of window id wID
			if my classifyWindowContents(c) is "claude-idle" then return true
		end try
		delay pollIntervalSec
		set elapsed to elapsed + pollIntervalSec
	end repeat
	return false
end waitForClaudeIdleByID

on sendKeystrokes(txt)
	tell application "System Events"
		keystroke txt
		delay 0.15
		key code 36 -- return
	end tell
end sendKeystrokes

on openNewTerminalAndStartClaude(claudeBin)
	-- Opens a new window, starts Claude, returns the STABLE window id
	-- (not the positional index) so callers can refer to it reliably even
	-- as other windows open/close/reorder.
	tell application "Terminal"
		activate
		set newTab to do script "cd ~ && clear && " & (quoted form of claudeBin) & " " & claudeArgs
		delay 0.3
		-- `do script` returns a tab; its containing window is the one we just created.
		try
			set newWinID to id of (first window whose tabs contains newTab)
		on error
			-- Fallback: whichever window is frontmost right now.
			set newWinID to id of front window
		end try
	end tell
	return newWinID
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
	set wID to winID of found
	set state to state of found

	if state is "claude-idle" then
		my speak("Claude is ready. Bringing the window to the front and entering voice mode.")
		try
			my activateTerminalWindow(wID)
			my sendKeystrokes(voiceCmd)
			my speak("Voice mode starting.")
		on error errMsg
			my speakError("Could not send the voice command. " & errMsg & ". Open System Settings, Privacy and Security, Automation, and allow this app to control System Events and Terminal.")
		end try
		return
	end if

	if state is "claude-busy" then
		my speak("Claude is busy. Waiting up to " & busyTimeoutSec & " seconds.")
		if my waitForClaudeIdleByID(wID, busyTimeoutSec) then
			try
				my activateTerminalWindow(wID)
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
		set newID to my openNewTerminalAndStartClaude(claudeBin)
	on error errMsg
		my speakError("Could not start Claude. " & errMsg)
		return
	end try

	my speak("Waiting for Claude to be ready.")
	if my waitForClaudeIdleByID(newID, startupTimeoutSec) then
		try
			my activateTerminalWindow(newID)
			my sendKeystrokes(voiceCmd)
			my speak("Voice mode starting.")
		on error errMsg
			my speakError("Could not send the voice command. " & errMsg & ". Open System Settings, Privacy and Security, Automation, and allow this app to control System Events and Terminal.")
		end try
	else
		my speakError("Claude did not reach its prompt within " & startupTimeoutSec & " seconds. Check the Terminal window.")
	end if
end run
