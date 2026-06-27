---
name: evolve
description: Cluster instincts AND conversation-derived candidates from `~/.claude/pending-evolve/` queue, decide routing (rule / skill / memory / agent / skip) yourself with stated defaults, audit existing files, then ask for one final unified approval covering all proposed writes.
command: true
---

# Evolve Command (auto-judge, single-confirmation variant, two-source)

## Pre-Run: Read All ADRs (including Superseded)

Before evolving patterns into rules/skills, scan **all** ADRs in `docs/decisions/` of the current project, not only those marked `Accepted`. ADRs marked `Superseded by ...` carry the constraints and rejected alternatives that shaped the current state, and those constraints often still apply. The audit trail is the value, not just the latest answer. Skipping superseded ADRs means re-suggesting patterns that have already been tried and rejected.

This is a customized version of the ECC `/evolve` flow. Compared to the default ECC behavior (which auto-writes evolved skill/command/agent files on `--generate` from instincts only), this version:
- Reads BOTH instincts AND the `~/.claude/pending-evolve/` queue (conversation-derived candidates from `correction-capture` + `delight-capture`)
- Clusters across both source streams (cross-pollination)
- Adds **rule** and **memory** as output channels alongside skill / agent
- Uses judgment to route per cluster, audits existing files for the right target
- Presents ONE unified plan for the user to approve once

## Routing modes & confidence gating (READ FIRST, added 2026-05-25)

`/evolve` runs in one of three modes. Default (bare `/evolve`) = **global**. The mode decides what is *read*, what is *written*, and what stays put. This layer governs everything below, the Steps that follow are the **global mode** body; inbox and project modes are narrower.

| Mode | Reads | Writes | Gate |
|---|---|---|---|
| **`/evolve inbox`** | all root `pending-evolve/*.md` | **nothing**, classifies, stamps `routing_confidence`, moves high-confidence project-specific candidates to project queues, proposes |, |
| **`/evolve global`** (default) | candidates that are `routing_confidence: high` AND (clearly cross-project-general OR recurring in ≥2 projects/sessions) | global rule / memory | high-confidence gate |
| **`/evolve project`** | current-repo candidates (root inbox filtered by `project_id` + that project's own queue), repo via `git rev-parse` | project rule / memory **only after explicit user confirmation** | high-confidence + user confirm |

### `routing_confidence` (assigned by `inbox`, NOT by capture)

Confidence is a **judgment**, so it is stamped by `/evolve` (inbox mode, or inline during a global/project run), never by the capture skills, capture records only facts (`project_id`, `captured_from_session`, `proposed_scope`). Levels:

- **high**, clearly cross-project-general, OR recurs in ≥2 sessions/projects, OR the user meta-corrected it
- **medium**, plausibly general but single-instance and not obviously universal
- **low / unclear**, scope can't be attributed with confidence

### The four gates (every candidate passes all four, in order)

A candidate becoming durable must clear four gates in sequence. Failing a gate stops promotion, it is not retried at a higher tier.

**1. Source gate, where did this come from?**
Every candidate carries source facts recorded by capture (facts, not judgment): `project_id` / `project_name` / `captured_from_session` / `proposed_scope`. If the source is unattributable, scope can't be reasoned about → defer. (root `pending-evolve/` is a neutral inbox; landing there confers nothing.)

**2. Confidence gate, how strong is the evidence?**
`routing_confidence` is stamped here (judgment, not capture): **high** = clearly cross-project-general OR ≥2 *agreeing* projects/sessions OR the user meta-corrected; **medium** = plausible but single-instance; **low/unclear** = scope unattributable. Only **high** may proceed toward global; medium/low/unclear → defer.

> **Recurrence-gating is for CORRECTIONS, not for FRAMEWORKS (a category error to avoid).** The "single-instance, defer until it recurs" rule above is calibrated for **behavioral-pattern corrections**: a correction needs ≥2 occurrences to confirm it is a *real systemic issue* and not a one-off slip. **It does NOT apply to strategic frameworks / mental models**, the `delight-aha-framework` (and most `delight-claude-move`) candidates. A transferable insight is valuable on its **first articulation**, it does not need to recur to prove it is real, *because it is a lens, not a flaky pattern.* Treating an aha like a flaky test, withholding it until it repeats, is a category error that silently drops the **highest-value signal** /evolve exists to capture. So:
> - For `type: delight-aha-framework` / `delight-claude-move`: **single-instance is sufficient** for promotion to **memory** (the framework channel). Judge them on **transferability and durability**, NOT recurrence count.
> - For corrections (`type: correction`): recurrence remains the bar for becoming a **rule** (a one-off correction may still be a one-off, ≥2 confirms it is systemic).
> - Mnemonic: **recurrence is the bar for corrections to rules; transferability is the bar for frameworks to memory.** Never gate a framework on recurrence.

**3. Conflict gate, is there a counterexample or boundary conflict? (a VETO, not a score)**
Before promoting, scan other projects' memory/candidates/instincts AND existing `rules/` for a contradicting entry (¬X). This gate is **asymmetric**: a single genuine counterexample outweighs many agreements, because the claim under test is "this is *globally* true" and one counterexample refutes universality.
- **Any genuine conflict VETOES global promotion**, it does not merely lower confidence. The candidate is not discarded; it is reclassified `context-dependent` and handed to the Scope gate for project-scoping.
- **Conflict with an EXISTING global rule MUST be surfaced loudly**, never silently write a rule that contradicts one already in `rules/`. Otherwise the ruleset slowly grows self-contradictory. Resolution is the user's call: either the existing global rule was over-generalized and gets scoped down, or the new candidate is context-specific. Report it; do not auto-resolve.

**4. Scope gate, global / project / context-dependent / defer?**
- cleared gates 1 to 3, high-conf, cross-project, no conflict → **global** rule/memory.
- high-conf but project-specific, OR conflict-vetoed from global → **project (context-dependent)**: written to that project's scope with the boundary/conflict noted, and **only after explicit user confirmation** (or the user saying "this is a project rule"). Never auto-write a project rule.
- medium/low/unclear, OR an unresolved conflict → **defer** (stay in root inbox; move only a high-confidence project-specific candidate to `~/.claude/projects/<project_id>/pending-evolve/`).

`/evolve inbox` runs gates 1 to 3 and proposes a Scope-gate outcome, but **writes nothing**, classification only.

### Per-project queue convention

- `~/.claude/pending-evolve/` = global candidates + unsorted inbox
- `~/.claude/projects/<project_id>/pending-evolve/` = candidates judged project-specific (created on first move)

### Why this layer exists

Before this, capture always dumped to one global root queue and `/evolve` treated everything there as a global candidate, so a mixed queue of project + global candidates got blind-routed, risking project-specific or low-context candidates becoming global rules. The confidence gate + per-project queues make **default defer** the safe baseline: nothing becomes global or project-durable without clearing an explicit bar. Source: 2026-05-25 routing-layer design discussion.

## Core principles (apply yourself, don't ask)

1. **Default to cheaper artifacts.** Cost hierarchy from cheap to expensive:
   - rule (a few lines in markdown, loaded only when context matches) ← cheapest
   - memory (nuanced feedback entry in `~/.claude/projects/.../memory/`) ← cheap
   - skill (~37 tokens system-prompt overhead every conversation forever) ← expensive
   - agent (new file in agents/ marketplace surface) ← most expensive

   For "persistent if-this-then-that principle" → **rule**. For "nuanced preference / framework I learned in conversation" → **memory**. Reserve skill for true on-demand multi-step workflows the user would explicitly invoke. Reserve agent for genuinely separable specialized roles.

2. **Don't ask the user "which output channel?" per cluster.** Make the call. Use the decision tree below.

3. **Confirm once, at the end, with everything visible.** The user reviews a single table of proposed writes and says "go" or selectively rejects. No per-item questions during the planning phase.

## Step 0, Read both sources

### Source A: Instincts (tool-call patterns)

```bash
python3 ~/.claude/skills/continuous-learning-v2/scripts/instinct-cli.py evolve
```

(or `${CLAUDE_PLUGIN_ROOT}/skills/continuous-learning-v2/scripts/instinct-cli.py evolve` if `CLAUDE_PLUGIN_ROOT` is set.)

Read the output and identify:
- **Clusters** of related instincts
- **High-confidence singletons** (≥0.7) representing a single rule
- **Promotion candidates**, same instinct in 2+ projects with high confidence (these are global rule candidates by default)

### Source B: Conversation-derived candidates (`~/.claude/pending-evolve/`)

```bash
ls ~/.claude/pending-evolve/*.md 2>/dev/null
```

(skip `.processed/`, that's the archive of already-handled candidates)

Read every `*.md` file in the directory. Each is a self-contained candidate with frontmatter describing:
- `type`: `correction` | `delight-claude-move` | `delight-aha-framework`
- `topic`: kebab-slug
- `captured_at`, `captured_from_session`, `source`
- `proposed_scope`: hint from the capture skill (not final, `/evolve` can override)
- `suggested_target`: hint (`memory` | `rule` | `CLAUDE.md` | `undetermined`)

Group these candidates by topic similarity (don't trust the topic slug alone, read the body and judge).

### Cross-source clustering (the architectural payoff)

After reading both sources independently, check for **cross-pollination**: does a `pending-evolve/` candidate cluster with one or more instincts about the same topic?

Example: a tool-call instinct "user often Edits CSS to remove !important" + a pending-evolve `correction-no-inline-important` candidate → these are one cluster, not two. Both alone might be borderline; together they're a clear rule.

Cross-source clusters get **higher priority** in routing decisions (more evidence, stronger signal).

## Step 0.5, Queue health snapshot (informational, non-blocking)

Run `~/.claude/scripts/verify-pending-evolve.sh` to get a Layer 1 schema summary of `pending-evolve/`. **This is informational only, never blocks /evolve from proceeding.** Output goes into the working memory of this /evolve run so the final summary can note queue health.

```bash
~/.claude/scripts/verify-pending-evolve.sh
```

What to do with the output:

- **Files: N total, M checked + Warnings: K**, print this line near the start of /evolve's working narration so the user sees queue health at a glance.
- **Warnings about legacy-schema files** (missing fields, old `type: delight-aha-framework` combined, filename prefix unrecognized, `direction: 1` instead of `D1`, etc.), **ignore for routing purposes**. Claude reads each markdown file flexibly in Step 0, infers what's missing, and routes based on body content. Legacy drift does not affect /evolve's ability to process.
- **Genuine ERRORS** (currently script never emits these; reserved for catastrophic cases like missing dir / missing jq), surface to the user and ask whether to abort the run.

This step is the **upstream-quality eyeball**, not a gatekeeper. The capture skills evolve over time; legacy files in the queue are absorbed naturally by Claude in Step 0.

## Step 1, For each candidate / cluster, decide routing

### Decision tree

```
Is this a hard, never-bend rule the user authored before this session?
   (e.g. existing entries in ~/.claude/CLAUDE.md)
   → IGNORE, already covered, don't duplicate

Is this an "if-this-then-that" persistent principle?
   (e.g. "always validate input", "prefer functional style",
    "tests before implementation", "italics in blue")
   YES → RULE  (cheapest persistent artifact)

Is this a nuanced preference / framework that came from conversation,
   doesn't need to be a hard rule, but should persist?
   (e.g. "default to terse unless asked for detail", "reach for
    grounded analogies when explaining systems", "audit fabricated
    specifics in public-bound text")
   YES → MEMORY  (the user's nuanced-guidance channel)

Is this a multi-step workflow the user would explicitly type
   /<name> to invoke?
   AND ≥3 distinct steps?
   AND no existing skill already covers it?
   YES → SKILL

Is this a complex, separable specialized role (e.g. a domain expert
   for a particular framework) that deserves its own context window?
   YES → AGENT

Else → SKIP
```

**Tiebreak rule**: when uncertain between rule and memory, prefer rule (more discoverable, applied automatically). When uncertain between memory and skill, prefer memory (cheaper).

**Skill anti-bloat gate** (mandatory before proposing skill):

```bash
ls ~/.claude/skills/ | head -50                          # local skills
ls ~/.claude/.agents/skills/ 2>/dev/null | head          # agent-mode skills
grep -l "<topic-keyword>" ~/.claude/skills/*/SKILL.md    # similar-topic match
```

If a similar skill exists → propose modifying it, not creating a new one. If after this check the cluster doesn't pass all 3 conditions in the SKILL branch above → demote to RULE or MEMORY.

## Step 2, For each RULE, pick scope and file (no asking)

### Scope

Default to **global** when:
- Cross-project promotion candidate (already in 2+ projects)
- Universal engineering principle (testing, security, code review, immutability, error handling, naming, etc.)
- Framework/language-agnostic

Default to **project** when:
- Specific to this codebase's conventions or domain
- References project-specific paths, models, or business logic
- Stack-specific in a way that conflicts with how other projects work

When uncertain → **global**. Easier to demote global → project later than the reverse.

### Target file

For **global** rules:
1. List `~/.claude/rules/` subdirectories: `common/`, `web/`, `python/`, `typescript/`, `golang/`, `swift/`, `php/`, `zh/` (skip `zh/`, translations only).
2. Pick the most domain-specific subdirectory that fits.
3. List markdown files in that subdirectory and read their top-level headings (first 30 lines of each is enough).
4. Pick the file whose existing topic best matches.

For **project** rules:
1. Detect repo root: `git rev-parse --show-toplevel`
2. Convention check (in order):
   - `<root>/.claude/rules/*.md` (subdirectory convention)
   - `<root>/CLAUDE.md` (single-file convention, most common)
3. If neither exists → propose creating `<root>/CLAUDE.md`.

### Append vs modify vs skip

Read the chosen file in full. Decide:
- New principle → **append** under the most relevant existing heading, or with a new heading if no fit
- Refines / nuances an existing entry → **modify** that entry in place
- Direct duplicate of existing entry → **skip** (don't double-write)

## Step 3, For each MEMORY, pick scope and file (with promotion logic)

### Memory promotion logic (project → global)

**Mirror continuous-learning-v2's instinct promotion pattern**: when the same memory topic appears in multiple projects, it's a candidate for promotion to global. Before finalizing scope for a memory candidate, run this audit:

```
For the topic of the current candidate:
  1. grep ~/.claude/projects/*/memory/feedback*<similar-topic>*.md
  2. Also grep ~/.claude/projects/<your-home-project>/memory/feedback*<similar-topic>*.md (existing global memory)
```

Routing decisions based on what the audit finds:

| What the audit finds | Routing |
|---|---|
| Topic doesn't exist anywhere yet | Use candidate's `proposed_scope` (project or global based on capture skill's hint) |
| Topic exists in **1 project memory** + current candidate is from a **different project** | **PROMOTION candidate** → write to global, propose deleting / merging old project entry, surface decision in the unified review table |
| Topic exists in **2+ project memories** (cross-project pattern) | **AUTO-PROMOTE** to global, propose archiving the project entries (move to `.processed/` rather than delete, in case the user wants them back) |
| Topic exists in **global memory** already | SKIP (already promoted), OR propose modifying the existing global entry if the new candidate adds nuance |
| Topic exists in **same project memory** already | UPDATE-IN-PLACE candidate → propose modifying the existing entry in that project |

Promotion thresholds (mirror instinct-cli constants):
- `PROMOTE_MIN_PROJECTS = 2` (same as continuous-learning-v2): 2+ projects with similar topic
- For memory there's no `confidence` field to threshold on, but the existence-in-multiple-projects signal substitutes, "this pattern surfaced in 2+ contexts" implies cross-project relevance

Project-id matching: use the `project_id` field in pending-evolve candidate frontmatter (the 12-char hash from continuous-learning-v2's project detection) for stable cross-session clustering. If `project_id` is "global", treat the candidate as cross-project by intent.

### Scope (after promotion audit)

After running the audit above, the final scope decision:

- **Promote to global** (from audit table above) → `~/.claude/projects/<your-home-project>/memory/feedback_<topic>.md`
- **Stays project-scoped** when:
  - Pattern only surfaced in 1 project AND clearly references specific codebase / domain / conventions
  - The pending-evolve candidate's `proposed_scope` is `project=<name>` and topic isn't seen elsewhere
  - Target: `~/.claude/projects/<project-hash>/memory/feedback_<topic>.md`
- **Stays global** when:
  - Candidate's `proposed_scope` is `global` AND topic doesn't exist locally elsewhere

When uncertain → prefer global (easier to demote later than to find a missed cross-project rule).

### Target file

- Global: `~/.claude/projects/<your-home-project>/memory/feedback_<kebab-topic>.md`
- Project: `~/.claude/projects/<project-hash>/memory/feedback_<kebab-topic>.md`

File-name prefixes (preserve from capture skill output):
- Correction-derived: `feedback_<topic>.md` (default)
- Delight Direction 1 (Claude move to replicate): `feedback_reinforce_<topic>.md`
- Delight Direction 2 (aha framework): `feedback_framework_<topic>.md`
- Correction Direction 2 (Claude self-correction): `feedback_self_<topic>.md` (distinguishes from external user-correction)

### Memory file body shape (mirror existing memory style)

```markdown
---
name: <kebab-slug>
description: <one-line, used for relevance matching>
metadata:
  type: feedback
  polarity: avoid | reinforce | framework
---

<Rule / framework statement (1-2 sentences)>

**Why:** <Specific reason or past incident.>

**How to apply:** <When / where this fires.>
```

### MEMORY.md index update

After writing the memory file, append a line to the matching `MEMORY.md` in the same directory:
```
- [Title](feedback_<topic>.md), <one-line summary>
```

## Step 4, For each SKILL, pick scope and propose

If you got past the anti-bloat gate:

- Skill name: kebab-case, scoped narrowly enough not to collide with the existing 220+ skills
- Skill location: `~/.claude/skills/<name>/SKILL.md` (global skills only, there's no "project skill" convention worth using)
- Skill description: ≤130 chars, precise (every char is system-prompt cost forever)
- Skill body: the multi-step procedure, drawn from the source instincts + pending-evolve candidates

If proposing modification of an existing skill: read its SKILL.md, decide where the new content fits.

## Step 5, Present the unified plan (this is the only ask)

Show the user **one table** covering every proposed write. For each row:

| # | Cluster / Source | Decision | Target | Action | Source items |
|---|---|---|---|---|---|
| 1 | "always validate user input at boundaries" | RULE → global | `~/.claude/rules/common/coding-style.md` | append under "Input Validation" | instinct: validate-form-input, sanitize-api-payload + pending-evolve: correction-validate-everything-20260520 |
| 2 | "audit fabricated specifics in public text" | MEMORY → global | `~/.claude/projects/<your-home-project>/memory/feedback_audit_fabricated_specifics.md` | create | pending-evolve: correction-audit-fabricated-specifics-20260522 |
| 3 | "use grounded analogies when explaining systems" | MEMORY → global, framework | `~/.claude/projects/<your-home-project>/memory/feedback_framework_grounded_analogies.md` | create | pending-evolve: delight-aha-framework-grounded-analogies-20260522 |
| 4 | "scaffold a FastAPI plan endpoint" | SKILL | new: `~/.claude/skills/fastapi-plan-endpoint/SKILL.md` | create | api-router-skeleton, request-validator |
| 5 | (low confidence singleton) | SKIP |, |, | obscure-cli-flag-preference |

Below the table, show **one diff per row** (in a fold or sequentially): the actual content that will be appended/modified/created.

Then ask:

> "Apply all? (yes / no / list rows to skip, e.g. '2,4')"

Wait for the response. Apply only approved rows. Don't ask anything else during the plan phase.

## Step 5.5, Routing Review Report & safety thresholds (added 2026-05-25)

Every `/evolve` run emits a **Routing Review Report** alongside the Step 5 plan, and checks four safety thresholds **before any write**. This is the lightweight per-run eval surface, distinct from Step 8's cross-run `.evolve-decisions.jsonl` aggregate. Lightweight by design: generated inline by `/evolve`, no new script, no capture-skill changes.

### Per-candidate routing table

One row per candidate processed this run:

| candidate_id | source_project / source_session | proposed_scope | routing_confidence | conflict_scan_result | final_route | reason | user confirm required? |

- **conflict_scan_result**: `none` | `conflict-with-project:<name>` | `conflict-with-global-rule:<file>` | `boundary/context-dependent`
- **final_route**: `global-rule` | `global-memory` | `project-rule` | `project-memory` | `context-dependent` | `defer` | `reject(covered)` | `keep-as-instinct`
- **user confirm required?**: `yes` for any project rule/memory write OR any surfaced conflict; else `no`

### Audit sample (5 random candidates)

Randomly pick 5 of this run's candidates; for each show: original body text, full metadata (frontmatter), the routing decision, and the reason. The spot-check that routing matches content, lets the user catch a mis-route without reading every row.

### Metrics (computed for the run)

> **Exclude already-covered candidates from BOTH numerator and denominator.** A candidate already captured by an existing rule/skill/memory is an **archive / no-op**, not a promotion, counting it inflates the denominator and (if mis-bucketed) the numerator. The eligible base is **NEW candidates only**: `eligible = total - already_covered`. And **rule-promotion and memory-promotion are separate rates**: the 30% guard is about *rule* bloat (behavioral, near-always-loaded), whereas memory is a recall-gated cheap channel and frameworks-to-memory is the *designed* path, not a suspect promotion.

- **rule_promotion_rate** = global-rule writes / eligible-NEW candidates  (the rate the 30% guard applies to)
- **memory_promotion_rate** = global-memory writes / eligible-NEW candidates  (informational, NOT gated at 30%, especially for `delight-*` framework candidates whose intended home is memory)
- **defer_rate** = deferred / eligible-NEW
- **conflict_surfaced_count** = candidates whose conflict_scan_result ≠ `none`
- **project_specific_confirmation_count** = project-route candidates that required user confirmation
- **user_correction_count** = times the user overrode a proposed route in this run's review

### Safety thresholds (checked BEFORE writing, a trip pauses or downgrades, never silently proceeds)

1. **rule_promotion_rate > 30% → PAUSE and explain.** Do not write. Promoting more than ~30% of the **eligible-NEW** batch to global *rules* is suspect (the global rule bar, high-conf + cross-project + no-conflict, should rarely clear that many at once). Surface the rate, list what's being promoted, ask the user to confirm or trim first. **Note:** `memory_promotion_rate` is NOT subject to this 30% gate, a backlog of `delight-*` framework candidates is *supposed* to mostly become memory, and gating that on the rule-bloat threshold is the category error corrected in the Confidence gate above. Already-covered candidates are excluded from the base entirely (archive, not promotion).
2. **conflict_scan_result all `none` BUT candidates span ≥2 projects → flag for re-check.** Zero conflicts across a multi-project batch usually means the scan was too shallow. Re-run it carefully (read the actual other-project entries, don't pattern-match) before trusting the all-clear.
3. **project-specific candidate without user confirmation → MUST NOT write project rule/memory.** Hard block. No confirmation → stays `defer`, never auto-written.
4. **confidence not explainable → default `defer`.** If you can't state in one sentence why a candidate is high/medium/low, it isn't high. Default to `defer`.

These thresholds are guards layered on the four gates (Source/Confidence/Conflict/Scope), not replacements.

## Step 6, Write approved rows, archive processed candidates, summarize

After writing:

- Print a short summary: "Wrote N rules, M memories, K skills, A agents, skipped S."
- For each write, show the resolved file path.
- **For each pending-evolve candidate that fed an approved write**: move it to `~/.claude/pending-evolve/.processed/` (preserves audit trail; can be re-examined if needed).
- **For each pending-evolve candidate the user skipped**: leave it in `~/.claude/pending-evolve/` for next run, OR (if low-value) delete with user confirmation.
- List source instinct YAML paths so the user can `rm` them if they want (don't auto-delete instincts, `pending-evolve/` candidates archive automatically, instincts don't).

## Step 7, Log every decision to `.evolve-decisions.jsonl` (Layer 2 feedback loop)

After Step 6 (writes + archive complete), append ONE JSON line per processed candidate to `~/.claude/pending-evolve/.evolve-decisions.jsonl`. **Every candidate /evolve looked at this run gets logged**, regardless of outcome, accepted, rejected, or deferred.

This is not optional. The log is the only Layer 2 eval signal for the capture skills upstream; skipping rows silently degrades the feedback loop. See `~/.claude/scripts/review-evolve-signals.sh` for the consumer.

### Row schema (locked)

```jsonl
{"candidate_file":"correction-foo-20260522-173500.md","skill_source":"correction-capture","decision":"accepted","decision_reason":"cross-source cluster","tags":["type=correction","direction=D1","topic=foo","scope=global"],"confidence":0.9,"evolve_session_at":"2026-05-23T15:30:00Z"}
```

Fields:

- **`candidate_file`**: basename of the source file. One row per file:
  - For `pending-evolve/` candidates: the `.md` filename
  - For instinct YAMLs: the `.yaml` filename
  - For cross-source clusters: write **one row per involved file** (same `decision` / `decision_reason` / `evolve_session_at`, but each with its own `skill_source`). Link them via a `cluster_id=<run-uuid>` tag.
- **`skill_source`**: where the candidate originated
  - `correction-capture` (filename prefix `correction-`)
  - `delight-capture` (filename prefix `delight-`)
  - `continuous-learning-v2` (instinct YAML)
- **`decision`**: exactly one of `accepted` | `rejected` | `deferred`
  - `accepted` → candidate fed a write that was persisted in Step 6
  - `rejected` → /evolve chose SKIP in Step 1, or the user excluded the row in Step 5
  - `deferred` → candidate left in queue for next run (singleton awaiting cluster, low confidence, waiting for evidence)
- **`decision_reason`**: terse, structured phrase. **Prefer canonical phrases over freeform prose**, aggregation depends on string equality. Canonical set (extend conservatively):
  - Reject: `"too narrow"`, `"one-off implementation choice"`, `"performative self-criticism"`, `"duplicate of existing memory"`, `"insufficient evidence"`, `"out of scope"`, `"covered by existing rule"`, `"user excluded in review"`
  - Defer: `"singleton awaiting cluster"`, `"low confidence, watching"`, `"needs human judgment"`, `"evidence in 1 project only"`
  - Accept: `"cross-source cluster"`, `"high-confidence instinct"`, `"explicit meta-correction"`, `"reinforced across sessions"`, `"auto-promote to global"`
- **`tags`**: array of `key=value` strings drawn from candidate frontmatter. Minimum: `type=`, `direction=`, `topic=`, `scope=`. For cross-source clusters add `cluster_id=<uuid>` linking rows.
- **`confidence`**: /evolve's confidence in the decision (0.0 to 1.0). Rough calibration:
  - 0.9+ → cross-source cluster, explicit the user meta-correction, or 3+ project occurrences
  - 0.7 to 0.85 → clear single-stream signal, well-articulated rule
  - <0.7 → borderline; usually defer rather than accept/reject
- **`evolve_session_at`**: ISO 8601 **UTC Z-form** timestamp (e.g., `2026-05-23T15:30:00Z`). Generated once at start of /evolve run, reused for all rows from that run.

### Timestamp format (load-bearing)

All `evolve_session_at` values **must** be UTC Z-form, never local-offset (`-07:00`). The review script uses `jq fromdate` for time-window filtering, which only parses Z form. Mixing formats breaks aggregation silently. Generate via:

```bash
EVOLVE_RUN_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

### Append protocol

```bash
echo '{"candidate_file":"...","skill_source":"...","decision":"...","decision_reason":"...","tags":[...],"confidence":...,"evolve_session_at":"...Z"}' \
  >> ~/.claude/pending-evolve/.evolve-decisions.jsonl
```

One row per `echo`, append-only, jsonl format. The file is never rewritten, only appended. Partial logs from crashed /evolve runs are fine; unlogged candidates stay in the queue and get re-processed next run.

### Why log everything (not just rejections)

Reject-only logging misses two important signal classes:
- **Accept rate by skill**: a skill with consistently >80% accept rate is well-calibrated; a skill at <30% needs its SKILL.md acid test tightened. You can't compute this from rejects alone.
- **Defer patterns**: candidates repeatedly deferred but never crossing into accept/reject indicate either a too-strict threshold or a topic that is genuinely one-off and should be rejected outright.

Together, accept + reject + defer rates per `skill_source` constitute the labeled Layer 2 corpus for evaluating upstream capture skills. The judgment decisions /evolve already has to make become the eval pipeline at zero marginal cost.

### Backward compatibility

The schema is forward-extensible, new fields can be added without breaking the review script (jq reads only known fields). When adding a new field, document it here AND update `review-evolve-signals.sh` if the aggregation should use it.

## Step 8, Run review-evolve-signals.sh and surface any alerts

After Step 7 has appended all decision rows to `.evolve-decisions.jsonl`, run the Layer 2 review summarizer with `--mark-reviewed`:

```bash
~/.claude/scripts/review-evolve-signals.sh --mark-reviewed
```

This:
1. Reads the cumulative `.evolve-decisions.jsonl`
2. Filters to rows since the last `.last-reviewed.json` cutoff
3. Aggregates accept/reject/defer rates per `skill_source`
4. Lists top reject reasons + top defer reasons
5. Surfaces threshold alerts (any `decision_reason` appearing ≥ `EVOLVE_ALERT_THRESHOLD` times, default 10)
6. Updates `.last-reviewed.json` to "now" so next /evolve only sees rows from this run forward

### Folding the summary into /evolve's final report

Take the script's output and **fold it into your final summary to the user**. If there are no threshold alerts and the rates look healthy, a one-line note is enough:

> Review window: 14 decisions (10 accept / 3 reject / 1 defer). No alerts.

If there ARE threshold alerts, surface them prominently:

> **ALERT**: `correction-capture` emitted 12 candidates rejected as "too narrow" in the last window. This suggests the D1 acid test in `correction-capture/SKILL.md` is too lenient. Consider tightening the "systemic preference (not one-off fact)" filter.

The alert text should name (a) which skill is producing noise, (b) which reject_reason keeps recurring, (c) which acid test or filter to look at.

### Why review at /evolve time (not scheduled separately)

Earlier proposals considered a weekly launchd job to run review. Rejected because:
- Review only has new signal when /evolve has logged new decisions
- /evolve doesn't run on a clock, so weekly runs would mostly produce stale repeats
- Folding into /evolve = single user-touched surface, no background timers, no hidden state

The same logic applied to verify-pending-evolve.sh (Step 0.5): both scripts are user-pull, not clock-push. Their natural cadence is "whenever /evolve runs."

## Cross-source clustering example (the architectural payoff in practice)

Scenario: user works on CSS for a few weeks. Two streams accumulate:

**Tool-call stream (continuous-learning-v2 observer)**: noticed pattern "user runs Grep then Edit on CSS files containing !important", generated instinct `prefer-setProperty-over-inline-important` at confidence 0.6 (borderline).

**Conversation stream (correction-capture)**: in session 2026-05-18 user said "don't set !important via inline JS, use setProperty", dumped to `~/.claude/pending-evolve/correction-no-inline-important-20260518.md` (single moment, low standalone weight).

Each alone would likely SKIP at /evolve time. Together at /evolve, they cluster into:
- RULE → global → `~/.claude/rules/web/css-conventions.md` → append under "JS-set styles": "Never set !important via inline JS; use setProperty on the relevant rule."
- Both sources are cited in the row's "Source items" column for traceability.

This is the payoff of treating both signal streams as inputs to one judgment surface. Capture stays cheap on both sides; judgment compounds.

## Why this differs from upstream ECC `/evolve`

Default ECC `/evolve --generate`:
- Writes `~/.claude/homunculus/.../evolved/` files automatically per cluster, no review
- Doesn't audit existing rules or skills before creating new ones
- Doesn't distinguish persistent-principle (rule) from invoked-tool (skill)
- Has no concept of "memory" as an output channel
- Reads only instincts (no conversation-derived signal)
- Tends toward skill-shaped output, growing per-conversation token cost

This variant:
- Reads two sources (instincts + `pending-evolve/`)
- Adds rule and memory as output channels
- Audits existing rules / skills / memory files before creating new ones
- Uses cost-aware tiebreak (cheaper artifacts preferred)
- Single unified approval gate

## Note: this replaces ECC's `/evolve`

This command installs to `~/.claude/commands/evolve.md` and is a rewrite of ECC's
`/evolve`. If you also have the ECC marketplace installed, its updates may
overwrite this file (the marketplace copy lives under
`~/.claude/plugins/marketplaces/ecc/commands/evolve.md`). If that happens,
re-run this project's `install.sh` to restore the cost-aware, four-gate version.
The `pending-evolve/` + memory channel behavior is specific to this project and
is not in upstream ECC.
