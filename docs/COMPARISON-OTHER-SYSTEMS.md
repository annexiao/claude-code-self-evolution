# How this compares to other self-evolving agent systems

"Self-evolving agent" covers a wide range of designs. This page places
claude-code-self-evolution among five well-known points in that space, and is
honest about where the ideas overlap (so nothing here overclaims novelty).

| System | What evolution means | Substrate | Human-in-loop | Fine-tunes weights? | Cost-aware? | Conflict handling |
|---|---|---|---|---|---|---|
| **Hermes Agent Self-Evolution** (NousResearch) | Reflective prompt/skill rewriting: reads execution traces, proposes targeted mutations to SKILL.md files, tool descriptions, and system-prompt sections via DSPy + GEPA (Genetic-Pareto) | Markdown skill files, tool-description strings, prompt sections in a git repo; changes shipped as pull requests | Yes: mandatory ("all changes go through human review, never direct commit"), plus constraint gates | No (API-driven mutation, not weight updates) | Partial: tracks per-run dollar cost as a budget signal, but no cheapest-artifact routing; it only writes one artifact type | Constraint gates (tests + semantic-preservation) reject bad mutations; multi-objective Pareto selection, not a single-counterexample veto |
| **Sepo** (self-evolving/repo) | Capability accrual via persistent memory + a user-invokable skill library + task orchestration inside GitHub | Repo-owned git branches: `agent/memory` and `agent/rubrics` | Yes: human-initiated (mention or label), authorization-gated | No | No artifact-cost tiering | Rubrics encode preferences; no explicit conflict-detection or veto |
| **OpenAI Cookbook: Autonomous Agent Retraining** | Eval-feedback-driven prompt rewriting: graders score output, a metaprompt agent rewrites the system prompt, re-tested immediately | The prompt text itself, versioned via a `VersionedPrompt` class | Both: an SME-reviewed loop, or a fully automated loop that only alerts a human when guardrails trip | No (despite the name, it rewrites prompts, no weight fine-tuning) | No: cost is not a routing dimension | Grader pipeline gates a new prompt; up to 3 retries then escalate; aggregate-score selection, no single-counterexample veto |
| **A Survey of Self-Evolving Agents** (CharlesQ9, arXiv 2507.21046) | Not a system: a taxonomy of the field (what / when / how / where to evolve) | N/A (survey) | Covers both autonomous and human-feedback methods | Covered as one category among several | Not a primary axis | Discusses safety and co-evolution as open challenges; no prescribed mechanism |
| **EvoMap** (evomap.ai) | Cross-agent knowledge inheritance: "one agent learns, a million inherit", agents publish reusable capsules others reuse | Cloud Knowledge Graph + "Capsule Market"; Agent-to-Agent protocol | Reduced: agent-to-agent loop with governance framing | No (shares artifacts, not weights) | Yes, in a different sense: optimizes reuse economics (tokens saved, hit rate) and monetizes capsules | Popularity ranking / leaderboard surfaces what reuses well, not semantic-conflict vetoes |
| **claude-code-self-evolution** (this project) | No-retraining behavioral evolution: real corrections + endorsements compound into the agent's instructions (global rules / project rules / memory / skills), gated by human review at one `/evolve` surface | Local, file-based: Haiku-distilled instincts (YAML) + session-end capture queues, promoted to markdown rules / memory / skills on disk | Yes, structurally: two cheap automatic capture streams write to queues only; one human-triggered `/evolve` promotes; no capture stream writes durable rules directly | No (weights never touched) | Yes, first-class: prefers the cheapest durable artifact (a context-loaded rule) over expensive ones (a skill that taxes the system prompt every session); reversibility drives the default | Conflict is a hard VETO: one counterexample refutes "globally true" and blocks promotion; confidence is 3-axis (recurrence raises, weekly decay lowers, conflict vetoes) |

## Where this project sits on the survey's map

The CharlesQ9 survey (arXiv 2507.21046) organizes the whole field along four
axes. Placing this project on each one is the fastest way to locate it:

| Survey axis | Routes the survey names | This project |
|---|---|---|
| **What** to evolve | Models (weights) / Memory / Tools / Architecture | **Memory + Tools** (rules, memory entries, skills). It never touches model weights or agent architecture. |
| **When** to evolve | Intra-test-time (mid-task) / Inter-test-time (between tasks) | **Inter-test-time**: evolution happens between sessions, at `/evolve`, never mid-task. |
| **How** to evolve | Scalar reward / Textual feedback; single-agent / multi-agent | **Textual feedback, single-agent**: it learns from natural-language corrections and endorsements, with a confidence weight layered on top (not an RL reward). |
| **Where** to evolve | Coding / Education / Healthcare | **Coding** (Claude Code). |

Two things worth noting from that placement:

- It deliberately avoids the two heaviest routes (evolving weights, evolving
  architecture). Those are the least reversible and hardest to govern; the whole
  value proposition rests on evolving only reversible behavioral instructions.
- The survey lists **safety and co-evolutionary dynamics as open challenges**.
  The conflict-as-veto gate, default-defer baseline, and human review gate are
  this project's concrete, if partial, engineering answer to that challenge.

## What makes this project distinctive

- **Capture-vs-judgment separation as an architecture, not a setting.** Two cheap automatic streams (a hook-fed observer distilling tool-call instincts; session-end correction/delight capture) only ever dump to queues. A single human-triggered `/evolve` is the lone surface that promotes anything durable. The closest peers (Hermes, the OpenAI cookbook) gate at the moment of writing one artifact type; none separate "notice cheaply and continuously" from "decide deliberately and rarely", nor fuse two independent signal streams at one judgment point.
- **Cost-aware artifact tiering driven by reversibility.** Routing prefers the cheapest durable form (a markdown rule loaded only when context matches) over the most expensive (a skill that taxes the system prompt every session forever). Hermes tracks dollars-per-run and EvoMap tracks tokens-saved, but neither chooses *which kind of artifact* to create based on its ongoing cost.
- **Conflict-as-veto rather than averaged score.** A single counterexample refutes a "globally true" claim and blocks promotion. Every other system here resolves disagreement by aggregation: grader pass-rates (OpenAI cookbook), Pareto fronts (Hermes/GEPA), or popularity rankings (EvoMap). A veto is categorically different from a weighted average.
- **3-axis confidence with time-decay.** Recurrence raises confidence, weekly decay lowers it, semantic conflict vetoes promotion. The decay axis (stale signals lose force automatically) is absent from all five; their version histories accrete monotonically.
- **Eval-as-byproduct, no separate harness.** Every `/evolve` accept/reject/defer is logged to jsonl and becomes a free labeled corpus for grading the capture skills. Hermes and the OpenAI cookbook run dedicated grader pipelines as a prerequisite to evolving; this project derives its eval corpus from the human's routing decisions, at zero extra cost.

## Where the ideas overlap (no overclaiming)

- **"Evolve the prompt/skill text, not the weights" is not novel.** Hermes and the OpenAI cookbook both do exactly this, and Hermes evolves the same artifact family (SKILL.md files, tool descriptions, prompt sections). The contribution here is the governance and routing layer (capture/judgment split, cost tiering, veto, decay), not the "no fine-tuning" idea itself.
- **A hard human review gate is shared, not unique.** Hermes ("never direct commit") and Sepo (authorization-gated) both gate on a human. The differentiator here is the *shape* of the gate: one batched judgment surface fed by cheap continuous capture.
- **Memory + rubrics as durable git-stored guidance is close to Sepo's model.** The difference is the explicit promotion pipeline (queue to gated `/evolve` to tiered artifact) versus direct curation.
- **Reflective trace-to-mutation (GEPA) appears in two of the five**, so that step is now prior art. This project's continuous, always-on instinct distillation differs in being passive rather than triggered per optimization run.
- **EvoMap is the genuine outlier**, cloud and cross-agent with a marketplace. It shares the word "evolution" but little else; this project is single-user, local, and private.
