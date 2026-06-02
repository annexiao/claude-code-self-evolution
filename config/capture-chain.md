<!-- ccse:capture-chain:start -->

## Capture chain (added by claude-code-self-evolution)

After the session state is saved above, run these two skills **in this exact
order** (one after another, not in parallel). Each scans the same just-ended
session for a different polarity of signal.

1. **`correction-capture`**: corrections in two directions: D1 the user corrected
   Claude, D2 Claude caught a pattern in its own behavior. Dump-only to
   `~/.claude/pending-evolve/`.
2. **`delight-capture`**: endorsements in two directions: D1 the user endorsed a
   Claude move worth replicating, D2 a framing reframed someone's thinking.
   Dump-only to `~/.claude/pending-evolve/`.

These three are **dump-only**: they write candidate files and exit. They do not
propose, do not write to memory, and do not interrupt the user. Promotion happens
later, only when the user runs `/evolve`. Zero candidates is a valid outcome; do
not fabricate signal.

<!-- ccse:capture-chain:end -->
