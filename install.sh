#!/usr/bin/env bash
#
# Installer for claude-code-self-evolution.
# Copies skills, the /evolve command, scripts, and the vendored engine into
# ~/.claude/. Backs up anything it would overwrite. Does NOT touch your
# settings.json automatically (it prints the snippet for you to merge), because
# silently editing your JSON config is the kind of thing you want to do by hand.
#
# Usage:
#   bash install.sh            # install
#   bash install.sh --dry-run  # show what it would do, change nothing

set -euo pipefail

DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"
STAMP="$(date +%Y%m%d-%H%M%S)"

say()  { printf '  %s\n' "$*"; }
head() { printf '\n\033[1m%s\033[0m\n' "$*"; }

run() {
  if [[ $DRY -eq 1 ]]; then
    say "[dry-run] $*"
  else
    eval "$*"
  fi
}

# Copy a file into a destination, backing up an existing different copy first.
install_file() {
  local src="$1" dst="$2"
  run "mkdir -p \"$(dirname "$dst")\""
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst" 2>/dev/null; then
    say "backing up existing $dst -> ${dst}.bak-${STAMP}"
    run "cp \"$dst\" \"${dst}.bak-${STAMP}\""
  fi
  run "cp \"$src\" \"$dst\""
  say "installed $dst"
}

# Append the capture-chain snippet to an existing command file, once (idempotent).
# Used to inject the chain into a save-session command you already have, instead
# of shipping a competing one.
append_chain() {
  local dst="$1"
  if grep -q "ccse:capture-chain:start" "$dst" 2>/dev/null; then
    say "capture chain already present in $dst, skipping"
    return
  fi
  say "backing up $dst -> ${dst}.bak-${STAMP}"
  run "cp \"$dst\" \"${dst}.bak-${STAMP}\""
  if [[ $DRY -eq 1 ]]; then
    say "[dry-run] append config/capture-chain.md to $dst"
  else
    printf '\n' >> "$dst"
    cat "$REPO/config/capture-chain.md" >> "$dst"
  fi
  say "appended capture chain to your existing $dst"
}

head "Installing claude-code-self-evolution into $CLAUDE"
[[ $DRY -eq 1 ]] && say "(dry run, no changes will be made)"

head "1. Capture skills (conversation stream)"
for skill in correction-capture delight-capture; do
  for f in "$REPO/skills/$skill/"*; do
    install_file "$f" "$CLAUDE/skills/$skill/$(basename "$f")"
  done
done

head "2. Commands: /evolve, and the save-session capture trigger"
install_file "$REPO/commands/evolve.md" "$CLAUDE/commands/evolve.md"

# save-session is already a system command for many setups (this repo's, ECC's,
# or your own /s). Rather than ship a competing one, inject the capture chain
# into the save-session command you already have. Only if none exists do we
# install the bundled fallback.
ss_found=0
for existing in "$CLAUDE/commands/save-session.md" "$CLAUDE/commands/s.md"; do
  if [[ -f "$existing" ]]; then
    append_chain "$existing"
    ss_found=1
  fi
done
if [[ $ss_found -eq 0 ]]; then
  install_file "$REPO/commands/save-session.md" "$CLAUDE/commands/save-session.md"
  say "no existing save-session found; installed the bundled fallback"
fi

head "3. Scripts (decay / verify / review)"
for f in "$REPO/scripts/"*.py "$REPO/scripts/"*.sh; do
  dst="$CLAUDE/scripts/$(basename "$f")"
  install_file "$f" "$dst"
  run "chmod +x \"$dst\""
done

head "4. Vendored engine (ECC continuous-learning-v2, tool-call stream)"
run "mkdir -p \"$CLAUDE/skills/continuous-learning-v2\""
run "cp -R \"$REPO/engine/continuous-learning-v2/.\" \"$CLAUDE/skills/continuous-learning-v2/\""
run "find \"$CLAUDE/skills/continuous-learning-v2\" -name '*.sh' -exec chmod +x {} +"
say "installed $CLAUDE/skills/continuous-learning-v2/"

head "5. Runtime directories"
run "mkdir -p \"$CLAUDE/pending-evolve/.processed\" \"$CLAUDE/homunculus/instincts/personal\" \"$CLAUDE/logs\""
say "created pending-evolve/ and homunculus/"

head "Done copying. A few things to know:"
cat <<EOF

  HEADS UP: the observer is ON by default.
  Once you wire the hook (step A), the first tool call in a project lazy-starts a
  background daemon that calls Claude Haiku to distill your tool-call patterns
  into instincts. That is the point of this tool, but it DOES spend Haiku tokens.
  To run without it, set "enabled": false under "observer" in
  ~/.claude/skills/continuous-learning-v2/config.json

  A) Wire the tool-call capture hook (required for the observer stream).
     Merge config/settings.example.json into your ~/.claude/settings.json
     (the PreToolUse + PostToolUse blocks pointing at
     continuous-learning-v2/hooks/observe.sh).

  B) (optional) Schedule weekly confidence decay:
       - macOS: edit config/com.user.instinct-decay.plist.example (set your
         username), copy to ~/Library/LaunchAgents/, then:
           launchctl load ~/Library/LaunchAgents/com.user.instinct-decay.plist
       - Linux: add a weekly cron entry:
           0 3 * * 0  python3 ~/.claude/scripts/apply-instinct-decay.py

  The conversation-capture chain fires at /save-session (the installer injected
  it into your save-session command above). Run /evolve when you want to review
  and promote what has accumulated.

EOF
