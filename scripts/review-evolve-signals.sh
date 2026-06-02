#!/usr/bin/env bash
# review-evolve-signals.sh
#
# Layer 2 eval feedback loop for /evolve.
#
# Reads ~/.claude/pending-evolve/.evolve-decisions.jsonl (written by /evolve
# at the end of each run), aggregates accept/reject/defer patterns since the
# last review, surfaces threshold alerts that recommend SKILL.md updates.
#
# Usage:
#   review-evolve-signals.sh                      Show summary since last review
#   review-evolve-signals.sh --mark-reviewed      Show summary, mark "reviewed up to now"
#   review-evolve-signals.sh --since TIMESTAMP    Override cutoff (ISO 8601 UTC Z-form)
#   review-evolve-signals.sh --all                Ignore cutoff, show all history
#   review-evolve-signals.sh --help               This message
#
# Environment overrides (for testing):
#   EVOLVE_DECISIONS_LOG    path to the .jsonl file
#   EVOLVE_REVIEW_STATE     path to the .last-reviewed.json
#   EVOLVE_ALERT_THRESHOLD  threshold count for reject_reason alerts (default: 10)

set -euo pipefail

LOG="${EVOLVE_DECISIONS_LOG:-$HOME/.claude/pending-evolve/.evolve-decisions.jsonl}"
REVIEW_STATE="${EVOLVE_REVIEW_STATE:-$HOME/.claude/pending-evolve/.last-reviewed.json}"
THRESHOLD="${EVOLVE_ALERT_THRESHOLD:-10}"

MARK_REVIEWED=0
SINCE_OVERRIDE=""
SHOW_ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --mark-reviewed) MARK_REVIEWED=1 ;;
    --all)           SHOW_ALL=1 ;;
    --since)         shift; SINCE_OVERRIDE="${1:-}" ;;
    --since=*)       SINCE_OVERRIDE="${1#--since=}" ;;
    --help|-h)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed. Install via 'brew install jq'." >&2
  exit 1
fi

if [ ! -f "$LOG" ]; then
  echo "No decision log found at:"
  echo "  $LOG"
  echo
  echo "/evolve has not written any decisions yet. Run /evolve in a Claude"
  echo "session, then come back to this script."
  exit 0
fi

# Determine cutoff timestamp
if [ "$SHOW_ALL" -eq 1 ]; then
  LAST_REVIEWED="1970-01-01T00:00:00Z"
elif [ -n "$SINCE_OVERRIDE" ]; then
  LAST_REVIEWED="$SINCE_OVERRIDE"
elif [ -f "$REVIEW_STATE" ]; then
  LAST_REVIEWED=$(jq -r '.last_reviewed_at // "1970-01-01T00:00:00Z"' "$REVIEW_STATE")
else
  LAST_REVIEWED="1970-01-01T00:00:00Z"
fi

# Filter rows since cutoff. fromdate parses Z-form ISO 8601 only.
SINCE_LAST=$(jq -c --arg ts "$LAST_REVIEWED" '
  select((.evolve_session_at | fromdate) > ($ts | fromdate))
' "$LOG" 2>/dev/null || true)

if [ -z "$SINCE_LAST" ]; then
  TOTAL=0
else
  TOTAL=$(printf '%s\n' "$SINCE_LAST" | grep -c . || true)
fi

echo "==================================================================="
echo "  /evolve decision review"
echo "  Cutoff:  $LAST_REVIEWED"
echo "  Window:  $TOTAL decision(s)"
echo "==================================================================="
echo

if [ "$TOTAL" -eq 0 ]; then
  echo "No new decisions in window."
  if [ "$MARK_REVIEWED" -eq 1 ]; then
    echo
    echo "(--mark-reviewed had no effect; nothing to mark.)"
  fi
  exit 0
fi

# Breakdown by decision outcome
echo "By outcome:"
printf '%s\n' "$SINCE_LAST" | jq -r '.decision' | sort | uniq -c | sort -rn \
  | awk '{ printf "  %-10s  %d\n", $2, $1 }'
echo

# Top reject reasons
REJECT_REASONS=$(printf '%s\n' "$SINCE_LAST" \
  | jq -r 'select(.decision == "rejected") | .decision_reason' \
  | sort | uniq -c | sort -rn || true)

if [ -n "$REJECT_REASONS" ]; then
  echo "Top reject reasons:"
  printf '%s\n' "$REJECT_REASONS" | head -10 \
    | awk '{ count=$1; $1=""; sub(/^[ \t]+/, "", $0); printf "  %4d  %s\n", count, $0 }'
  echo

  # Threshold alerts
  ALERTS=$(printf '%s\n' "$REJECT_REASONS" \
    | awk -v t="$THRESHOLD" '$1 >= t { count=$1; $1=""; sub(/^[ \t]+/, "", $0); printf "  [%d]  %s\n", count, $0 }')

  if [ -n "$ALERTS" ]; then
    echo "ALERTS (reject_reason >= ${THRESHOLD} in window):"
    printf '%s\n' "$ALERTS"
    echo
    echo "  Recommendation: review the SKILL.md acid test for the producing skill(s)."
    echo "  Repeated same-reason rejections suggest the acid test is too lenient."
    echo "  Use 'reject rate by skill_source' below to identify which skill to update."
    echo
  fi
fi

# Top defer reasons (short, no threshold, defer is informational)
DEFER_REASONS=$(printf '%s\n' "$SINCE_LAST" \
  | jq -r 'select(.decision == "deferred") | .decision_reason' \
  | sort | uniq -c | sort -rn || true)

if [ -n "$DEFER_REASONS" ]; then
  echo "Top defer reasons:"
  printf '%s\n' "$DEFER_REASONS" | head -5 \
    | awk '{ count=$1; $1=""; sub(/^[ \t]+/, "", $0); printf "  %4d  %s\n", count, $0 }'
  echo
fi

# Per-skill breakdown (the key Layer 2 signal)
echo "Decision rate by skill_source:"
printf '%s\n' "$SINCE_LAST" | jq -r '"\(.skill_source)|\(.decision)"' | awk -F'|' '
{
  skill = $1;
  decision = $2;
  total[skill]++;
  if      (decision == "accepted") accepted[skill]++;
  else if (decision == "rejected") rejected[skill]++;
  else if (decision == "deferred") deferred[skill]++;
}
END {
  printf "  %-28s  %-10s  %-10s  %-10s  %s\n", "skill_source", "accepted", "rejected", "deferred", "total";
  printf "  %-28s  %-10s  %-10s  %-10s  %s\n", "----------------------------", "----------", "----------", "----------", "-----";
  for (s in total) {
    a = (accepted[s]+0);
    r = (rejected[s]+0);
    d = (deferred[s]+0);
    t = total[s];
    a_pct = (t > 0 ? (a * 100.0 / t) : 0);
    r_pct = (t > 0 ? (r * 100.0 / t) : 0);
    d_pct = (t > 0 ? (d * 100.0 / t) : 0);
    printf "  %-28s  %3d (%3.0f%%)  %3d (%3.0f%%)  %3d (%3.0f%%)  %5d\n", s, a, a_pct, r, r_pct, d, d_pct, t;
  }
}' | { IFS= read -r header; IFS= read -r sep; echo "$header"; echo "$sep"; sort; }
echo

# Mark reviewed
if [ "$MARK_REVIEWED" -eq 1 ]; then
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "$REVIEW_STATE")"
  printf '{"last_reviewed_at":"%s"}\n' "$NOW" > "$REVIEW_STATE"
  echo "Marked reviewed at $NOW"
  echo "  ($REVIEW_STATE)"
fi
