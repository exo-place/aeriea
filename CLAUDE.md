# CLAUDE.md

Behavioral rules for Claude Code in the aeriea repository.

<!-- BEGIN ECOSYSTEM RULES -->

## Ecosystem Design Principles

Cross-cutting principles distilled from the ecosystem's own decisions (synthesized in `docs/decisions/throughlines.md`). Apply them when building new repos and recording decisions. (Already-encoded principles — independent-tools / no-path-deps, the delegation model, CLAUDE.md-as-control-surface — live in their own sections and are not repeated here.)

- **Prefer data over code at every seam.** Serializable AST / struct / JSON over closures, embedded DSLs, or source text — so artifacts cache, replay, transport, and diff.
- **Library-first; projection-from-one-definition.** The typed library is the source of truth; CLI / HTTP / MCP / WebSocket / JSON surfaces are generated projections, never hand-rolled per surface.
- **Capability security.** Hosts grant pre-opened handles; code only attenuates what it is given; nothing forges authority; allow-list over deny-list.
- **The LLM is an oracle at the leaves, never the control loop.** Determinism is a hard invariant: seeded RNG, event-log replay, build-time-only inference. Per-query LLM in the hot loop is a defect.
- **Trust comes from verifiable evidence, not authority.** Verbatim snippets, pinned-commit permalinks, claim→node citation — never a bare reference.
- **Retire, don't deprecate; collapse asymmetries to primitives.** Remove backward-compat aliases rather than carry them; reduce N special cases to their irreducible primitives.
- **Validate against reality; tests are the spec.** Load-bearing substrates are validated against real corpora; fixtures and tests define correctness, not aspirational specs.

## Hard Constraints

- No `--no-verify`. Fix the issue or fix the hook.
- No path dependencies in `Cargo.toml` — they couple repos and break independent publishing.
- No interactive git (no `git rebase -i`, no `git add -i`, no `--no-edit` on rebase).
- No suggesting project names. LLMs are bad at this; refine the conceptual space only.
- No tracking cross-project issues in conversation — they go in TODO.md in the affected repo.
- No ecosystem changes without checking all affected repos.
- No assuming a tool is missing without checking `nix develop`.
- Commit completed work in the same turn it finishes. Uncommitted work is lost work.

## Meta

- Something unexpected is a signal. Stop and find out why. Do not accept the anomaly and proceed.
- Corrections from the user are conversation, not material for new rules. Rules are added when a failure mode is observed repeatedly.

<!-- END ECOSYSTEM RULES -->

## Origin

Aeriea (pronounced "area" — visual *aerie* / aural *area*) is an embodied modern-life sandbox built around 100% immersion as the single non-negotiable design goal. The design emerged from a multi-session co-design with Claude in May 2026; see commit history of `rhi-zone/github-io` (`drafts/game/DESIGN.md`) for the conversation that produced DESIGN.md, which now lives in this repo.

Reference set: Warframe (variety of power fantasies, cosmetic depth, sandbox structure, KIM), Trials in Tainted Space / Flexible Survival / Lilith's Throne / HHS+ / Accidental Woman (deep character customization, transformation, NSFW-first), ChatMUD (persistent text-RP world), Redout 2 (compositional momentum carving — the trigger), Mirror's Edge / Ghostrunner / Dying Light (parkour 2.0), AER / Sable / Owlboy / Sky (place quality), VRChat (live toggles/sliders/items, mirrors, embodied presence), Hollow Knight (small composable verbs), Animal Crossing / Stardew / Paralives (life-sim activity density), `existence` (simulation-underneath rendering pattern), `playmate` (body/transformation/tag system reference for refining stage).

See `DESIGN.md` for the full design including the 100% immersion goal, the ~45-system enumeration, the activity surfaces working list, architecture commitments (deterministic seeded sim, self-hosted multiplayer, cross-platform flat+PCVR+Quest), and open questions.

## Engine

Godot 4.x is the primary engine. Rust via gdext for hot paths (deep simulation, perf-critical systems) when needed. The `flake.nix` dev shell provides `godot_4`, a Rust toolchain, `clang`, `mold`, `bun` (for docs), and `xvfb-run` + `xvfb` for windowed verification in headless/CI environments (`xvfb-run -a godot4 --path . <scene> --quit-after N` — `--headless` skips real GDScript reload and hides parse errors).

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
