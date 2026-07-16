---
name: correction-capture
description: After every /save-session (or its short alias /s, same command), scan the just-ended session for TWO types of correction signal, Direction 1 (the user corrected Claude's behavior) and Direction 2 (Claude self-corrected, recognizing a pattern it should change). Both written as candidate files to `~/.claude/pending-evolve/` queue. **DUMP-ONLY**, no propose, no memory write, no review. Filters out one-off fact / scope corrections and performative self-criticism, only captures systemic / replicable signal. Sibling skill to delight-capture; the 2x2 capture matrix is correction-D1 / correction-D2 / delight-D1 / delight-D2. TRIGGER strictly on completion of /save-session (or /s).
---

# Correction Capture (dump-only, two directions)

After `/save-session` (or its alias `/s`), scan the same session for TWO types of correction signal:

- **Direction 1**: the user corrected Claude's behavior (the original sense, external correction)
- **Direction 2**: Claude self-corrected, recognizing a pattern in its own behavior worth changing

Write candidate files to `~/.claude/pending-evolve/`. **Do not propose, do not write to memory, do not interrupt the user.** `/evolve` reads the queue later for batched judgment.

## The 2x2 capture matrix (with delight-capture)

```
                  ┌─────────────────────────┬─────────────────────────┐
                  │   Polarity: correction  │   Polarity: delight     │
                  │   ("don't do X")        │   ("do more of X")      │
┌─────────────────┼─────────────────────────┼─────────────────────────┤
│ External        │   D1: the user corrects      │   D1: the user endorses      │
│ (the user is source) │   Claude move           │   Claude move           │
├─────────────────┼─────────────────────────┼─────────────────────────┤
│ Self            │   D2: Claude self-      │   D2: Claude has aha    │
│ (Claude is      │   corrects, recognizing │   from the user's framing,   │
│ source)         │   own pattern           │   or the user reframes       │
└─────────────────┴─────────────────────────┴─────────────────────────┘
```

Same structural pattern across the matrix. All four go to `pending-evolve/` queue with different file prefixes. `/evolve` clusters across all four.

## Why dump-only

This skill is the **capture layer**, not the judgment layer. Capture is for cheap signal collection; `/evolve` is the single judgment surface that clusters across signal types, decides routing, and writes durable outputs. Capture-vs-judgment separation lets the user's review burden batch at /evolve time rather than multiplying per skill.

## Why two directions

The continuous-learning-v2 instinct system observes tool-call patterns only, `observe.sh` doesn't capture user messages or Claude's text responses. Conversational corrections (D1) AND Claude's own real-time self-corrections (D2) both die at session end without explicit capture.

D2 is high-value because Claude has direct access to its own reasoning trace and can catch patterns the user doesn't even notice. Self-recognized failures are often deeper than user-observed ones (Claude knows when it chose wrong, even when the result happened to be acceptable to the user). But D2 also has a noise risk: performative self-criticism without substance. The acid test below filters for real D2.

## Direction 1: the user corrects Claude (external correction)

### Triggers

> These example phrases are illustrative signals, not a literal or exhaustive match list. Match on meaning, in any language, not on exact wording.

- **Direct negation**: "no", "don't", "wait", "actually", "that's not right", "don't do it like that"
- **Style / format feedback**: "too long", "less jargon", "more concrete", "you keep doing X", "less em-dashes", "no over-organized markdown"
- **Workflow preference**: "I always do X before Y", "every time, Y comes after X", "the default should be X"
- **Aesthetic / framing taste**: "say it in plain words", "this framing is too corporate", "don't use words like 'incredibly'"
- **Self-introspection prompted**: "why did you do X again" / "you did it again" / "you just made that up"
- **Meta-correction** (highest priority): the user explicitly elevates an incident into a rule ("always do it this way from now on" / "note this pattern" / "this should go into memory")

### Direction 1 filter

For each candidate, run two checks:
- Is this a systemic preference (persists across sessions) or a one-off (scope-limited)?
- Can I articulate the underlying rule in 1-2 sentences without reference to this specific task?

If NO to either → skip. If YES to both → capture as D1.

### Direction 1 file shape

File path: `~/.claude/pending-evolve/correction-<kebab-topic>-<YYYYMMDD-HHMMSS>.md`

```markdown
---
type: correction
direction: D1
topic: <kebab-topic>
captured_at: <ISO 8601>
captured_from_session: <session-file-name>
project_id: <12-char-hash> | global
project_name: <repo-name> | global
source: user-direct-correction-of-claude | user-self-introspection-prompted | user-meta-correction
proposed_scope: global | project=<name>
suggested_target: memory | CLAUDE.md | rule | undetermined
---

# <Title, declarative sentence stating what changed>

## What changed
<1-2 sentence rule statement.>

## Why this matters
<Specific reason, tied to a past incident in this session.>

## How to apply
<When / where this rule fires.>

## Source moment
<Verbatim the user correction phrase + verbatim Claude action that triggered it.>
```

## Direction 2: Claude self-correction (internal recognition)

### Triggers

Moments where Claude (in its own response text, not in answer to a direct the user challenge) recognizes a pattern in its own behavior worth changing:

> As above, these are illustrative signals, not a literal or exhaustive match list. Match on meaning, in any language.

- "I should have done X earlier"
- "I missed Y"
- "I just realized I've been doing Z"
- "I notice I keep doing W"
- "Looking back, I would have done this differently"
- "I should have caught that"
- "I conflated A and B"
- "I confused X for Y"
- "I owe you a sharper version"

**Implicit D2 signals** (highest weight when caught):
- Claude visibly rolls back a position it just stated and proposes a different one **without the user challenging the original**
- Claude flags its own past behavior pattern across multiple session moments ("I've been over-organizing the markdown this whole session")
- Claude catches its own assumption that wasn't surfaced explicitly

### Direction 2 acid test (filter for performative self-criticism)

Trigger phrase alone is necessary but not sufficient. To pass:

1. **Specific behavior, not generic**: Does the self-correction point to a **specific** behavior Claude was doing, not just "I could be better in general"?
2. **Articulatable as a future-checkable rule**: Can it be stated as a rule future Claude could self-check against ("when context X, avoid Y")?
3. **About a pattern**, not just this incident: Would the lesson apply to similar future situations, or is it one-off?

ALL THREE → capture as D2. Any NO → skip (it's performative self-criticism, not a real correction signal).

### Direction 2 file shape

File path: `~/.claude/pending-evolve/correction-self-correction-<kebab-topic>-<YYYYMMDD-HHMMSS>.md`

```markdown
---
type: correction
direction: D2
topic: <kebab-topic>
captured_at: <ISO 8601>
captured_from_session: <session-file-name>
project_id: <12-char-hash> | global
project_name: <repo-name> | global
source: claude-self-correction
proposed_scope: global | project=<name>
suggested_target: memory | rule | undetermined
---

# <Title, declarative sentence stating what Claude noticed it should change>

## The self-correction
<1-2 sentence rule: "When [context], I should do [Y] instead of [X]", articulated as a transferable rule future Claude can self-check.>

## What I was doing wrong
<Specific behavior pattern Claude caught itself doing in this session. Not generic.>

## The right behavior
<What Claude should be doing instead. Concrete.>

## Why I missed it before
<(Optional but valuable) The underlying assumption / default that produced the wrong behavior. Helps future Claude recognize the same trap.>

## How to apply
<Future trigger conditions Claude can self-check against.>

## Source moment
<Verbatim Claude self-correction statement + context (what was happening when Claude recognized the pattern).>
```

## When NOT to capture (either direction)

Avoid noise:

- **One-off fact corrections** (D1): "that value is 0.005, not 0.02", this-task scope only
- **Current-task implementation decisions** (D1): "use React, not Vue", applies to this build, not a workflow rule
- **Performative self-criticism without substance** (D2): "I could have done better" without specifics
- **Casual filler** (D1): "wait" used to think rather than to correct
- **Praise / endorsement of a Claude move**: that's `delight-capture`'s job
- **Ambiguous reactions** where the underlying rule can't be articulated in 1-2 sentences

Skip aggressively. The queue should contain signal, not noise. `/evolve` can always pick up a missed signal next session if the pattern recurs.

## Project context detection

When writing the candidate file, populate `project_id` and `project_name` by detecting the current project context. Reuse continuous-learning-v2's helper:

```bash
source ~/.claude/skills/continuous-learning-v2/scripts/detect-project.sh
# After sourcing: $PROJECT_ID and $PROJECT_NAME are set
# If not in a git repo / no project context: both default to "global"
```

If the detection script isn't available, fall back to:
- `CLAUDE_PROJECT_DIR` env var → use as project root
- `git rev-parse --show-toplevel` from current cwd → use as project root
- Neither available → `project_id: global`, `project_name: global`

The project_id stays consistent across sessions for the same repo (because it's hashed from the git remote URL), so `/evolve` can cluster candidates from different sessions of the same project together.

## Process

1. **Identify the session**: read the most recent `~/.claude/session-data/YYYY-MM-DD-HHMM-*-session.tmp` + in-context history.

2. **Scan for trigger phrases AND surrounding context**:
   - For D1 candidates, check the user-correction triggers
   - For D2 candidates, check Claude's own response text for self-correction triggers
   - Verify trigger phrase is matched to specific behavior, not floating commentary

3. **For each candidate, apply the relevant acid test** (D1 filter or D2 acid test above).

4. **Detect project context** for the frontmatter.

5. **Write each surviving candidate** to `~/.claude/pending-evolve/<type>-<topic>-<timestamp>.md` using the right shape (D1 vs D2 templates above).

6. **Do nothing else.** No clustering. No scope finalization. No review propose. The queue file is the deliverable.

## Hard constraints

- **NEVER write directly to `~/.claude/projects/.../memory/`.** Memory writes happen only via `/evolve`.
- **NEVER propose review to the user.** /evolve is the review surface.
- **NEVER cluster across candidates at capture time.** Each correction-shaped moment is its own file.
- **Acid test or skip.** Trigger phrase alone is necessary but not sufficient. Especially strict for D2 to avoid performative noise.
- **Zero entries is a valid output.** Don't fabricate.

## What this skill produces (and where it goes)

```
~/.claude/pending-evolve/
├── correction-<topic>-20260522-1635.md                  ← D1: the user corrects Claude
├── correction-self-correction-<topic>-*.md              ← D2: Claude self-corrects
├── delight-claude-move-<topic>-*.md                     ← Delight D1: replicate move
├── delight-aha-framework-<topic>-*.md                   ← Delight D2: hold framework
└── .processed/                                          ← /evolve archives here
```

`/evolve` reads all `*.md` (skipping `.processed/`), clusters across types, decides routing.

## Distinct from other channels

| Channel | Role |
|---|---|
| `~/.claude/CLAUDE.md` | Hard rules, manually authored by the user |
| **`correction-capture` D1+D2 → pending-evolve** | Capture conversation-derived corrections (external + self) |
| `delight-capture` D1+D2 → pending-evolve | Capture conversation-derived endorsements (external + self-aha) |
| Instinct system | Capture tool-call patterns |
| `/evolve` | **JUDGMENT layer**, reads everything except CLAUDE.md, decides routing |

## Within-session repetition clustering (added 2026-05-24)

After collecting individual D1 / D2 candidates from a session, run one
deterministic pass to cluster them by theme. The signal that a correction
was issued **twice in the same session on the same theme** is the strongest
in-band evidence that a real behavior pattern exists, much stronger than
two isolated corrections.

### Procedure

1. For each captured candidate, generate a coarse theme tag from the
   underlying rule (e.g., `user-must-not-restate-loaded-rules`,
   `no-new-skill-when-existing-fits`, `trust-the-rule-system`).
2. If ≥2 candidates share a theme tag → emit ONE additional merged
   candidate file with:
   - `repetition_count: N`
   - `confidence: high`
   - Body listing each instance with its turn number / timestamp /
     verbatim trigger phrase
3. **Always emit the individual candidates too**, alongside the merged
   one. Each instance may carry context `/evolve` needs to see.

### Why this lives here, not in a separate `repetition-capture` skill

Repetition is a *property* of corrections, not its own category. A
sibling skill would duplicate the trigger logic, the queue path, and the
filter heuristics, operational tax without payoff. Keeping repetition
inside correction-capture means `/evolve` has ONE place to look for
"things to learn from corrections," with intra-session repetition just
being a higher-confidence sub-case.

### Default `/evolve` routing for repetition-tagged candidates

When `/evolve` sees a merged candidate with `repetition_count ≥ 2`, its
default move shifts from "consider" to "promote":
- `repetition_count = 2` → propose as a rule or memory entry, ask the user
- `repetition_count ≥ 3` → strong signal; almost certainly a rule.
  Auto-draft the rule body for the user to approve.

The judgment is still `/evolve`'s; this skill just upgrades the
confidence label that `/evolve` reads.

### Anti-pattern

- Skipping individual candidates and emitting only the merged one.
  The merged file loses per-instance verbatim, `/evolve` may need to
  see "exactly what the user said the second time" to phrase the resulting
  rule well. Always emit both.

### Triggering example

(Illustrative and paraphrased, not a verbatim transcript.)

Within one session:
- Turn 12: the user says "if the global rule actually took effect, I wouldn't have to keep saying this", captured as
  D1, theme tag `trust-the-rule-system`.
- Turn 18: the user says "and if it were written down clearly, I shouldn't have to repeat it", captured as D1, theme tag `trust-the-rule-system`.
- Cluster pass: 2 candidates share theme → emit merged file
  `corr-D1-merged-trust-the-rule-system.md` with `repetition_count: 2`,
  body listing both instances. `/evolve` later promotes this to a rule
  with high confidence.

### Design note

> If this skill already covers the correction, maybe repetition should be handled here too, rather than in a separate sibling skill.

Resolved by extending this skill rather than creating a sibling.
