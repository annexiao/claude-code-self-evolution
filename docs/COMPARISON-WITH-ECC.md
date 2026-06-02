# What this project adds to ECC

This project stands on the shoulders of [ECC (everything-claude-code)](https://github.com/affaan-m/ECC)
by Affaan Mustafa. ECC's instinct system is the foundation: a hook watches every
tool call, a small observer model distills repeated patterns into confidence
weighted "instincts", and an `/evolve` command turns instincts into reusable
skills/commands/agents. That engine is vendored here under
`engine/continuous-learning-v2/`, essentially unchanged.

What follows is the precise diff: what this project adds, and why.

## At a glance

| Dimension | ECC (upstream) | This project |
|---|---|---|
| Learning input | Tool-call patterns only (the observer hook) | Tool-call patterns **plus conversation signal** (corrections + endorsements) |
| What gets captured | What you *did* (Edit, Bash, Grep sequences) | What you did **plus what you said**: when you corrected Claude, when you endorsed a move, when a framing landed |
| `/evolve` output channels | skill / command / agent | **rule** and **memory** added as first-class outputs, in front of skill/agent |
| `/evolve` default bias | Tends to generate skills | **Cost-aware**: prefers the cheapest reversible artifact (rule) over the most expensive (skill) |
| Promotion logic | Confidence threshold + cross-project recurrence | **Four gates** (Source, Confidence, Conflict, Scope); conflict is a hard **veto**, not an averaged score |
| Confidence dynamics | Recurrence raises it | Recurrence raises it, **time-decay lowers it**, **semantic conflict vetoes** promotion |
| Review | Auto-writes on `--generate` | **Single human-approved gate**: nothing durable is written without one unified review |
| Eval | (not built in) | Every `/evolve` decision logged to jsonl, becomes a **free labeled corpus** to grade the capture skills |
| Confidence decay | LLM prompt rule ("minus 0.02/week") | **Deterministic Python script** (LLMs should not do arithmetic) |

## The four additions, in detail

### 1. A second capture stream: conversation, not just tool calls

ECC's observer hook (`observe.sh`) records tool calls. It does not see your
words. So the richest learning signal in a coding session, **the moment you say
"no, don't do it that way"**, evaporates at session end.

This project adds two session-end capture skills that read the conversation:

- **`correction-capture`** captures corrections in two directions:
  - **D1**: you corrected Claude ("too long", "don't set !important inline", "以后都这样").
  - **D2**: Claude caught *itself* ("I conflated A and B", "I should have read the file first"). Claude has access to its own reasoning trace and can flag patterns you never even saw.
- **`delight-capture`** captures the positive polarity, also in two directions:
  - **D1**: you endorsed a specific move worth replicating.
  - **D2**: a framing reframed someone's thinking (an "aha"), worth holding as a transferable principle.

That is the **2x2 capture matrix** (polarity x source). The tool-call stream and
the conversation stream stay in separate storage and **converge only at `/evolve`**,
where a tool-call instinct and a conversation correction about the same topic can
cluster into one stronger signal. Neither stream alone could see that cluster.

### 2. Capture is cheap and dumb; judgment is deliberate and singular

ECC's `/evolve --generate` can write artifacts directly. This project enforces a
strict **capture-vs-judgment separation**:

- The capture skills are **dump-only**. They never propose, never write to
  memory, never interrupt you. They append a candidate file to a queue and exit.
- `/evolve` is the **single judgment surface**. You trigger it when you want to.
  It clusters everything, routes each cluster, and presents **one** review table.

Why: it batches your review burden into one moment instead of a prompt after
every session, and it concentrates every accept/reject decision through one gate,
which (see point 4) turns out to be free eval data.

### 3. Cost-aware routing into rules and memory, not just skills

ECC tends toward skill-shaped output. But a skill costs system-prompt tokens in
**every** session forever, and reversing one means deleting a file *and* living
with the token cost you already paid. So this project adds a **cost hierarchy**
and biases `/evolve` toward the cheap, reversible end:

```
rule  <  memory  <  command  <  skill  <  agent
cheapest, loaded only          ~37 tokens every    own context
when context matches           session forever      window
```

- An "if-this-then-that" principle ("always validate input at boundaries") becomes a **rule** (a few lines of markdown, loaded only when relevant).
- A nuanced preference learned in conversation ("reach for grounded analogies when explaining systems") becomes a **memory** entry.
- Only a genuine multi-step, user-invoked workflow clears the **skill** anti-bloat gate.

`/evolve` makes this call itself and only asks you once, at the end.

### 4. Four-gate promotion: counting contradiction, not just agreement

ECC promotes on recurrence and confidence. This project routes every candidate
through **four gates in sequence**, and the third one is the key addition:

1. **Source**: where did this come from? Unattributable to scope, defer.
2. **Confidence**: high (cross-project-general, or recurs in 2+ contexts, or you meta-corrected it) may proceed; medium/low defers.
3. **Conflict (a VETO, not a score)**: scan other projects and existing rules for a counterexample. **One genuine counterexample refutes "globally true" and vetoes global promotion**, no matter how many agreements exist. A candidate that contradicts an existing global rule is surfaced loudly, never silently written.
4. **Scope**: global rule / project rule / context-dependent / defer.

The insight: a learning system that only counts agreement slowly grows an
internally contradictory ruleset. Treating conflict as a hard veto (asymmetric
with agreement) keeps **default-defer** as the safe baseline.

Confidence therefore has **three change-axes**, not one: recurrence raises it,
the weekly decay script lowers it, and conflict vetoes it outright.

### 5. The judgment log is the eval corpus (free)

Because every candidate funnels through one `/evolve` decision, logging that
decision (accept / reject / defer + reason) to `.evolve-decisions.jsonl` yields a
**labeled corpus at zero marginal cost**. `review-evolve-signals.sh` aggregates
it: if `correction-capture` keeps producing candidates rejected as "too narrow",
that is a signal to tighten its acid test. The eval loop closes itself with no
separate framework.

## What was changed inside the vendored engine

Exactly one thing: the **confidence-decay rule was removed from the observer
prompt** (`agents/observer.md`) and reimplemented as a deterministic script
(`scripts/apply-instinct-decay.py`). Asking an LLM to subtract 0.02 per week is
asking it to do arithmetic it does less reliably than four lines of Python.
Everything else in `engine/continuous-learning-v2/` is ECC's, as-is.

## Credit

ECC is the foundation this is built on, and the instinct/observer design is
entirely Affaan Mustafa's. If you want the tool-call learning engine on its own,
use [ECC](https://github.com/affaan-m/ECC) directly. This project is the
conversation-capture + cost-aware-judgment layer on top.
