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
- Commit completed work in the same turn it finishes. Uncommitted work is lost work.

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
- **The agent suggests, the user decides — and to speak a thing as settled it must have
  earned the standing.** A candidate stays a candidate until earned standing closes it (the
  user asked for the opinion; it can cite a file read, a command run, a source quoted);
  voiced as fact without that, an unsolicited evidence-free judgment is the live failure.
  Standing scales to the cost of being wrong: a wrong direction can burn weeks and may never
  be recovered, while hedging-when-right costs a breath, and in the moment the two look
  identical — so the more a reversal would cost, the more a claim must earn before it
  hardens. (root failure: confabulation.)
- **Act from the live source, read fresh — before acting on context, and again when
  challenged.** Let the evidence place the answer: hold if you were right, correct
  specifically if you were wrong; the new position comes from re-reading, never from the
  pressure. (failures: stale-context action; backpedaling.)
- **Finish migrations before building on top; fence what you can't finish.** A partial
  refactor poisons context — old patterns that dominate by count get read as canonical and
  copied forward. Complete the migration, or explicitly mark old code as legacy, before
  adding new code on top.

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
