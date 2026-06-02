# TODO

## Immediate

- Open `project.godot` in Godot 4.x editor; verify it loads.
- Run `bun install` in `docs/` once nix shell is active (needed before vitepress works).
- Fill `docs/.vitepress/config.ts` and `docs/index.md` for design docs site (currently scaffolded but empty).
- Wire up git hooks path: `git config core.hooksPath .githooks`

## First prototype: movement

Parkour 2.0 movement is load-bearing per DESIGN.md (the per-second dopamine engine). First prototype: get a player capsule moving fluently with carve/momentum feel in a basic level. Reference: Mirror's Edge, Ghostrunner, Redout 2 (for the carving feel even though it's vehicular).

## Movement abilities / extra movement (future design pass)

The data-driven composable movement substrate is **implemented through Slice 4**
(all four slices done): see **`docs/decisions/movement-substrate.md`** for the
serializable state-machine-as-data schema, the interpreter + compiler dual path,
the determinism model, and the slice plan.

- [x] **Slice 1** — schema + loader + deterministic interpreter; ground+jump as data.
- [x] **Slice 2** — slide/crouch/wall-run/vault/respawn ported to data; full behavioral parity.
- [x] **Slice 3** — GDScript compiler + golden-trace harness; interpreter == compiled, bit-identical.
- [x] **Slice 4** — **bullet jump as a PURE-DATA verb** (`movement/verbs/bullet_jump.kit.json`,
  composed via `movement/default.manifest.json` overlay) with **ZERO engine code
  change**. Proven: regen of the compiled GDScript now emits bullet jump; golden
  trace shows interpreter == compiled == repeat (max_delta 0.0); behavioral burst
  asserted (vy +4.92, forward 24.73 vs plain-jump 10.00). The composition seam
  (`MovementKit.compose` / `load_from_manifest`) + the `add_transitions` patch +
  the cooldown-timer guard are all data. This validated the substrate thesis: the
  existing Condition/Effect primitive vocabulary was SUFFICIENT (no new primitive
  needed) — bullet jump composes from `add_velocity(forward)` + `set_velocity_y` +
  `set_collider_height` + `set_timer` + `input_buffered`/`timer` guards.

The remaining backlog verbs are now **authorable as data exactly the same way**
(drop a `movement/verbs/<verb>.kit.json`, enable it in the manifest — no engine
edit), each still needing its own loop/momentum interaction / NSFW–SFW parity pass:

- **Air burst** — radial upward/outward push (cf. Warframe Zephyr)
- **Charge** — forward dash with collision knockback (cf. Warframe Rhino)
- **Wormhole** — area-denial teleport portal (cf. Warframe Nova)
- **Teleport** — instant directional blink (cf. Warframe Ash / Loki)
- **Aim / ADS** — precision mode; interact with momentum (slow? steady?)
- **Aim glide** — slow descent + precision while aiming (cf. Warframe aim glide)
- **Wall cling / wall latch** — momentary grip, interrupt wall-run momentum

**Named presets** — the kit-overlay + manifest mechanism is a natural seam for
named movement presets: a preset is just a manifest that selects a specific set
of verb kits. Example: a "Warframe" preset bundling bullet jump (already a data
verb), wall jump (already in base kit), wall cling, and aim glide (both backlog
verbs above). No new architecture needed; the composition seam already exists.

(Some of the above — teleport/wormhole/charge — may exercise primitives the
current vocabulary does not yet have, e.g. an instantaneous position set or a
collision-cast; per the spec, adding such a leaf is the one sanctioned engine
change, reviewed against "collapse asymmetries to primitives.")

## Body / animation backlog

- **Secondary / soft-body physics** (jiggle, ears, tails, flesh/soft tissue) —
  R&D bet, multi-year horizon. The standard jiggle-bone approach (spring-driven)
  does not preserve volume and does not self/world-collide; it reads as wobbly
  sticks. Goal: volume-preserving, physically accurate secondary motion with
  proper self- and world-collision (e.g. tail collides with body/ground, doesn't
  clip). Approach: develop or use an accurate offline simulator and produce a
  cheap realtime surrogate evaluated dynamically at runtime — NOT canned
  animation. Two surrogate shapes: (a) reduced-order / subspace deformable
  dynamics (project the accurate sim onto a small modal basis — physical, orders
  of magnitude cheaper), and (b) a neural net trained against the offline
  accurate sim as the frontier option. "Bake" = precompute / fit offline; "fully
  dynamic" = evaluate responsively at runtime. The surrogate must be
  deterministic (fixed weights / deterministic evaluation) to satisfy the
  seeded-simulation invariant — a trained soft-body net is compatible with the
  repo's build-time-inference / deterministic-hot-loop principle precisely
  because it is deterministic, not a per-query LLM. Fits the animation-fidelity
  bet in DESIGN.md. Cross-reference `~/git/rhizone/playmate` (`frond`) during
  the refining stage. **High-want fidelity target:** fine-grained contact
  deformation (fingers pressing into soft tissue, tissue deforming/bulging
  locally around the contact). This is the hard case for modal surrogates —
  a small modal basis smears out localized contact stress — so this target
  pushes toward learned or hybrid surrogates (global base + local contact
  enrichment), not pure modal reduction. See DESIGN.md for the full caveat.
  The poke is a waypoint; the harder rung is **full-hand cupping /
  squishing / grasping** — multiple simultaneous contact regions,
  large-strain loading, and visible volume redistribution (tissue bulging
  between/around fingers). That is where volume preservation becomes
  load-bearing, not cosmetic.

## Open design questions (from DESIGN.md)

- Project name (aeriea is tentative; pronounced "area")
- Per-activity design (each item in Activity surfaces needs its own loop/dopamine/authoring pass)
- Persistence model detail (deterministic action log + per-server state; specifics TBD)
- Sources of change priority (which sources the project leans on hardest)
- Specific power-fantasy enumeration (movement/cosmetics/NPCs/variety/lived-history/environment-authoring committed; more if needed)
- Content authoring strategy detail

## Cross-references

- `~/git/rhizone/playmate` — body/transformation/tag system (`frond`); revisit during refining stage as cross-reference, not as initial dependency
- `~/git/paragarden/existence` — simulation-underneath-rendering pattern, ~67k LOC working code
- [ ] propagate ecosystem-common region (Ecosystem Design Principles) from github-io CLAUDE.md — see tooling/propagate-claude-md.sh

- [ ] Propagate ECOSYSTEM RULES region: removed main-session-only orchestrator/delegation rules (now in a main-session hook, see rhizone/github-io). This repo was dirty during the 2026-05-30 ecosystem propagation — run `tooling/propagate-claude-md.sh` from github-io against this repo's CLAUDE.md and commit when the tree is clean.
