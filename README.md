# Claude Voice Launcher

Accessible one-command launcher that starts [Claude Code](https://docs.anthropic.com/claude/docs/claude-code) in voice mode on macOS — designed for blind and low-vision users.

Say **"Hey Siri, open Claude Voice"** (or double-click the app) and it:

1. Opens Terminal if it isn't already running.
2. Scans every existing Terminal window to see whether Claude Code is already at a prompt.
3. If Claude is ready → sends `/voicemode:converse` to that window.
4. If Claude is mid-response → speaks *"Claude is busy, waiting"* and waits up to 30 seconds.
5. Otherwise → opens a new Terminal, runs `claude --dangerously-skip-permissions`, waits for the prompt, then sends `/voicemode:converse`.
6. Narrates every step through macOS text-to-speech so a blind user knows exactly what's happening.

## Why this exists

Starting Claude Code normally requires sighted interaction: typing `claude` in Terminal, watching for the prompt to appear, then typing a slash command. For a blind user, each of those steps is a place where things can silently go wrong. This launcher removes all of them: one voice command → talking to Claude.

## Install

Prerequisites on the target Mac:

- **macOS 13 Ventura or newer**
- **Claude Code CLI** installed and on `PATH` — verify with `claude --version`. Install from <https://docs.anthropic.com/claude/docs/claude-code>.
- **VoiceMode skill** available to Claude Code (provides `/voicemode:converse`).

Clone and install:

```bash
git clone https://github.com/soothslayer/claude-voice-launcher.git
cd claude-voice-launcher
bash install.sh
```

The installer:

1. Copies source scripts into `~/bin/`.
2. Compiles `~/Applications/Claude Voice.app` via `osacompile`.
3. Sets a stable bundle identifier so macOS remembers granted permissions.
4. Creates a symlink at `~/Desktop/Claude Voice.app`.
5. **Pre-accepts Claude Code's "Do you trust the files in this folder?" dialog** for `$HOME` (the directory the launcher uses) by writing `hasTrustDialogAccepted: true` into `~/.claude.json` under `projects.$HOME`. Skips a guaranteed stall for a blind user. Run `python3 scripts/pre-trust-directory.py /path/to/dir` to pre-trust any other directory.
6. Launches the **interactive, voice-narrated permissions setup** which opens each required System Settings pane and tells you what to toggle.

## Change the directory Claude starts in

By default the launcher runs `claude` from `$HOME`. To start in a different directory, write the path to `~/.claude-voice-launcher-dir`:

```bash
echo "~/git/my-project" > ~/.claude-voice-launcher-dir
```

`~` and `$HOME` are expanded. If the file is missing, empty, or points to a directory that doesn't exist, the launcher falls back to `$HOME`. Remember to pre-trust the new directory so Claude doesn't stall on its trust prompt:

```bash
python3 scripts/pre-trust-directory.py ~/git/my-project
```

## How to trigger it

Three redundant triggers — use whichever works for you:

| Trigger | Phrase | Requires |
|---|---|---|
| Siri (zero setup) | "Hey Siri, open Claude Voice" | Hey Siri enabled |
| Siri (custom phrase) | "Hey Siri, start Claude voice" | A Shortcut named "Start Claude Voice" (installer walks you through creating it) |
| Voice Control (offline) | "Start Claude voice" | Voice Control enabled + custom command added (installer walks you through it) |
| Manual | Double-click the Desktop icon, or Spotlight → "Claude Voice" | nothing |

## Permissions the setup script pre-grants

| Permission | Where | Why |
|---|---|---|
| Automation → Claude Voice → System Events | Privacy & Security → Automation | Send keystrokes (`/voicemode:converse`) |
| Automation → Claude Voice → Terminal | Privacy & Security → Automation | Read Terminal window contents to detect Claude's state |
| Accessibility → Claude Voice | Privacy & Security → Accessibility | Fallback for keystroke injection on some macOS versions |

Claude Code's own tool-permission prompts are bypassed by running `claude --dangerously-skip-permissions`. Read the [Claude Code docs on that flag](https://docs.anthropic.com/claude/docs/claude-code) before using — it means Claude will run tools without asking first.

## How it detects Claude's state

The launcher reads `contents of tab 1 of window N` for every Terminal window and classifies each as:

- `claude-idle` — contents contain `? for shortcuts` **and** the input box glyph `│ >`.
- `claude-busy` — contains `esc to interrupt` or similar mid-response markers.
- `shell` — last non-empty line ends in `%`, `$`, or `#`.
- `unknown` — anything else.

If Claude Code's TUI changes and detection breaks, tune the marker lists at the top of [`claude-voice-launcher.applescript`](claude-voice-launcher.applescript) and re-run `install.sh`.

## Session management commands

The `commands/` directory contains scripts for managing Claude Code voice sessions. The installer copies them to `~/bin/`. Each is a `.command` file (double-clickable in Finder, or invocable via Siri app bundles).

| Command | What it does |
|---|---|
| `start-claudette.command` | Kill everything, start a fresh Claude Code voice session in tmux |
| `resume-claudette.command` | Re-enter voice mode in an existing session; starts fresh if session is dead |
| `wake-claudette.command` | Smart handler: detects if Claude is idle, thinking, or not running — asks before interrupting |
| `pause-claudette.command` | Send Escape to stop voice mode without killing the session |
| `end-claudette.command` | Fully stop Claude Code and close the tmux session |
| `back-to-claudette.command` | Kill Hermes voice, resume Claudette voice mode |
| `talk-to-hermes.command` | Pause Claudette, launch Hermes voice (requires `hermes-voice` on PATH) |
| `fix-audio.command` | Restart coreaudiod to fix frozen mics; installs a passwordless sudo rule |

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `CLAUDE_VOICE_PROJECT_DIR` | `$HOME` | Working directory for Claude Code sessions |
| `VOICEMODE_STT_BASE_URLS` | `http://127.0.0.1:8901/v1` | Speech-to-text endpoint |
| `VOICEMODE_WHISPER_PORT` | `8901` | STT port number |

### Creating Siri app bundles

To trigger any command via "Hey Siri, open [Name]":

```bash
osacompile -o ~/Applications/"Wake Claudette.app" -e 'do shell script "open ~/bin/wake-claudette.command"'
/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Wake Claudette'" ~/Applications/"Wake Claudette.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.$(id -un).wake-claudette" ~/Applications/"Wake Claudette.app/Contents/Info.plist"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/"Wake Claudette.app"
mdimport ~/Applications/"Wake Claudette.app"
```

Both `CFBundleName` and `CFBundleIdentifier` are required — without them, Siri won't find the app. The `lsregister` + `mdimport` steps register it with Launch Services and Spotlight.

### Audio device detection

The scripts auto-detect audio hardware via `SwitchAudioSource` (install with `brew install switchaudio-osx`). Currently configured for:

- **DY106** — Bluetooth headset (output, fallback input)
- **K66** — USB microphone (preferred input)

If your devices have different names, the scripts gracefully skip — no errors, just no switching.

## Files

| File | Purpose |
|---|---|
| [`claude-voice-launcher.applescript`](claude-voice-launcher.applescript) | The brain — window classification, keystroke injection, narration |
| [`claude-voice-setup.command`](claude-voice-setup.command) | One-time narrated permissions primer (double-clickable) |
| [`commands/`](commands/) | Session management scripts (start, resume, wake, pause, end, switch) |
| [`install-voice-control-command.sh`](install-voice-control-command.sh) | Narrated guide for adding the Voice Control custom command |
| [`install-siri-shortcut.sh`](install-siri-shortcut.sh) | Narrated guide for creating the Siri Shortcut |
| [`install.sh`](install.sh) | One-shot installer that wires everything up |

## Troubleshooting

**"Nothing happens when I double-click the app."**
Strip the quarantine attribute: `xattr -dr com.apple.quarantine ~/Applications/Claude\ Voice.app`

**"Claude Voice says 'Error, could not send voice command'."**
Automation permission not granted. Open `System Settings → Privacy & Security → Automation` and enable System Events + Terminal under "Claude Voice".

**"Claude starts but `/voicemode:converse` isn't entered."**
VoiceMode isn't installed in Claude Code. Run `/plugin install voicemode` (or the current equivalent) inside Claude Code.

**"Terminal opens but Claude never reaches the prompt."**
Launch Claude manually once first (`claude --dangerously-skip-permissions`), dismiss any trust-directory or API-key prompts, quit, then re-test.

**"It picked the wrong Terminal window."**
Detection markers may have drifted. Edit `claudeFooterMarkers` / `claudeBusyMarkers` at the top of [`claude-voice-launcher.applescript`](claude-voice-launcher.applescript) and re-run `install.sh`.

## Uninstall

```bash
rm -rf ~/Applications/Claude\ Voice.app
rm -f  ~/Desktop/Claude\ Voice.app
rm -f  ~/bin/claude-voice-launcher.applescript \
       ~/bin/claude-voice-setup.command \
       ~/bin/install-voice-control-command.sh \
       ~/bin/install-siri-shortcut.sh
rm -f  ~/.claude/.voice-launcher-setup-complete
```

Then in Shortcuts.app delete "Start Claude Voice" (if created), and in Voice Control settings remove the "Start Claude voice" command (if created).

## License

MIT — see [LICENSE](LICENSE).

## Contributing

PRs welcome, especially for:
- Additional shell / terminal-emulator support (iTerm2, Warp, Ghostty, Kitty, Alacritty).
- Localization of the spoken narration.
- Alternative voice-trigger mechanisms.
