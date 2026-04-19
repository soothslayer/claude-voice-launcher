#!/usr/bin/env python3
"""
pre-trust-directory.py
Pre-accept Claude Code's "Do you trust the files in this folder?" dialog
for a given directory by writing to ~/.claude.json.

Why: the voice launcher runs `cd ~ && claude --dangerously-skip-permissions`
and would otherwise stall on the trust prompt. For a blind user, any
interactive prompt is a failure mode — so we pre-populate the trust state.

Usage:
    python3 pre-trust-directory.py [DIR ...]

With no args, pre-trusts $HOME (the directory the launcher always uses).

Safe to run multiple times; idempotent. Creates a timestamped backup of
~/.claude.json on first run.
"""
import json
import os
import shutil
import sys
from datetime import datetime

CONFIG = os.path.expanduser("~/.claude.json")


def pre_trust(dirs):
    if not os.path.exists(CONFIG):
        print(f"NOTE: {CONFIG} does not exist yet — will be created on first `claude` run.", file=sys.stderr)
        print("Launch `claude` once first, accept the trust prompt manually, then re-run this.", file=sys.stderr)
        return 1

    # Backup once per invocation
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = f"{CONFIG}.bak-{ts}"
    shutil.copy2(CONFIG, backup)

    with open(CONFIG) as f:
        data = json.load(f)

    projects = data.setdefault("projects", {})
    changed = []
    for d in dirs:
        abs_d = os.path.abspath(os.path.expanduser(d))
        entry = projects.setdefault(abs_d, {
            "allowedTools": [],
            "mcpContextUris": [],
            "enabledMcpjsonServers": [],
            "disabledMcpjsonServers": [],
            "hasTrustDialogAccepted": False,
            "projectOnboardingSeenCount": 0,
            "hasClaudeMdExternalIncludesApproved": False,
            "hasClaudeMdExternalIncludesWarningShown": False,
        })
        before = entry.get("hasTrustDialogAccepted")
        entry["hasTrustDialogAccepted"] = True
        if before is not True:
            changed.append(abs_d)

    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    shutil.move(tmp, CONFIG)
    os.chmod(CONFIG, 0o600)

    if changed:
        print(f"Pre-trusted {len(changed)} director{'y' if len(changed)==1 else 'ies'}:")
        for d in changed:
            print(f"  + {d}")
        print(f"Backup: {backup}")
    else:
        print("All requested directories were already trusted — no changes made.")
        # Backup is harmless; leave it in place.
    return 0


def main():
    dirs = sys.argv[1:] or [os.path.expanduser("~")]
    sys.exit(pre_trust(dirs))


if __name__ == "__main__":
    main()
