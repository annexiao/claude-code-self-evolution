---
name: evolve
description: Cluster instincts AND conversation-derived candidates from `~/.claude/pending-evolve/` queue, decide routing (rule / skill / memory / agent / skip) yourself with stated defaults, audit existing files, then ask for one final unified approval covering all proposed writes.
command: true
---

# Evolve Command (auto-judge, single-confirmation, two-source)

Reads two signal streams (tool-call instincts from continuous-learning-v2, and conversation-derived candidates in `~/.claude/pending-evolve/`, written by `correction-capture` + `delight-capture`), clusters across them, routes each cluster to the cheapest durable artifact that holds it, and asks the user for exactly ONE approval covering every proposed write. Full provenance vs upstream ECC: Appendix D.

The run is four phases, each an ordered checklist: **READ, JUDGE, PROPOSE, EXECUTE**. The single approval sits at the end of PROPOSE; nothing durable is written before it, and no new proposals may surface after it.

## Modes (determine FIRST, this scopes everything below)

| Mode | Reads | May write | Gate |
|---|---|---|---|
| **`/evolve`** (default, sweeps everything) | instincts + ALL root `pending-evolve/*.md` + EVERY project queue `~/.claude/projects/*/pending-evolve/*.md`. One run covers global AND all projects, so the user never has to `cd` into a repo to evolve it. | global rules/memory AND, per project, that project's rules/memory | Confidence gate for global; Confidence + **per-project** user confirm for each project's writes |
| **`/evolve inbox`** | all root `pending-evolve/*.md` | **no durable artifacts** (no rules/memory/skills/agents). Queue-internal bookkeeping only: stamps `routing_confidence` into candidate frontmatter and moves high-confidence project-specific candidates to that project's queue. Proposes Scope-gate outcomes; writes nothing else. | (none) |
| **`/evolve project`** | current repo only (root inbox filtered by `project_id` + the project's own queue); repo via `git rev-parse --show-toplevel` | that project's rule/memory, **ONLY after explicit user confirmation** | Confidence + user confirm |

**Default-mode output structure (added 2026-07-15).** The default run does NOT collapse everything into one table. It produces **one GLOBAL plan table + one separate plan table per project** that has surviving candidates. Each table is labeled with its scope (`GLOBAL` / `project=<name>`) so the user always knows which context they are judging in. **Each table gets its OWN go/skip decision**, never one blanket "yes" spanning global + N projects (that is the rubber-stamp failure the per-project confirmation invariant exists to prevent). When the run touches a project, read that project's ADRs (Phase 1.6) before proposing its table. `location does not equal scope`: a candidate physically in the root inbox with `proposed_scope: project=X` is only a *hint*; the Scope gate decides its real home, and a project-captured lesson that is actually cross-project-general routes GLOBAL (that is correct, not a bug).

Queue convention: root `~/.claude/pending-evolve/` = global candidates + unsorted inbox; `~/.claude/projects/<project_id>/pending-evolve/` = candidates judged project-specific (created on first move). `.processed/` under each = archive of handled candidates.

## Core principles (apply yourself, don't ask)

1. **Default to cheaper artifacts.** Cost hierarchy, cheap to expensive: **rule** (markdown, loaded when context matches), then **memory** (recall-gated note in `~/.claude/projects/.../memory/`), then **skill** (~37 tokens of system-prompt cost every conversation forever), then **agent**. "Persistent if-this-then-that principle" goes to rule. "Nuanced preference / framework from conversation" goes to memory. Skill only for true multi-step workflows the user would explicitly invoke. Agent only for genuinely separable roles. (**`command` is deliberately NOT in this hierarchy and NOT a routing target**: the user does not use slash-commands as promotion destinations, and the routing tree in 2.3 writes rule/memory/skill/agent only. Removed 2026-07-15 because a leftover `command` rung caused real confusion about whether `/evolve` routes there. It does not.)
2. **Don't ask "which output channel?" per cluster.** Make the call with the decision tree in JUDGE.
3. **One review surface, per-table confirmation.** The user reviews a single unified surface at the end of PROPOSE (the global table + one table per project). They give a **separate go/skip per table**: global gets its own, each project gets its own, so they are always confirming inside that scope's context. Within a table they may skip individual rows. No per-item questions before the surface; no new proposals after it.
4. **Report every bucket.** The final summary's buckets (accepted / rejected / deferred / kept-as-instinct) must sum to the number of candidates evaluated. Name the defer/no-action residual explicitly with its count: it is often the largest bucket and the easiest to omit. (The user, 2026-06-27, noting the defer bucket is the one usually left out.)

---

## Phase 1: READ

**1.1 Determine mode** (table above). All later steps are scoped by it.

**1.2 Read Source A, instincts:**

```bash
python3 ~/.claude/skills/continuous-learning-v2/scripts/instinct-cli.py evolve
```

(or `${CLAUDE_PLUGIN_ROOT}/skills/continuous-learning-v2/scripts/instinct-cli.py evolve` if set.) Identify: clusters of related instincts; high-confidence singletons (>= 0.7); promotion candidates (same instinct in 2+ projects, global rule candidates by default).

**1.3 Read Source B, the candidate queue** for this mode's scope (skip `.processed/`). Read every file's body, not just frontmatter. Frontmatter fields: `type` (`correction` | `delight-claude-move` | `delight-aha-framework`), `topic`, `captured_at`, `captured_from_session`, `source`, `project_id`, `proposed_scope` (a capture-time hint, NEVER final), `suggested_target` (hint).

> **Gotcha (added 2026-07-16, after a real mis-read):** `project_id` holds a **hash** (e.g. `a1b2c3d4e5f6`), NOT the project name; the readable name is in the separate `project_name` field (e.g. `my-app`). To filter/count candidates by project, grep `project_name`, or map the hash first: `grep 'project_id: <name>'` returns 0 and falsely reads as "no project candidates." Also: candidates carry their scope in **frontmatter**, not in a physical per-project `pending-evolve/` subdir (those are created only on first move), so "no project subdir exists" does not mean "no project candidates." Get the real distribution with `grep -h '^project_name:' *.md | sort | uniq -c`.

**1.4 Queue health snapshot** (informational, never blocks):

```bash
~/.claude/scripts/verify-pending-evolve.sh
```

Print the `Files: N total / Warnings: K` line in the run narration. Legacy-schema warnings are ignorable for routing (bodies are read flexibly in 1.3). Genuine errors (missing dir/jq) get surfaced, ask whether to abort.

**1.5 Historical enforcement-debt readout.** Over the existing `~/.claude/pending-evolve/.evolve-decisions.jsonl` (before this run appends anything), filter rows where `decision_reason == "covered by existing rule"` AND `would_have_prevented == "yes"`, group by `mapped_rule_clause`, note per-clause counts. This is each clause's standing **enforcement debt**. Cold start (no log / no such rows) is fine: note "no debt data" and move on. Full debt semantics + the graduation ladder: Appendix B.

> **Split by triage, and window it (added 2026-07-25, because the raw count conflates two opposite fixes and never ages out).** Two corrections to the tally above, or it mis-graduates:
> - **Split each clause's count by the row's `triage=` tag** (`plumbing` / `steerability` / `over-scoping`, stamped on covered rows, per Appendix B Step 1). The count that drives a HOOK/decompose graduation is the **steerability** count ALONE. Plumbing rows (the rule existed but was never delivered to context) route to a **loading** fix, not a hook: hardening a rule that was never delivered does nothing. Over-scoping rows route to a **narrowing**. A clause at threshold on plumbing/over-scoping rows must NOT be proposed for a hook.
> - **Window the count.** This is Appendix B's own "did it work = the clause stops appearing with `would_have_prevented=yes` in *later windows*", which the raw all-time tally does not implement. If an `annotation` row carrying `resolves_clause: <clause>` exists (write one at EXECUTE whenever this run fixes a root cause for a clause: a loading fix, a hook, a narrowing), count ONLY covered-rows dated AFTER that annotation for that clause. A fixed root cause then ages out instead of accumulating forever; without this, resolved debt keeps counting and eventually crosses the threshold on stale rows.

**1.6 (project mode only) Read ALL ADRs in the repo's `docs/decisions/`, including `Superseded` ones.** Superseded ADRs carry the constraints and rejected alternatives that shaped the current state; skipping them means re-proposing patterns already tried and rejected. (Global mode reads no project ADRs.)

---

## Phase 2: JUDGE

**2.1 Cluster.** Group Source-B candidates by topic (read bodies; don't trust slugs). Then check **cross-source clusters**: a queue candidate + instinct(s) on the same topic are ONE cluster, and get higher routing priority, two weak signals from independent streams are strong evidence. (Worked example: Appendix C.)

**2.1b Semantic conflict scan (added 2026-07-15).** After clustering, run one pass reading candidate BODIES for pairs that give **opposing guidance on the same situation**, not slug overlap, actual contradiction (e.g. "do only what's asked, don't bundle" vs "proactively audit the whole surface"; "assume-and-proceed" vs "never assume, enumerate first"). These usually are not hard contradictions but **boundary-not-yet-drawn** pairs: each is right in a different context. Do NOT resolve them yourself and do NOT silently pick one. Surface every apparent-conflict pair in PROPOSE (new section 3.2b) with: both candidates' one-line claims, the situation where they collide, and the **context axis** you think separates them, then let the user draw the boundary or supply more context. This is the conversation-stream analog of the Conflict gate (2.2 gate 3), which only scanned against existing rules; this scans candidates against each OTHER.

**2.2 Apply the four gates, in order.** Failing a gate stops promotion; it is not retried at a higher tier. These gates apply to EVERY durable-write candidate, rules AND memory alike (a memory write is not exempt because it's cheap).

1. **Source gate.** Candidate must carry attributable source facts (`project_id` / `captured_from_session` / `proposed_scope`). Unattributable goes to defer. Landing in the root inbox confers nothing.
2. **Confidence gate.** Stamp `routing_confidence` here (it is /evolve's judgment, never capture's): **high** = clearly cross-project-general OR recurs in >= 2 agreeing projects/sessions OR the user meta-corrected it; **medium** = plausible but single-instance; **low/unclear** = scope unattributable. Only **high** may proceed toward a global write. If you can't state in one sentence why a candidate is high, it isn't: defer.
   > **Recurrence gates corrections to rules; transferability gates frameworks to memory. Never gate a framework on recurrence.** The "single-instance, defer" bar is calibrated for behavioral corrections (>= 2 occurrences confirm systemic, not one-off). It does NOT apply to `delight-aha-framework` / most `delight-claude-move` candidates: a transferable lens is valuable on first articulation, it's an insight, not a flaky pattern. Treating an aha like a flaky test silently drops the highest-value signal this command exists for. Single-instance frameworks judged transferable + durable ARE `high` for the memory channel.
3. **Conflict gate (a VETO, not a score).** Scan other projects' memories/candidates/instincts AND existing `rules/` for a contradicting entry. Asymmetric: ONE genuine counterexample refutes "globally true" regardless of how many agreements exist. A conflict vetoes global promotion, reclassify `context-dependent`, hand to Scope gate. **Conflict with an existing global rule must be surfaced loudly in PROPOSE**, never silently write a contradiction; resolution (scope down the old rule vs project-scope the new one) is the user's call.
4. **Scope gate.** Cleared 1 to 3 + high + cross-project + no conflict goes to **global**. High but project-specific, or conflict-vetoed, goes to **project** (context-dependent, boundary noted), **written only after explicit user confirmation**. Medium/low/unclear or unresolved conflict goes to **defer** (stays in root inbox; only a high-confidence project-specific candidate moves to that project's queue).
5. **Aging gate, the exit from `defer`.** A candidate is `rejected("insufficient evidence")` and archived to `.processed/` when **all three** hold:
   - it has been logged `deferred` **at least 3 times** in `.evolve-decisions.jsonl`, AND
   - its **first appearance** (`captured_at`, else the date in its filename) is **more than 3 months** before this run, AND
   - it has **never accumulated a second instance** (no sibling candidate on the same topic, no `repetition_count` of 2 or more, no `recurrence_of` pointing at it).

   **Both the count and the elapsed time are required.** The defer count alone is not enough because /evolve's cadence varies: 3 defers can mean three weeks for one user and three months for another. The age alone is not enough because a candidate captured long ago but judged only once has not yet been given three chances. Frameworks are **exempt**, since gate 2's carve-out says they never gated on recurrence in the first place, so "no second instance" is not evidence against them.

   Why this gate exists: without it, `defer` is a channel with no exit. Every run re-reads, re-judges and re-defers the same candidates, spending judgment on an unchanging batch while the queue grows monotonically. A single-instance correction defers *while waiting for recurrence*; three rounds with no recurrence **is** the evidence, not a still-open question. Archiving is not deletion: the file moves to `.processed/` and can be pulled back.

**2.3 Route each surviving cluster** with this tree:

```
Already covered by an existing rule / memory / SKILL / CLAUDE.md entry?
   -> route reject(covered). Do NOT silently drop it: this row feeds
     enforcement debt. ATOMIC (added 2026-07-15): the moment you judge
     a candidate "covered" you MUST, in the same step, stamp
     mapped_rule_clause + would_have_prevented (Appendix A fields).
     Classify-covered and stamp-debt are ONE action, never two: a
     covered judgment without the debt fields is an incomplete
     judgment, and is why debt sat at 0 for months (the stamp step
     was silently skipped every run). Archive to .processed/ at EXECUTE.

     MECHANICAL, not eyeballed (added 2026-07-25 after a real miss):
     the covered-check is an ON-DISK grep, seeded from the candidate's
     `topic:` slug, over EVERY store that governs behavior. A /evolve
     run reads no project code files, so the stores NOT loaded into this
     run's context are exactly the ones a from-memory guess can never
     catch. Grep ALL of these:
       - always-on rules: `~/.claude/rules/**/*.md` (no frontmatter)
       - PATH-SCOPED rules: the SAME `~/.claude/rules/**/*.md` files
         that DO carry `paths:` frontmatter (web/*, language dirs, and
         the scoped commons). These NEVER load during /evolve, so they
         are the sharpest blind spot, blinder than skills.
       - memories: `~/.claude/projects/*/memory/*` (all projects + global)
       - skills: `~/.claude/skills/*/SKILL.md`
       - CLAUDE.md (the one store that IS always in context)
     Guessing "covered" from a hardcoded rule-name list you hold in
     context is the convenient PROXY, not the check: it is structurally
     blind to skills, to path-scoped rules, and to project memories.
     That blindness is how a candidate canonically owned by a skill got
     re-proposed as a fresh memory write instead of logged as debt. A
     candidate covered by a skill, a path-scoped rule, or a project
     memory is still `reject(covered)` and still owes the debt fields.

"If-this-then-that" persistent principle?          -> RULE   (cheapest)
Nuanced preference / framework worth persisting?    -> MEMORY
Multi-step workflow the user would type /<name> for,
   AND >= 3 distinct steps, AND no existing skill?  -> SKILL
Complex separable specialist role?                  -> AGENT
Else                                                -> SKIP
```

Tiebreaks: rule-vs-memory goes to rule (auto-applied, more discoverable); memory-vs-skill goes to memory (cheaper). **Skill anti-bloat gate** (mandatory before proposing any skill): `ls ~/.claude/skills/ | head -50`, `grep -l "<topic>" ~/.claude/skills/*/SKILL.md`; similar skill exists, propose modifying it; fails any SKILL condition, demote to rule/memory. Skill spec: name kebab-case + collision-checked, location `~/.claude/skills/<name>/SKILL.md` (global only), description <= 130 chars.

**2.4 Pick scope + target file** for each RULE / MEMORY write. Scope was decided by the gates in 2.2, this step only picks WHERE, it must not relax the gates. In particular: **scope uncertainty is not resolved by "prefer global"; unclear scope was already deferred at the gate.** ("Prefer global" applies only to genuinely cross-cutting content that already cleared the Confidence gate as high.)

- **Global rule** goes to: list `~/.claude/rules/` subdirs (`common/`, `web/`, `python/`, `typescript/`, `golang/`, `swift/`, `php/`; skip `zh/`), pick the most domain-specific fit, read that subdir's file headings, pick the best-matching file. Then: new principle appends under the best heading; refines an existing entry, modify in place; duplicate, it should have routed `reject(covered)` in 2.3.
- **Project rule** goes to: repo root via `git rev-parse --show-toplevel`; target `<root>/.claude/rules/*.md` if that convention exists, else `<root>/CLAUDE.md`, else propose creating `<root>/CLAUDE.md`. (Write only after the user confirms, Scope gate.)
- **Memory**: reminder at the point of use, **a single-instance framework (`delight-aha-framework` / `feedback_framework_*`) does NOT need recurrence to route here**, transferability is its bar (gate 2's category-error note). Do not defer an aha "until it repeats." Then run the promotion audit:
  `grep ~/.claude/projects/*/memory/feedback*<similar-topic>*` + same against the global dir `~/.claude/projects/<your-home-project>/memory/` + **also** `grep -l <topic-words> ~/.claude/skills/*/SKILL.md` (a "memory" candidate is frequently already owned by a skill; skipping the skill grep is the 2026-07-25 miss).

  | Audit finds | Routing |
  |---|---|
  | Already owned by a SKILL (canonically) | route `reject(covered)` against that SKILL + stamp debt; if a project/global memory is a cruder duplicate of the skill, propose RETIRING that memory and pointing it at the skill, do NOT also write a rule |
  | Topic nowhere yet | Route by the gates' scope decision (2.2). `proposed_scope` is a hint for where to LOOK, never sufficient by itself for a global write. |
  | In 1 project memory + candidate from a different project | PROMOTE to global; propose merging/removing the old project entry in the plan table |
  | In 2+ project memories | AUTO-PROMOTE to global; propose archiving project entries (move, don't delete) |
  | Already in global memory | route `reject(covered)`, or propose modifying the global entry if the candidate adds real nuance |
  | Already in same project's memory | UPDATE-IN-PLACE candidate |

  Targets: global `~/.claude/projects/<your-home-project>/memory/feedback_<topic>.md`; project `~/.claude/projects/<project_id>/memory/feedback_<topic>.md`. Filename prefixes by candidate type: correction-D1 to `feedback_<topic>.md`; correction-D2 to `feedback_self_<topic>.md`; delight-D1 to `feedback_reinforce_<topic>.md`; delight-D2 to `feedback_framework_<topic>.md`. Body shape:

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

  After any memory write (at EXECUTE), append an index line to the `MEMORY.md` in the same directory.

**2.5 Projected enforcement debt.** Take the historical per-clause counts from 1.5 (already split by triage and windowed) and ADD this run's provisional `reject(covered)` classifications (with `would_have_prevented=yes`) from 2.3, splitting THOSE by triage too. Then route by which triage bucket dominates the clause, never off the raw total:
- **steerability** count reaches **~3-4** -> a **hook / decompose graduation candidate** (prose is not holding; propose the Appendix B fork).
- **plumbing** dominates -> a **loading-fix candidate** (the rule was never delivered to context; fix delivery, do NOT propose a hook).
- **over-scoping** dominates -> a **narrowing/de-escalation candidate**.

Graduation/loading/narrowing proposals go into PROPOSE's Enforcement-changes section, never auto-rewrite a rule. When a proposal fixes a root cause, its EXECUTE step must write the `annotation` + `resolves_clause` row (per 1.5) so the clause's pre-fix debt ages out.

---

## Phase 3: PROPOSE (the only ask)

**3.0 Pick the review surface (added 2026-07-25).** If the run proposes more than ~7 rows across all tables, render the whole PROPOSE surface as a review board: a self-contained HTML page (collapsed/expandable rows, a sticky decision nav, a tally whose buckets carry their dispositions, a ledger of past runs read from the decision log), following the design in `docs/REVIEW-BOARD.md`. Assert the row counts before publishing, and add no how-to prose. The approval still comes back in ONE message; the page is for reading, never for collecting input. The chat-table fallback is capped at ~7 rows: batch anything longer into several readable approval rounds rather than compressing rows below the point where a proposal can be judged.

**3.1 Plan table(s)**, one GLOBAL table, then one table per project with candidates (each its own go/skip, per the Modes note). One row per proposed artifact write. **Every row MUST carry a plain-language description and a confidence with its reason** (added 2026-07-15), without them the user is judging a category label, not an actual proposal, and cannot tell what they are approving or how strongly it is held:

| # | What I'm proposing / what you're judging | Confidence (+ why) | Decision | Target | Source items |
|---|---|---|---|---|---|
| 1 | Make "always validate user input at boundaries" a standing rule, so any new endpoint/handler gets input validation by default. You're judging: is this a real cross-project default, or over-broad? | **high**, recurs in 3 projects + matches an instinct | RULE to global | `~/.claude/rules/common/coding-style.md` (append under "Input Validation") | instinct: validate-form-input + correction-validate-everything-20260520 |
| 2 | Hold the framework "use grounded analogies when explaining systems" as a memory, so future explanations reach for a concrete parallel. You're judging: is this transferable, or a one-off nicety? | **medium**, single articulation, but frameworks route on transferability not recurrence | MEMORY to global, framework | `.../memory/feedback_framework_grounded_analogies.md` (create) | delight-aha-framework-grounded-analogies-20260522 |

**Column rules.** `What I'm proposing / what you're judging`: 1-2 plain sentences, what the durable artifact would DO in future sessions, plus the specific judgment call handed to the user. No jargon-only category labels. `Confidence (+ why)`: `high` / `medium` / `low`, each with a one-clause reason keyed to the Confidence gate (2.2 gate 2): `high` = cross-project-general OR recurs >= 2 OR the user meta-corrected; `medium` = plausible single-instance / framework-on-first-articulation; `low` = would normally defer, shown only if surfaced deliberately. The confidence is /evolve's semantic judgment against the gate, not a computed score, stating the reason is what keeps that judgment out of Claude's head and in front of the user. **Never silently pre-trim rows Claude feels lukewarm about**, show them with `low`/`medium` and let the user decide; hiding them is the exact opacity this column exists to kill.

Below each table, show one diff per row (the actual content to be appended/modified/created).

**Size rule (added 2026-07-20).** Cap any single review surface at roughly **7 rows**. Past that,
either batch it into several asks, or render the whole surface as a page instead (see
[docs/REVIEW-BOARD.md](../docs/REVIEW-BOARD.md)). The failure this prevents is not "the table is
long", it is what a long table pushes you into: compressing each row until the user is approving a
category label rather than a proposal. If the rows do not fit, there are too many rows on screen,
not too many words in a row.

A large run (dozens of proposed writes) should default to the board. It is one self-contained HTML
page with a collapsed summary row per write and the full evidence one click away, which is the only
arrangement where detail and scannability are not zero-sum. The approval still comes back as one
chat message.

**3.2 Enforcement changes** (separate section, these are NOT candidate-routing rows; approving a ladder climb is a different decision from approving a memory write):

| Rule clause | Debt (hist + this run) | Current rung | Proposed rung | Proposed change |
|---|---|---|---|---|
| `your-rule.md#specific-sub-clause` | 3 + 1 | 2 (decision-question) | 3 (checklist gate) | <one-line description> |

Omit the section when there are no graduation candidates.

**3.2b Apparent-conflict pairs** (from the 2.1b semantic scan; separate section, resolving a boundary is the user's call, not a routing row):

| Candidate A (claim) | Candidate B (claim) | Where they collide | Context axis I think separates them | Your boundary |
|---|---|---|---|---|

For each pair, propose the separating axis but leave the last column for the user. Omit the section when the scan found no apparent conflicts (but per safety-threshold 2, "found none across >= 2 projects" means re-scan reading bodies, not pattern-match).

**3.3 Routing Review Report**, one row per candidate evaluated this run:

| candidate_id | source project/session | proposed_scope | routing_confidence | conflict_scan_result | final_route | reason | confirm? |

`conflict_scan_result`: `none` | `conflict-with-project:<name>` | `conflict-with-global-rule:<file>` | `boundary/context-dependent`. `final_route`: `global-rule` | `global-memory` | `project-rule` | `project-memory` | `context-dependent` | `defer` | `reject(covered)` | `keep-as-instinct`. `confirm?` = `yes` for any project write or surfaced conflict.

Plus an **audit sample**: 5 random candidates shown with full body + frontmatter + decision + reason, so the user can spot a mis-route without reading every row.

Plus **metrics** over the eligible base (`eligible = evaluated - reject(covered)`; covered rows are archives/no-ops, not promotions, excluding them from BOTH numerator and denominator per the user's 2026-06-27 call):
- `rule_promotion_rate` = global-rule writes / eligible, the 30% guard applies here
- `memory_promotion_rate` = global-memory writes / eligible, informational, NOT gated at 30%: frameworks-to-memory is the designed path (see the category-error note in gate 2), so a framework-heavy batch legitimately shows high memory promotion
- `defer_rate`, `conflict_surfaced_count`, `project_confirmation_count`, `user_correction_count`

**3.4 Safety thresholds** (checked BEFORE asking; a trip pauses or downgrades, never silently proceeds):

1. `rule_promotion_rate > 30%` goes to PAUSE and explain; the global-rule bar should rarely clear that many at once. List what's being promoted, ask the user to confirm or trim.
2. Zero conflicts found across a batch spanning >= 2 projects, the scan was probably too shallow; re-run it reading actual entries, not pattern-matching.
3. **Any project rule/memory write without explicit user confirmation, hard block.** No confirmation, stays `defer`. (Third statement of this invariant, deliberately: it is the highest-blast-radius mistake this command can make.)
4. Confidence not explainable in one sentence, `defer`.

**3.5 Ask once, per table:** present the whole surface (global table + each project's table + enforcement-changes + apparent-conflict pairs), then ask for a **separate go/skip per table**, e.g. "GLOBAL: apply all / skip rows? · project=my-app: apply all / skip rows? · ...". One review surface, but each scope confirmed in its own context (never one blanket yes across global + N projects, safety-threshold 3). Also collect the user's boundary answers for any 3.2b conflict pairs. Wait; apply only approved rows; ask nothing else.

---

## Phase 4: EXECUTE

**4.1 Write approved artifacts** (rules, memories + their MEMORY.md index lines, skills, enforcement-change edits). Show each resolved path.

**4.2 Disposition every candidate**, consistent semantics (this also fixes an old contradiction where user-skipped rows were logged `rejected` yet left queued for reprocessing):
- Fed an approved write, move to `.processed/`, log `accepted`.
- `reject(covered)` or SKIP-judged, move to `.processed/`, log `rejected`.
- **The user excluded the row in review**, stays in queue, log `deferred` with reason `"user excluded in review"` (defer = will be seen again; if the user wants it gone, delete on their confirmation).
- Deferred by gates, stays in queue, log `deferred`.
- Instinct YAMLs are never auto-deleted; list their paths so the user can `rm`.

**4.3 Log EVERY candidate evaluated this run**, one JSONL row each, appended to `~/.claude/pending-evolve/.evolve-decisions.jsonl`, schema in Appendix A (locked; the review script depends on it). Not optional: this log is the only Layer-2 eval signal for the upstream capture skills, and the only place enforcement debt accumulates. On `reject(covered)` rows, the `mapped_rule_clause` + `would_have_prevented` fields are what make 1.5/2.5 possible next run, never omit them.

**4.4 Run the review summarizer:**

```bash
~/.claude/scripts/review-evolve-signals.sh --mark-reviewed
```

It aggregates accept/reject/defer rates per `skill_source` since the last cutoff and alerts when any **reject** reason appears >= `EVOLVE_ALERT_THRESHOLD` (default 10) times in the window (rejects only, the script does not threshold accept/defer reasons). Fold the output into the final summary: healthy, one line; alert, name (a) which capture skill is producing noise, (b) the recurring reject reason, (c) which acid test to tighten. Note: a wave of `"covered by existing rule"` rejects is NOT capture noise, it is enforcement debt; read it via Appendix B, don't tighten capture for it.

**4.5 Final summary** with complete bucket accounting (Core principle 4): accepted / rejected / deferred / kept-as-instinct counts that sum to evaluated, defer residual named, queue count after the run, plus the review-script line.

---

## Appendix A: `.evolve-decisions.jsonl` row schema (LOCKED, contract with review-evolve-signals.sh)

```jsonl
{"candidate_file":"correction-foo-20260522-173500.md","skill_source":"correction-capture","decision":"accepted","decision_reason":"cross-source cluster","tags":["type=correction","direction=D1","topic=foo","scope=global"],"confidence":0.9,"evolve_session_at":"2026-05-23T15:30:00Z"}
```

- **`candidate_file`**: basename. One row per file (queue `.md` or instinct `.yaml`). Cross-source clusters: one row per involved file, same decision/reason/timestamp, linked by a `cluster_id=<run-uuid>` tag.
- **`skill_source`**: `correction-capture` (prefix `correction-`) | `delight-capture` (prefix `delight-`) | `continuous-learning-v2` (instinct YAML).
- **`decision`**: `accepted` (fed a persisted write) | `rejected` (covered / SKIP-judged) | `deferred` (stays in queue, including user-excluded rows, see 4.2) | `annotation` (a maintainer note attached to the log, not a candidate outcome, e.g. classifying a prior alert as benign/convergence-reject; excluded from accept/reject/defer rate math).
- **`decision_reason`**: canonical phrases only (aggregation is string-equality; extend conservatively).
  - Reject: `"too narrow"`, `"one-off implementation choice"`, `"performative self-criticism"`, `"duplicate of existing memory"`, `"insufficient evidence"`, `"out of scope"`, `"covered by existing rule"`
  - Defer: `"singleton awaiting cluster"`, `"low confidence, watching"`, `"needs human judgment"`, `"evidence in 1 project only"`, `"user excluded in review"` *(recategorized from Reject on 2026-07-07: excluded rows stay in queue, which is defer semantics)*
  - Accept: `"cross-source cluster"`, `"high-confidence instinct"`, `"explicit meta-correction"`, `"reinforced across sessions"`, `"auto-promote to global"`, `"framework transferable on first articulation"`, `"clear single-stream signal, well-articulated rule"`
- **`mapped_rule_clause`** (enforcement-debt field, ONLY on `"covered by existing rule"` rows): the specific clause duplicated, as `<rule-file-basename>#<short-clause-slug>` (e.g. `your-rule.md#specific-sub-clause`), the sub-behavior, not the whole file. Omit elsewhere.
- **`would_have_prevented`** (ONLY on covered rows): `yes` | `no` | `unclear`, would that rule, *if actually followed*, have prevented this failure? A counterfactual, not topical relatedness. Only `yes` counts toward debt; `no`/`unclear` guard against graduating the wrong rule on false attribution. Omit elsewhere.
- **`triage`** (in `tags` as `triage=<v>`, on covered rows, added 2026-07-25): `plumbing` (the covering artifact was never IN context when the mistake happened, e.g. a skill or path-scoped rule that did not load, or a routing-audit that did not scan it) | `steerability` (it WAS in context, ignored anyway) | `over-scoping` (it fired on a legitimately-different case, no real harm). 1.5/2.5 route by this: only `steerability` drives a hook graduation. Stamp it from the candidate's own triage frontmatter (`covering_artifacts`, `rule_in_context`, `acknowledged_then_violated`) or infer from the body, but **do NOT take a candidate's self-stamped `steerability` at face value.** Re-ask step 0 yourself: does the operative step live in an on-demand skill or a path-scoped rule that was not loaded? If so the row is `plumbing`, whatever the candidate said. A capture-time stamp can only see the artifact the capture happened to name; a run that reads all five stores on disk can see the one it missed. When a candidate's evidence matches no row it must arrive as `triage=unclear`, never as a defaulted `steerability`, because a defaulted label is biased toward the most expensive fix (a hook), so treat an unexplained `steerability` as unstamped. Anchor: 26 candidates across 8 projects self-stamped `steerability` against an always-on rule that was genuinely loaded, while the operative step sat unloaded in an on-demand QA skill; the whole cluster was plumbing, and taking the stamps at face value would have bought a hook for a rule that was never delivered.
- **`resolves_clause`** (ONLY on `decision:"annotation"` rows, added 2026-07-25): `<mapped_rule_clause>`, records that this run fixed a root cause for that clause (a loading fix, a hook, a narrowing). 1.5 counts only covered-rows dated AFTER this annotation for that clause, so resolved debt ages out instead of accumulating on stale rows.
- **`tags`**: `key=value` strings from frontmatter; best-effort `type=`, `direction=`, `topic=`, `scope=` (legacy rows may omit them, the generator now emits them so new rows comply; do not retro-fill old rows); clusters add `cluster_id=`.
- **`confidence`**: 0.0 to 1.0. 0.9+ = cross-source cluster / user meta-correction / 3+ projects; 0.7 to 0.85 = clear single-stream; <0.7 = usually defer instead.
- **`evolve_session_at`**: ISO 8601 **UTC Z-form only** (`date -u +"%Y-%m-%dT%H:%M:%SZ"`, generated once per run). The review script's `jq fromdate` parses only Z-form; a local-offset timestamp breaks aggregation silently.

Append protocol: one `echo '<row>' >> ~/.claude/pending-evolve/.evolve-decisions.jsonl` per row; append-only, never rewritten; partial logs from crashed runs are fine (unlogged candidates stay queued and re-process next run). Why log everything, not just rejects: accept-rate per skill shows which capture skill is well-calibrated (<30% accept, tighten its acid test); repeated defer-without-resolution shows a threshold problem. The schema is forward-extensible (jq reads known fields); document any new field here AND update the script if aggregation should use it.

## Appendix B: Enforcement debt: triage first, then fork by mechanizability (rewritten 2026-07-15)

A `"covered by existing rule"` candidate is NOT noise, it is a **failed activation**: a rule existed and was violated anyway. Recurrence-despite-a-rule is the highest-value signal that a rule is prose-in-name-only. Keep capturing them, archive them as covered, but mine them first (1.5 / 2.5).

Debt per clause = count of covered rows with `would_have_prevented=yes`, grouped by `mapped_rule_clause`. Projected debt (historical + current run) reaching **~3-4** makes the clause a graduation candidate (surface in 3.2). Never auto-rewrite a rule; propose, let the user decide.

**The 2026-07-09 run falsified the old single 7-rung ladder** (one direction, debt-high, climb-more-mechanical). It was wrong twice: (a) it assumed every rule can climb toward a hook, but pure-judgment rules cannot be made deterministic; (b) it assumed recurrence always means under-enforced, when it can mean the rule is too broad. The model below replaces it.

### Step 1: TRIAGE the failure before doing anything (debt is 3-dimensional, not a scalar)

The same symptom ("rule violated") has three distinct causes needing opposite fixes. The capture skills stamp triage signal at capture time (was the rule in context? acknowledged-then-violated? a legitimately-different case?); use it, or infer from the candidate body:

| Cause | Signature | Fix direction |
|---|---|---|
| **Plumbing**, the artifact holding the OPERATIVE step was never IN context that turn | path-scoped rule not reloaded after `/compact`; nested rule never injected; context evicted it; **or the principle is split across surfaces, with the judgment in an always-on rule and the action in an on-demand skill that never loaded** | Fix LOADING, not the rule. Hardening a rule that wasn't delivered is pointless. (Verify with an `InstructionsLoaded`-style audit of what was actually loaded at violation time.) |
| **Steerability**, rule WAS in context, ignored anyway | loaded + acknowledged + violated | Move to a real enforcement point (Step 2). This is the only cause the old ladder addressed. |
| **Over-scoping**, rule fired on a legitimately-different case | recurrence with NO real harm; the "violation" was actually correct behavior | **De-escalate**: narrow the rule's trigger/scope, or demote its severity. A bigger hammer here is the wrong fix. |

Only **steerability** debt escalates. Plumbing debt routes to a loading fix. Over-scoping debt routes to a de-escalation/narrowing proposal. Misclassifying the last two as steerability is how a system over-hardens rules that were never the problem.

### Step 2: For steerability debt, FORK by mechanizability (not one ladder)

Different rule shapes get different enforcement homes. Pick by "can this be checked, and how":

| Rule shape | Enforcement home | Why |
|---|---|---|
| **Deterministically checkable** (banned phrase, "run `git rev-list` before saying 'pushed'", file-exists) | **Deterministic hook / linter / permission-deny** (`PreToolUse`, exit 2) | A regex/command settles it; 100% reliable, no model needed. Anthropic's own line: prompts are context, hooks are enforcement. |
| **Judgment, not mechanizable** ("is this claim backed by a check that could have failed", "does the copy lead with the reader's pain") | **`prompt`-type or `agent`-type hook**, put the judgment rule text in the hook's `prompt`; a cheap model judges it at each matching tool event | This is the key 2026-07-15 addition. The old plan compressed judgment to a prose line and put it BACK in CLAUDE.md, the same "context not enforcement" bucket that caused the recurrence. A prompt-hook gives the judgment call a real enforcement point without forcing false decomposition. (Official: `{"type":"prompt","prompt":"...","model":"...","timeout":30}`. `type:"agent"` when the check must inspect files first.) |
| **Bounded to a file type / domain** (only matters when touching CSS, or migrations, or a repo) | **Path-scoped rule** (`paths:` frontmatter) | Loads only when relevant, frees always-on attention budget (instruction count trades off linearly against compliance). A third option between always-on prose and a hook. |
| **Genuinely cross-cutting judgment, could fire on any task** (verify-before-claiming, communication register) | **One sharp always-loaded line** + optionally a prompt-hook if debt persists | These have no natural glob and can't be deterministic. Keep them short (every extra always-on clause dilutes the rest) and, if they keep failing, back them with a prompt-hook rather than a longer prose rule. |

**Decompose bundles, don't climb them.** A rule that is really N sub-behaviors (e.g. a verify rule's many accreted trigger-shapes) is not one rung to climb, split it: hook the mechanizable sub-clauses individually, path-scope the domain-bounded ones, leave only the irreducible-judgment core as prose (backed by a prompt-hook if needed). "Add trigger-shape #N+1" is the anti-pattern this replaces.

### Verify the intervention + de-escalation is real

"Did it work" = the same `mapped_rule_clause` stops appearing with `would_have_prevented=yes` in later windows, a query over the same log, not a new system. This works for de-escalation too: a narrowed over-scoped rule should stop generating covered-rows-with-no-harm.

**Cross-check the classification (research-confirmed):** Anthropic's own docs state CLAUDE.md is "context, not a hard enforcement layer" and closed "rules not enforced" issues as *not planned*, so a rule violated >= 2 times is expected behavior for prose, and the triage/fork above (not a third prose rewrite) is the correct next move. Evidence-cited rules (each rule carrying its ground-truth incident) resist silent deprioritization; keep that.

**Explicitly deferred machinery (build only when its trigger fires):** weighted/decayed scoring (trigger: debt data outgrows eyeballing a count); synthetic probes + adversarial regression suite (trigger: something reaches a deterministic hook and must be guarded from regression); a meta-critic on /evolve's own classifications (trigger: observed mis-routing); an infra-level policy proxy that enforces across all projects/subagents regardless of whether a rule was loaded (trigger: you want cross-project enforcement, not per-repo). At solo scale most are net-negative, small-N scoring is statistical theater, upkeep lands on one person. This is the same build-vs-preserve restraint the system applies to itself.

## Appendix C: Cross-source clustering example

Tool-call stream: instinct `prefer-setProperty-over-inline-important` at 0.6 (borderline). Conversation stream: `correction-no-inline-important-20260518.md` (single moment, low standalone weight). Each alone would SKIP. Together they cluster to RULE, global, `~/.claude/rules/web/css-conventions.md`, both sources cited in the row's Source-items column. Capture stays cheap on both sides; judgment compounds at the one surface that sees both.

## Appendix D: Provenance, design history, local-override note

**vs upstream ECC `/evolve --generate`:** ECC auto-writes evolved skill files per cluster with no review, reads instincts only, has no rule/memory channels, doesn't audit existing artifacts, and trends skill-shaped (growing per-conversation token cost). This variant reads two sources, adds rule+memory channels, audits before creating, prefers cheaper artifacts, and gates everything behind one approval.

**Design history:** routing modes + four gates + per-project queues added 2026-05-25 (before them, a mixed queue was blind-routed globally; the gates make default-defer the safe baseline). Routing Review Report + safety thresholds added 2026-05-25. Covered-excluded metrics base + rule-vs-memory rate split: 2026-06-27. Enforcement-debt fields + ladder: 2026-07-05 (the user's reframe: if a candidate is already covered yet the same failure recurs, that recurrence is itself a signal). Restructured into phases + contradiction fixes (inbox wording, uncertain-to-defer, covered-logged-not-ignored, excluded-to-deferred): 2026-07-07, after adversarial review with a second model.

**Local override:** this file lives at `~/.claude/commands/evolve.md`, NOT the marketplace copy. If an ECC update ever overwrites it, restore from backup, the pending-evolve / memory / enforcement-debt layers are local, not upstream.
