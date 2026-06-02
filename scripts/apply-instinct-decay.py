#!/usr/bin/env python3
"""
apply-instinct-decay.py

Deterministic confidence decay for continuous-learning-v2 personal instincts.
Replaces the Haiku-driven decay rule that lived in observer.md ("-0.02/week")
with a small, predictable, code-driven decay (-0.005/week).

Design:
  - File mtime is the "last evidence" timestamp. The observer agent updates
    mtime whenever it touches a YAML (confirming/contradicting observations).
    Manual edits also update mtime, which is fine, reviewing an instinct
    counts as thinking about it.
  - Decay = WEEKLY_DECAY * weeks_since_mtime, floored at CONFIDENCE_FLOOR.
  - Files touched in the last MIN_WEEKS_STALE are skipped (no point decaying
    an instinct that just got reinforced).
  - Writing the file updates mtime → next run sees ~0 stale → decays again
    only after another week of inactivity. Self-resetting.

Designed for weekly launchd schedule (com.user.instinct-decay.plist).
To disable temporarily: `launchctl unload ~/Library/LaunchAgents/com.user.instinct-decay.plist`
To tune the rate: edit WEEKLY_DECAY below.

Run with --dry-run to preview without writing.
"""

import argparse
import re
import sys
import time
from pathlib import Path

# ───── Configuration ─────
WEEKLY_DECAY = 0.005       # confidence loss per week stale
MIN_WEEKS_STALE = 1.0      # don't decay anything touched in the last week
CONFIDENCE_FLOOR = 0.0     # don't go below this
SECONDS_PER_WEEK = 7 * 86400

HOMUNCULUS = Path.home() / ".claude/homunculus"

CONFIDENCE_RE = re.compile(r'^(confidence:\s*)([\d.]+)', re.MULTILINE)


def find_instinct_dirs() -> list[Path]:
    """All personal/ directories: global + per-project."""
    dirs: list[Path] = []
    global_dir = HOMUNCULUS / "instincts" / "personal"
    if global_dir.is_dir():
        dirs.append(global_dir)
    projects_dir = HOMUNCULUS / "projects"
    if projects_dir.is_dir():
        for p in projects_dir.iterdir():
            if p.is_dir():
                personal = p / "instincts" / "personal"
                if personal.is_dir():
                    dirs.append(personal)
    return dirs


def decay_file(f: Path, dry_run: bool):
    """Decay one file. Returns (old, new, weeks) or None if skipped."""
    weeks_stale = (time.time() - f.stat().st_mtime) / SECONDS_PER_WEEK
    if weeks_stale < MIN_WEEKS_STALE:
        return None

    text = f.read_text()
    m = CONFIDENCE_RE.search(text)
    if not m:
        return None  # no confidence field, leave it alone

    old_conf = float(m.group(2))
    new_conf = max(CONFIDENCE_FLOOR, old_conf - WEEKLY_DECAY * weeks_stale)
    if abs(new_conf - old_conf) < 0.001:
        return None  # below precision threshold

    if not dry_run:
        new_text = CONFIDENCE_RE.sub(rf'\g<1>{new_conf:.3f}', text, count=1)
        f.write_text(new_text)

    return (old_conf, new_conf, weeks_stale)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--dry-run', action='store_true',
                   help='Show what would change without writing')
    args = p.parse_args()

    prefix = '[DRY RUN] ' if args.dry_run else ''
    print(f"{prefix}Scanning {HOMUNCULUS}")
    print(f"{prefix}Decay rate: {WEEKLY_DECAY}/week, floor: {CONFIDENCE_FLOOR}, skip if < {MIN_WEEKS_STALE}w stale")
    print()

    total = 0
    changed = 0
    for d in find_instinct_dirs():
        for f in sorted(d.glob("*.md")):
            total += 1
            result = decay_file(f, args.dry_run)
            if result:
                old, new, weeks = result
                changed += 1
                rel = f.relative_to(HOMUNCULUS)
                action = 'would change' if args.dry_run else 'changed'
                print(f"  {old:.3f} → {new:.3f}  ({weeks:5.1f}w stale)  {rel}")

    print()
    verb = 'would change' if args.dry_run else 'changed'
    print(f"{prefix}{changed}/{total} files {verb}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
