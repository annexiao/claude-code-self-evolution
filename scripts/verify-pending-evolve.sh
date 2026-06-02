#!/usr/bin/env bash
# verify-pending-evolve.sh
#
# Layer 1 queue-health inspector for ~/.claude/pending-evolve/.
# Informational only, never blocks /evolve.
#
# Walks every *.md candidate (skipping .processed/) and reports deviations
# from the current schema as WARNINGS. /evolve still consumes every file
# regardless of schema state because Claude reads markdown flexibly. The
# warnings exist so the user (or future-Claude) can see queue health at a
# glance and notice when current capture skills emit non-conforming
# output (vs legacy drift from older sessions, which is expected).
#
# Checks:
#   1. Filename matches one of the four valid prefixes
#      (correction-, correction-self-correction-, delight-claude-move-, delight-aha-framework-)
#   2. Frontmatter exists (--- ... --- block at top)
#   3. Required fields present: type, direction, topic, captured_at,
#      captured_from_session, project_id, project_name, source,
#      proposed_scope, suggested_target
#   4. type / direction consistent with filename prefix
#   5. captured_at looks like ISO 8601
#   6. project_id non-empty
#
# Exit code is always 0 unless the script itself can't run (missing dir,
# missing jq). Per-file deviations never block.
#
# Usage:
#   verify-pending-evolve.sh             Scan default dir
#   verify-pending-evolve.sh --quiet     Only output if errors/warnings exist
#   verify-pending-evolve.sh --help      This message
#
# Environment override (for testing):
#   PENDING_EVOLVE_DIR    path to scan (default: ~/.claude/pending-evolve)

set -uo pipefail
shopt -s nullglob

DIR="${PENDING_EVOLVE_DIR:-$HOME/.claude/pending-evolve}"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet|-q) QUIET=1 ;;
    --help|-h)
      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -d "$DIR" ]; then
  echo "Error: directory does not exist: $DIR" >&2
  exit 1
fi

REQUIRED_FIELDS=(type direction topic captured_at captured_from_session project_id project_name source proposed_scope suggested_target)
VALID_PREFIX_RE='^(correction|correction-self-correction|delight-claude-move|delight-aha-framework)-'

ERRORS=0
WARNINGS=0
TOTAL=0
CHECKED=0

# Collect output so --quiet can suppress when clean
OUTPUT=""
emit() {
  if [ "$QUIET" -eq 0 ]; then
    printf '%s\n' "$1"
  fi
  OUTPUT+="$1"$'\n'
}

err() {
  local f="$1" msg="$2"
  emit "ERROR [$f]: $msg"
  ERRORS=$((ERRORS+1))
}

warn() {
  local f="$1" msg="$2"
  emit "WARN  [$f]: $msg"
  WARNINGS=$((WARNINGS+1))
}

extract_field() {
  # extract_field <frontmatter_text> <field_name>
  # Returns the value (whitespace-trimmed, unquoted) or empty.
  printf '%s\n' "$1" \
    | grep -E "^${2}:" \
    | head -1 \
    | sed -E "s/^${2}:[[:space:]]*//; s/^['\"]//; s/['\"]$//"
}

for f in "$DIR"/*.md; do
  [ -e "$f" ] || continue
  TOTAL=$((TOTAL+1))
  bname=$(basename "$f")

  # 1. Filename prefix
  if ! [[ "$bname" =~ $VALID_PREFIX_RE ]]; then
    warn "$bname" "filename prefix not recognized (expected correction-/correction-self-correction-/delight-claude-move-/delight-aha-framework-)"
    continue
  fi

  # Filename timestamp suffix (-YYYYMMDD-HHMMSS.md or -YYYYMMDD-HHMM.md)
  if ! [[ "$bname" =~ -[0-9]{8}-[0-9]{4,6}\.md$ ]]; then
    warn "$bname" "filename does not end with -YYYYMMDD-HHMMSS.md or -YYYYMMDD-HHMM.md timestamp"
  fi

  # 2. Frontmatter present and parseable
  FM=$(awk '/^---[[:space:]]*$/{c++; if (c==2) exit; next} c==1{print}' "$f" 2>/dev/null)
  if [ -z "$FM" ]; then
    warn "$bname" "no frontmatter found (expected --- ... --- at top of file)"
    continue
  fi
  CHECKED=$((CHECKED+1))

  # 3. Required fields presence
  for field in "${REQUIRED_FIELDS[@]}"; do
    if ! printf '%s\n' "$FM" | grep -qE "^${field}:"; then
      warn "$bname" "missing required field '${field}'"
    fi
  done

  # 4. type / direction consistency with filename prefix
  type_val=$(extract_field "$FM" type)
  direction_val=$(extract_field "$FM" direction)

  expected_type=""
  expected_direction=""
  case "$bname" in
    correction-self-correction-*) expected_type="correction"; expected_direction="D2" ;;
    correction-*)                 expected_type="correction"; expected_direction="D1" ;;
    delight-claude-move-*)        expected_type="delight";    expected_direction="D1" ;;
    delight-aha-framework-*)      expected_type="delight";    expected_direction="D2" ;;
  esac

  if [ -n "$expected_type" ] && [ -n "$type_val" ] && [ "$type_val" != "$expected_type" ]; then
    warn "$bname" "type='$type_val' inconsistent with filename prefix (expected '$expected_type')"
  fi
  if [ -n "$expected_direction" ] && [ -n "$direction_val" ] && [ "$direction_val" != "$expected_direction" ]; then
    warn "$bname" "direction='$direction_val' inconsistent with filename prefix (expected '$expected_direction')"
  fi

  # 5. captured_at ISO 8601-ish
  captured_at=$(extract_field "$FM" captured_at)
  if [ -n "$captured_at" ] && ! [[ "$captured_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    warn "$bname" "captured_at='$captured_at' does not look like ISO 8601"
  fi

  # 6. project_id non-empty
  project_id=$(extract_field "$FM" project_id)
  if [ -z "$project_id" ]; then
    warn "$bname" "project_id is empty or missing"
  fi
done

# Summary (always emit, even with --quiet, if there were errors/warnings)
if [ "$QUIET" -eq 0 ] || [ "$ERRORS" -gt 0 ] || [ "$WARNINGS" -gt 0 ]; then
  if [ "$QUIET" -eq 1 ]; then
    printf '%s' "$OUTPUT"
  fi
  echo
  echo "==================================================================="
  echo "  verify-pending-evolve"
  echo "  Directory: $DIR"
  echo "  Files:     $TOTAL total, $CHECKED checked"
  echo "  Errors:    $ERRORS"
  echo "  Warnings:  $WARNINGS"
  echo "==================================================================="
fi

[ "$ERRORS" -gt 0 ] && exit 1
exit 0
