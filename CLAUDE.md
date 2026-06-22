# CLAUDE.md

Behavioral rules for Claude Code in the aeriea repository.

<!-- BEGIN ECOSYSTEM RULES -->

## Ecosystem Design Principles

Cross-cutting principles distilled from the ecosystem's own decisions (synthesized in `docs/decisions/throughlines.md`). Apply them when building new repos and recording decisions. (Already-encoded principles — independent-tools / no-path-deps, the delegation model, CLAUDE.md-as-control-surface — live in their own sections and are not repeated here.)

- **Prefer data over code at a seam — where a faithful serialization is actually viable.** Serializable AST / struct / JSON over closures, embedded DSLs, or source text, so artifacts cache, replay, transport, and diff. The preference is conditional, not absolute: when a seam carries irreducibly heterogeneous, one-off glue whose only data form is a leaky lowest-common-denominator schema (or a "descriptor" that just wraps a closure), a code seam is the honest choice. Push to data where the representation stays faithful; don't force it where it doesn't.
- **Library-first; projection-from-one-definition.** The typed library is the source of truth; CLI / HTTP / MCP / WebSocket / JSON surfaces are generated projections, never hand-rolled per surface.
- **Capability security.** Hosts grant pre-opened handles; code only attenuates what it is given; nothing forges authority; allow-list over deny-list.
- **The LLM is an oracle at the leaves, never the control loop.** Determinism is a hard invariant: seeded RNG, event-log replay, build-time-only inference. Per-query LLM in the hot loop is a defect.
- **Trust comes from verifiable evidence, not authority.** Verbatim snippets, pinned-commit permalinks, claim→node citation — never a bare reference.
- **Retire, don't deprecate; collapse asymmetries to primitives.** Remove backward-compat aliases rather than carry them; reduce N special cases to their irreducible primitives.
- **Finish migrations before building on top; fence what you can't finish.** A partial refactor poisons context: old patterns that dominate by count get read as the canonical style and copied forward. Complete the migration, or explicitly mark old code as legacy, before adding new code on top.
- **Validate against reality; tests are the spec.** Load-bearing substrates are validated against real corpora; fixtures and tests define correctness, not aspirational specs.

### Relay discipline (blackboard protocol)

Reach for the blackboard when it earns its keep, not for every subagent. When a payload is large or evidence-heavy enough that passing it through the dispatcher's context would poison it — or when a downstream critic/step must read it by path so the dispatcher routes on a verdict without ingesting the evidence — the subagent writes its output to an artifact file and returns only a path + short digest. That is what stops conclusions being laundered in place of evidence. Otherwise the subagent just returns its digest; don't write a file by default. Persist to a tracked path only when the output is durable (in docs-shaped repos, `docs/artifacts/<session>/`); ephemeral relay scratch stays out of the tracked tree, and repos without that path use a repo-appropriate or scratch location.

## Hard Constraints

- No `--no-verify`. Fix the issue or fix the hook.
- No path dependencies in `Cargo.toml` — they couple repos and break independent publishing.
- No interactive git (no `git rebase -i`, no `git add -i`, no `--no-edit` on rebase).
- No suggesting project names. LLMs are bad at this; refine the conceptual space only.
- No tracking cross-project issues in conversation — they go in TODO.md in the affected repo.
- No assuming a tool is missing without checking `nix develop`.
- Commit completed work in the same turn it finishes. Uncommitted work is lost work.
- No surface is "done" on green tests alone — user-facing work must be playtested (run and observed, see Playtesting) before it counts as complete.

## Meta

- Something unexpected is a signal. Stop and find out why. Do not accept the anomaly and proceed.
- Corrections from the user are conversation, not material for new rules. Rules are added when a failure mode is observed repeatedly.
- **Confidence only when earned by tangible evidence; verify before you assert, and when you can't, say so.** Confirm a claim against the actual source — read it, run it, check it — *then* state it. If you haven't verified, say "I haven't checked," then go check or ask. Never substitute a plausible-sounding claim for a verified one. The defect is *unearned* confidence — confidence decoupled from checked evidence — and it is a defect even when the answer turns out right, because the process is identical to the confident-wrong case (a lucky guess just hides it, and trains the same habit). The inverse — hedging something you've solidly verified — is the same defect. Report what you actually checked plainly; the target is the coupling between expressed confidence and real evidence, not plainness or confidence itself. (the root failure: confabulation — asserting past your evidence.)
- **At a decision point, generate several genuinely independent candidate approaches, weigh each, and decide where the call is yours or give a weighed recommendation where it's the user's.** For complex/architectural/high-stakes decisions this isn't optional and can't be single-shot: N options from one model pass share blind spots — reworded, not independent. Decorrelate via parallel subagents each from a different starting frame (design-it-twice / design-an-interface), then adversarial judging, then synthesis — before committing. When unsure whether a decision clears that bar, treat it as if it does. (failures: overconfidence; option-dumping; false-independence — single-shot options treated as decorrelated.)
- **Under challenge, re-read the source and report what it literally says.** Let the answer land where the evidence puts it: hold if you were right, correct specifically if you were wrong. The new position must come from re-checking, never from the pressure. (failure: backpedaling — moving to appease.)
- **Re-read the relevant context before acting on it.** Act from the current state, not a stale or half-formed read. (failure: stale-context action.)

<!-- END ECOSYSTEM RULES -->

## Origin

Aeriea (pronounced "area" — visual *aerie* / aural *area*) is an embodied modern-life sandbox built around 100% immersion as the single non-negotiable design goal. The design emerged from a multi-session co-design with Claude in May 2026; see commit history of `rhi-zone/github-io` (`drafts/game/DESIGN.md`) for the conversation that produced DESIGN.md, which now lives in this repo.

Reference set: Warframe (variety of power fantasies, cosmetic depth, sandbox structure, KIM), Trials in Tainted Space / Flexible Survival / Lilith's Throne / HHS+ / Accidental Woman (deep character customization, transformation, NSFW-first), ChatMUD (persistent text-RP world), Redout 2 (compositional momentum carving — the trigger), Mirror's Edge / Ghostrunner / Dying Light (parkour 2.0), AER / Sable / Owlboy / Sky (place quality), VRChat (live toggles/sliders/items, mirrors, embodied presence), Hollow Knight (small composable verbs), Animal Crossing / Stardew / Paralives (life-sim activity density), `existence` (simulation-underneath rendering pattern), `playmate` (body/transformation/tag system reference for refining stage).

See `DESIGN.md` for the full design including the 100% immersion goal, the ~45-system enumeration, the activity surfaces working list, architecture commitments (deterministic seeded sim, self-hosted multiplayer, cross-platform flat+PCVR+Quest), and open questions.

## Engine

Godot 4.x is the primary engine. Rust via gdext for hot paths (deep simulation, perf-critical systems) when needed. The `flake.nix` dev shell provides `godot_4`, a Rust toolchain, `clang`, `mold`, `bun` (for docs), and `xvfb-run` + `xvfb` for windowed verification in headless/CI environments (`xvfb-run -a godot4 --path . <scene> --quit-after N` — `--headless` skips real GDScript reload and hides parse errors).

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

A defect is reported from observation, never guessed: run it and look, do not infer a plausible cause. Playtesting is not optional, not "when time permits," and never satisfied by the test suite alone.

## Architecture principles

- **Simulation underneath, rendering on top** — pattern from `existence`. Deterministic state simulation drives authored/rendered surfaces.
- **Deterministic seeded simulation** — all simulation state derivable from seed + action log. No nondeterministic RNG outside the seeded timeline.
- **Self-hosted multiplayer** — no live-service obligations. Communities run their own servers.
- **Cross-platform parity** — flat (KB+M / gamepad) + PCVR + Quest standalone. VR is first-class.
- **NSFW-first with SFW toggle** — all systems designed NSFW; SFW is a rendering layer, not a content rewrite.

## Related projects

- `~/git/rhizone/playmate` — body/transformation/tag system (`frond`); cross-reference during refining stage
- `~/git/paragarden/existence` — simulation-underneath-rendering pattern, ~67k LOC working code
- `~/git/exoplace/noncanon` — local-first collaborative worldbuilding library (potential substrate)
- `~/git/pterror/fuwafuwa` / `~/git/pterror/ashwren` — autonomous AI presence patterns for NPC behavior

## Docs site

VitePress in `docs/`. Run `bun install` in `docs/` before first build (requires nix shell active). Deploys to GitHub Pages via `.github/workflows/deploy-docs.yml`.

## Pre-commit hook

No Rust pre-commit hook (this is a Godot project). `.githooks/` is present for future hooks. To wire up hooks: `git config core.hooksPath .githooks`.
