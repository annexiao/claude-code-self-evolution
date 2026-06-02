---
name: delight-capture
description: After every /save-session (or its short alias /s, same command) and after correction-capture has finished, scan the just-ended session for TWO types of positive calibration signal, Direction 1 (the user endorses a specific Claude move) and Direction 2 (Claude has an aha moment from the user's framing, or the user's framing reframes Claude's prior position). **DUMP-ONLY**, write candidate files to `~/.claude/pending-evolve/` queue. Do NOT propose to the user directly. Acid test: did the source name a blind spot the other party didn't see, OR propose a framing that changed the other's thinking? If yes → Direction 2. If "Claude did a move worth replicating" → Direction 1. If neither (just polite "thanks") → skip. /evolve reads the queue for batched judgment. TRIGGER strictly on completion of /save-session (or /s) + correction-capture chain.
---

# Delight Capture (dump-only, two directions)

After `/save-session` (or its alias `/s`) and `correction-capture` finish, scan the session for two distinct types of positive calibration signal. Write candidate files to `~/.claude/pending-evolve/`. **Do not propose, do not write to memory, do not interrupt the user.** `/evolve` reads the queue later for batched judgment.

This is the positive-polarity sibling of `correction-capture`. The 2x2 capture matrix (external vs self, correction vs delight) is documented in `correction-capture`'s SKILL.md.

## Why dump-only + two directions

Same architectural reasoning as `correction-capture`: capture is for cheap signal collection, `/evolve` is the single judgment surface that clusters across signal types and decides what becomes a rule / memory / skill.

Two directions because delight is bidirectional:

- **Direction 1**: the user delighted by a Claude move (the original sense, replicate the move)
- **Direction 2**: Claude has an aha moment from the user's framing, or the user's framing reframes Claude's prior position (the user taught Claude a framework worth holding)

Both are positive calibration. They produce different memory shapes and serve different purposes.

## Universal acid test (applies to both directions)

For any candidate moment, ask the two-clause question:

1. Did the source (the party who produced the insightful statement) **name a blind spot the other party didn't see**?
2. Did the source **propose a framing the other party adopts** going forward in the same conversation?

- **YES to either → Direction 2 capture (aha framework)**
- **NEITHER → check Direction 1 acid test below. If also no → skip.**

The blind-spot / reframe definition is stricter than "could Claude replicate this move?", it tests whether the cognitive position of either party actually shifted. If no shift happened, the moment is satisfying but not insight-worthy.

## Direction 1: the user endorses a Claude move (replicate)

### Triggers

- **Explicit praise**: "太好了", "真棒", "you nailed it", "I love that", "你说得好对啊", "this is the shape"
- **Specific endorsement**: "这个比喻准", "your framing is right", "this table is what I wanted", "this analogy works"
- **Keep-doing-this signals**: "以后都这样", "I want more of this", "保持这个口吻"
- **Implicit reinforcement** (highest evidence): the user adopts Claude's phrasing in subsequent messages, or extends a Claude-introduced concept further

### Direction 1 acid test

For each candidate: **could you describe the Claude move in 1-2 sentences such that Claude could replicate it in a different context?**

If yes → Direction 1 capture, file prefix `delight-claude-move-`.
If no (specific to this output, doesn't generalize) → skip.

### Direction 1 file shape

File path: `~/.claude/pending-evolve/delight-claude-move-<kebab-topic>-<YYYYMMDD-HHMMSS>.md`

```markdown
---
type: delight
direction: D1
topic: <kebab-topic>
captured_at: <ISO 8601>
captured_from_session: <session-file-name>
project_id: <12-char-hash> | global
project_name: <repo-name> | global
source: user-endorsed-claude-move
proposed_scope: global | project=<name>
suggested_target: memory
---

# <Title, declarative sentence about the move>

## The move
<1-2 sentence pattern statement: when [context], doing [move] works because [mechanism].>

## Why it lands
<Specific reason the move resonated, tied to this session.>

## When to reach for it
<Future situations where this move applies. Concrete enough for trigger recognition.>

## Source moment
<Verbatim the user endorsement + verbatim Claude move.>
```

## Direction 2: Aha moments, Claude (or the user) gets a framework worth holding

### Triggers

The set here is broader than Direction 1 because cognitive endorsement uses different vocabulary:

**Chinese**:
- 洞见 / 这是个洞见 / 你这个洞见很准
- 发人深省 / 深刻
- 启发 / 有启发 / 启发到我了
- 这个角度好 / 这个 framing 好 / 这个 lens 准
- 这是我没想到的 / 我没意识到 / 没意识到这层
- 让我重新想了一下 / 我得重新想一下
- 你这么一说 / 你这么一框

**English**:
- "insightful" / "this is insightful" / "really insightful"
- "thought-provoking" / "got me thinking"
- "didn't see it that way" / "hadn't thought about it that way"
- "makes me rethink X" / "I need to reconsider"
- "good angle" / "good frame" / "good lens"
- "that reframes it" / "that changes how I see it"
- "huh" / "oh interesting" (when followed by genuine extension, not polite)
- "you're making me reconsider" / "I'm reconsidering Y"

**Implicit Direction 2 signals** (highest weight when caught):
- the user's next message extends or applies Claude's framing as if internalized
- the user adopts Claude's specific vocabulary in subsequent messages
- the user references the framing back to Claude later in the conversation as a settled point
- Claude visibly changes a previously-stated position and the conversation moves on with the new one

### Direction 2 acid test (the blind-spot / reframe definition)

The trigger phrase alone is necessary but not sufficient. Run the two-clause test (same as Universal acid test above):

1. Did the source name a blind spot the other party didn't see? OR
2. Did the source propose a framing that the other party adopts going forward?

If YES to either → Direction 2 capture, file prefix `delight-aha-framework-`.
If NEITHER → skip. The moment was satisfying but not framework-shaped.

### Direction 2 file shape

File path: `~/.claude/pending-evolve/delight-aha-framework-<kebab-topic>-<YYYYMMDD-HHMMSS>.md`

```markdown
---
type: delight
direction: D2
topic: <kebab-topic>
captured_at: <ISO 8601>
captured_from_session: <session-file-name>
project_id: <12-char-hash> | global
project_name: <repo-name> | global
source: user-articulated | claude-design-user-endorsed | user-reframe-of-claude | claude-aha-from-user-insight
proposed_scope: global | project=<name>
suggested_target: memory or rule
---

# <Title, declarative sentence stating the framework>

## The framework
<2-3 sentence statement of the insight as a transferable principle.>

## Why this matters
<What previously-held assumption or default it overturns or improves. Specific.>

## Source moment
<Verbatim statement that surfaced the framework + context (what was being discussed when it emerged).>

## How to apply
<When / where this framework applies in future situations. List concrete trigger conditions.>

## Generalizes beyond this session
<(Optional but encouraged) Other domains where the same lens applies, surface 1-3 adjacent cases to help future Claude recognize the pattern elsewhere.>

## Pair with
<(Optional) Other pending-evolve entries from same session that compose with this one.>
```

## When NOT to capture (either direction)

Avoid noise:

- **Bare politeness**: "thanks" / "ok!" / "好的" / "👍" / "got it" without specific endorsement
- **Praise of content, not Claude-move-or-framework**: "the calculator design is good" (about output, not how Claude did it)
- **Endorsement of something but the user can't articulate WHAT pattern**: "this is great" with no specifics
- **Single-instance aesthetic taste that won't generalize**: "this color is nice" in one specific UI
- **Trigger phrase present but no actual shift**: Claude said "this reframes it" as filler, no real position change

## Project context detection

When writing the candidate file, populate `project_id` and `project_name` by detecting the current project context. Reuse continuous-learning-v2's helper:

```bash
source ~/.claude/skills/continuous-learning-v2/scripts/detect-project.sh
# After sourcing: $PROJECT_ID and $PROJECT_NAME are set
# If not in a git repo / no project context: both default to "global"
```

Fallback chain if the script isn't available: `CLAUDE_PROJECT_DIR` env var → `git rev-parse --show-toplevel` from cwd → "global" literal.

The project_id is stable across sessions for the same repo (hashed from git remote URL), so `/evolve` can cluster candidates from different sessions of the same project together for promotion logic.

## Process

1. **Identify the session**: read `~/.claude/session-data/YYYY-MM-DD-HHMM-*-session.tmp` + in-context history.

2. **Scan for trigger phrases AND surrounding context**:
   - For each candidate, check whether Direction 1 or Direction 2 acid test passes
   - Verify the trigger phrase is matched to a specific Claude move (D1) or framework moment (D2), not floating praise

3. **Detect project context** for the frontmatter.

4. **Write each surviving candidate** to `~/.claude/pending-evolve/<type>-<topic>-<timestamp>.md` using the right shape (D1 vs D2 templates above).

5. **Do nothing else.** No clustering across candidates. No scope finalization. No review propose to the user. The queue file is the deliverable.

## Hard constraints

- **NEVER write directly to `~/.claude/projects/.../memory/`.** Memory writes happen only via `/evolve`.
- **NEVER propose review to the user.** /evolve is the review surface.
- **Don't conflate D1 and D2.** They have different memory shapes and serve different downstream purposes. When uncertain, prefer D2 (it's the higher-leverage capture) but mark `suggested_target: undetermined` in frontmatter.
- **Acid test or skip.** Trigger phrase alone is necessary but not sufficient.
- **Zero entries is a valid output.** Don't fabricate to seem productive.

## Tone in candidate files

Memory text is for future Claude to read. Style guidance:

- **Imperative, declarative**: "When X, do Y" not "I would suggest doing Y when X"
- **Concrete trigger conditions**: "when explaining a system with multi-step async flow" beats "when explaining systems"
- **Cite the original source moment verbatim** in the source field: anchors the framework in a specific incident
- **No emoji, no hedging language**
- **For Direction 2**: surface adjacent domains where the framework also applies (the "Generalizes beyond" section), this is where Direction 2's value compounds
