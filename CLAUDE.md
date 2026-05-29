# CLAUDE.md

Behavioral rules for Claude Code in the aeriea repository.

## Origin

Aeriea (pronounced "area" — visual *aerie* / aural *area*) is an embodied modern-life sandbox built around 100% immersion as the single non-negotiable design goal. The design emerged from a multi-session co-design with Claude in May 2026; see commit history of `rhi-zone/github-io` (`drafts/game/DESIGN.md`) for the conversation that produced DESIGN.md, which now lives in this repo.

Reference set: Warframe (variety of power fantasies, cosmetic depth, sandbox structure, KIM), Trials in Tainted Space / Flexible Survival / Lilith's Throne / HHS+ / Accidental Woman (deep character customization, transformation, NSFW-first), ChatMUD (persistent text-RP world), Redout 2 (compositional momentum carving — the trigger), Mirror's Edge / Ghostrunner / Dying Light (parkour 2.0), AER / Sable / Owlboy / Sky (place quality), VRChat (live toggles/sliders/items, mirrors, embodied presence), Hollow Knight (small composable verbs), Animal Crossing / Stardew / Paralives (life-sim activity density), `existence` (simulation-underneath rendering pattern), `playmate` (body/transformation/tag system reference for refining stage).

See `DESIGN.md` for the full design including the 100% immersion goal, the ~45-system enumeration, the activity surfaces working list, architecture commitments (deterministic seeded sim, self-hosted multiplayer, cross-platform flat+PCVR+Quest), and open questions.

## Engine

Godot 4.x is the primary engine. Rust via gdext for hot paths (deep simulation, perf-critical systems) when needed. The `flake.nix` dev shell provides `godot_4`, a Rust toolchain, `clang`, `mold`, and `bun` (for docs).

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
