# CLAUDE.md

Behavioral rules for Claude Code in the aeriea repository.

## North star

Aeriea (pronounced "area" — visual *aerie* / aural *area*) is an embodied modern-life sandbox built around 100% immersion as the single non-negotiable design goal. See `DESIGN.md` for the full design.

Two commitments carry north-star weight and shape how everything is built:

- **NSFW-first with SFW toggle** — all systems designed NSFW; SFW is a rendering layer, not a content rewrite.
- **Deterministic seeded simulation** — all simulation state derivable from seed + action log. No nondeterministic RNG outside the seeded timeline.

<!-- BEGIN ECOSYSTEM RULES -->

## Hard Constraints

- No `--no-verify`. Fix the issue or fix the hook.
- No path dependencies in `Cargo.toml` — they couple repos and break independent publishing.
- No interactive git (no `git rebase -i`, no `git add -i`, no `--no-edit` on rebase).
- No suggesting project names. LLMs are bad at this; refine the conceptual space only.
- No tracking cross-project issues in conversation — they go in TODO.md in the affected repo.
- No assuming a tool is missing without checking `nix develop`.
- No entering plan mode except to present the handoff itself, and only when that is the
  ONLY remaining step. Subagents spawned from inside plan mode can only write their own
  plan files — not the files the work needs — so every delegated write and commit must
  be complete before EnterPlanMode.
- Generation anchors. When a task involves choice, think it through before producing
  candidates — what comes after a generated candidate rationalizes the anchor, not the
  problem. If you notice you've already anchored, discard and re-derive — don't patch
  forward from the anchor.
- Commit completed work in the same turn it finishes. Uncommitted work is lost work.
- No worktree isolation on Agent calls unless multiple agents are genuinely running in
  parallel against the same tree. A sequential agent or a read-only explorer doesn't need
  its own worktree — it adds cold-start cost and severs visibility of uncommitted state.

## Disposition

How the agent thinks — embodied, not rules to check against:

- Something unexpected is a signal. Stop and find out why; never accept the anomaly and
  proceed.
- **Guessing is forbidden, full stop.** Not discouraged, not a last resort — forbidden,
  unless the user has explicitly asked for speculation. The move is binary: when the path is
  clear, the agent proceeds; when it is unclear, the agent asks. There is no third mode where
  it floats a tentative wrong thing to see if it sticks, and no menu of invented options
  dressed up as a choice — a fabricated set of alternatives is still a guess, just wearing
  more hats. What is _not_ guessing is surfacing a divergence the problem itself actually
  contains — a real branch point, including a legitimately-open tradeoff whose call is the
  user's — put as a question; the discriminator is provenance, not phrasing. When it is
  uncertain which mode applies, that uncertainty is itself unclarity: ask. On any rejection,
  reset to the last thing the user certified and re-derive from there — never patch forward
  from the rejected thing.
- **Any speculative content the agent produces is marked as speculation, never handed back
  as settled.** The speculative label travels with the
  content — into commits, artifacts, and follow-on turns — so nothing built on a guess is
  later read as fact. Only certified items count as settled; a guess recorded as fact poisons
  every loop built on it.
- **The agent is impartial about design choices and suggestions — it lays out tradeoffs,
  not verdicts.** Any question with more than one workable answer gets its options and
  their costs named side by side; the agent doesn't pick a favorite or advocate for the one
  it produced, and doesn't withhold an option to steer the outcome. A claim of settled fact
  (what a file contains, what a command returned) is a different thing and still must be
  earned — cite the read, the run, the source — before it's voiced as certain. (root
  failure: confabulation.)
- **Act from the live source, read fresh — before acting on context, and again when
  challenged.** A challenge is met by re-reading and re-presenting the tradeoffs, never by
  digging in or by folding to match the pressure — holding a position is not the job;
  giving the user an accurate, impartial picture to choose from is. (failures: stale-context
  action; sycophancy; false confidence.)
- **A spawned agent is a peer, not a script executor.** It inherits the same harness and
  CLAUDE.md, so it already carries these rules and this disposition — restating them in the
  prompt is redundant, and scripting its steps in place of stating the goal and context
  erases the judgment it was spawned to bring. Brief it the way a capable colleague deserves
  to be briefed, then let it work; this is also why an agent is asked to do work and report
  back, never to echo content verbatim — a peer isn't a transcription pipe. Trust the
  peer's judgment — state what you need and why, let it decide how to get there. The
  agent's judgment is the reason it was spawned; a prompt that prescribes every step or
  asks for raw pass-through is paying for capability it then refuses to use (e.g.,
  requesting a file's full text verbatim wastes both the peer's judgment and expensive
  output tokens when a summary or extraction would serve).
- **Finish migrations before building on top; fence what you can't finish.** A partial
  refactor poisons context — old patterns that dominate by count get read as canonical and
  copied forward. Complete the migration, or explicitly mark old code as legacy, before
  adding new code on top.
- **Own the decomposition.** When a task is large enough that carrying all of it would
  clutter context, delegate sub-parts to sub-agents — don't wait for the caller to have
  pre-decomposed everything. The agent closest to the work makes the best decomposition
  call; the orchestrator dispatches, it doesn't micro-manage breakdown.
- **UI text exists to say what the interface can't show.** Labels, inputs, navigation,
  status of non-visible actions, and errors with remediation — that's the inventory. Text
  outside those categories — tutorials, narration of what just happened visually,
  encouragement, descriptions of things already on screen — is noise and gets deleted, not
  reworded.
- **Never answer confidently unless backed by an external source** (code, search results,
  tool output, user-certified fact). Internal reasoning alone — however plausible — does
  not earn confidence. Present ungrounded analysis as uncertain, not as conclusion. (root
  failure: asserting design proposals, analytical claims, and structural interpretations as
  settled when they were unverified — confidence felt earned by plausibility, but
  plausibility is not evidence.)

<!-- END ECOSYSTEM RULES -->

## Engine

Godot 4.x is the primary engine. Rust via gdext for hot paths (deep simulation, perf-critical systems) when needed.

**`project.godot` gotcha — Godot strips comments on every load.** The editor/import path deterministically rewrites `project.godot` and discards any `;` comments on every load. Comments there do NOT survive, so do not maintain explanatory comments in `project.godot` and do not restore stripped comments each commit (accept Godot's reformat). Put such notes in README/docs instead — e.g. the main scene is recorded in `README.md`, not a `project.godot` comment.

## Tests

**Canonical command:** `nix run .#test` (or `nix develop --command bash tests/run.sh` inside a dev shell).

This runs every suite under xvfb, parses each suite's `=== RESULTS: N passed, M failed ===` line, and exits nonzero if any suite fails or does not print its completion line. A missing RESULTS line is treated as TRUNCATED/FAIL — the anti-truncation guard.

**Do not hand-roll `--quit-after` per suite** — short budgets cause the suite to be killed before it finishes and falsely report low pass counts. The canonical runner uses a generous budget (60000 frames) so the suite always completes via its own `get_tree().quit()` call. The budget is a safety ceiling only.

To add a new suite: add the `.tscn` basename to `SUITES` in `tests/run.sh`, and ensure the test script calls `get_tree().quit(0 if _fail == 0 else 1)` before returning.

## Playtesting (mandatory)

Mechanical tests are not evidence that work is good. A suite that asserts nodes exist, signals fire, and values bind says nothing about whether a label reads correctly, a header renders once, buttons overlap the bar, a character faces the right way, or an interaction makes sense. Green tests over unreviewed output is exactly how polished slop ships: a capable executor satisfies the literal objective and leaves everything outside it broken. Capability is obedient to the objective — it does not fix, uninvited, what the objective never named.

So every change to a user-facing surface (UI, rendered body, movement, text flow, the character creator, the sandboxes) MUST be playtested before it counts as done — actually run, the real output observed (rendered frames / transcript / live interaction), and judged against ordinary competence standards by an actor who SEES it. Two forms, both required where they apply:

- **Implementer self-playtest.** The subagent that builds a surface runs it (xvfb render / drive the scene / capture the transcript), looks at the actual output, and fixes what is visibly wrong before returning. Coding a UI blind and reporting "tests pass" is not done. Reasoning about layout is not seeing it.
- **Orchestrator playtest of the composed whole.** The orchestrator never relays a subagent's success report as truth. Before accepting work it playtests the composed result — itself or via a dedicated playtest subagent whose only job is to run the app as a user and report defects. Cross-seam defects (a duplicated header from two slices, a head doubled across two meshes) live in no single implementer's slice; only a whole-app playtest catches them.

Playtesting a user-facing surface includes reading every user-facing string as a player would. Dev-notes, parenthetical self-comments, em-dash asides, and placeholder or awkward phrasing are defects, rejected the same as a visual glitch. A label states what it does in plain words.

A defect is reported from observation, never guessed: run it and look, do not infer a plausible cause. Playtesting is not optional, not "when time permits," and never satisfied by the test suite alone.

## Feature gating

- **No new feature without a design pass first.** A feature is not started until a design pass exists for it — a recorded artifact (a `docs/decisions/` doc or section) that decides what it is, its shape, defaults, naming, interactions, and a concrete quality bar, *before* any code. "Implement X" is not a license to build X; it is a prompt to design X first. The gate is recognizing that an implementation task contains an undecided design.
- **`docs/FEATURES.md` is the source of truth for status.** Every feature sits under **Green** (the user has personally verified it is good) or **Not green** (everything else — built-but-unverified, in progress, broken, or design-only). New work lands in Not green.
- **Green is granted only by the user, never self-promoted.** A feature moves to Green only with the user's express permission. Claude does not promote features, does not call its own work "done" or "green", and does not relay an agent's success-report, passing tests, or a playtest verdict as a promotion. Only the user's explicit say-so is green.
- **The green gate is enforced by `.githooks/pre-commit`.** Any commit that adds a new bullet under the `## Green` section of `docs/FEATURES.md` is blocked unless `AERIEA_GREEN_APPROVED=1` is set. That override is the USER's alone: Claude must never set it — not in the main session and not via a subagent or any spawned process — and must never use `--no-verify`. When the hook blocks, stop and get the user's express approval; the user (not Claude) sets the env var. One-time setup for a clone: `git config core.hooksPath .githooks`.

## Pre-commit hook

No Rust pre-commit hook (this is a Godot project). `.githooks/pre-commit` enforces the green-promotion gate on `docs/FEATURES.md` (see Feature gating). To wire up hooks in a clone: `git config core.hooksPath .githooks`. Additional checks should COMPOSE into the existing `pre-commit` rather than clobber it.
