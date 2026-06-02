---
name: save-session
description: Save the current session's state to a dated file, then run the capture chain (correction-capture, then delight-capture) in order. This is the trigger that drives the conversation-capture half of the system. Invoke at the end of a working session.
command: true
---

# Save Session (capture-chain trigger)

This command is the trigger for the conversation-capture half of
claude-code-self-evolution. It does two things, in order:

1. Writes a small session-state file (so a future session can resume context).
2. Runs the two capture skills, **in this exact order**, so the queue fills
   with candidates for `/evolve` to judge later.

The chain order is defined here, in this shipped command, so the system is
self-contained: you do not need any external `CLAUDE.md` wiring for it to work.

## Step 1: write the session-state file

Create `~/.claude/session-data/` if it does not exist, then write a file named
`YYYY-MM-DD-HHMM-session.md` containing:

- Date and time
- Project / working directory (basename of cwd, or `git rev-parse --show-toplevel`)
- A short list of the tasks worked on this session
- Files created or modified
- Any notes useful for resuming next time

Keep it brief. This file is for resuming context, not a full transcript.

```bash
mkdir -p ~/.claude/session-data
# write the dated file with the summary above
```

Tell the user where it was saved.

<!-- ccse:capture-chain:start -->

## Step 2: run the capture chain, in order

After the session-state file is written, run these two skills **in this
order**. Each scans the same just-ended session for a different polarity of
signal. Run them one after another, not in parallel, because the later one
references the earlier one's framing.

1. **`correction-capture`** to capture corrections, in two directions:
   - D1: the user corrected Claude's behavior.
   - D2: Claude caught a pattern in its own behavior worth changing.
   Writes dump-only candidates to `~/.claude/pending-evolve/`.

2. **`delight-capture`** to capture endorsements, in two directions:
   - D1: the user endorsed a specific Claude move worth replicating.
   - D2: a framing reframed someone's thinking (an aha worth holding).
   Writes dump-only candidates to `~/.claude/pending-evolve/`.

<!-- ccse:capture-chain:end -->

## Important

- The two capture skills are **dump-only**: they write candidate files and
  exit. They do NOT propose, do NOT write to memory, and do NOT interrupt the
  user. Promotion happens later, only when the user runs `/evolve`.
- **Zero candidates is a valid outcome.** Do not fabricate signal to seem
  productive. If a skill finds nothing worth capturing, it reports that and the
  chain continues.
- Run the chain even on sessions that feel uneventful. Each skill produces a
  "nothing to capture" report rather than silently skipping, which keeps the
  habit reliable.

## Note on the `/s` alias

Some setups alias this command to `/s` for speed. This repo ships only
`/save-session`; if you want the alias, add your own `commands/s.md` that defers
to this one.
