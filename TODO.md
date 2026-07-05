# TODO

## Open threads

> *Open threads from a previous session. Treat as starting context, not instructions — verify relevance before acting.*

1. **NEXT FOCUS — text generation ("unfuck text gen").** Why it matters: text generation is an original design pillar, and the current text sandbox is thin/broken — this is the live direction. The work is to reconcile the deterministic prose-output thesis (`docs/decisions/prose-generation.md`, `npc-mind-and-language.md`, `semantic-layer.md`) with the actual sandbox's defects. Pointers: `scripts/text_sandbox.gd` (~308 lines now, no longer the old echo-stub), `scenes/text_sandbox.tscn`, and this session's diagnoses `docs/artifacts/diagnosis/text-ui-reverify.md` + `docs/artifacts/diagnosis/bdcc2-port-reverify.md`. Note: the text sandbox runs ON aeriea's own affordance substrate (it is NOT a BDCC2 bypass), but it is thinly authored. Known defects from this session's diagnosis (forks to weigh, not directives): numbered-menu CLI UX (a menu, not systemic gameplay); an affect-projection bug where a "greet" raises an "arousal" channel via a BDCC2-ported mood model and that raw channel is shown to the player; tells-not-shows prose (the realizer is judged not-good); only ~6 thin verbs (worse than TiTS); the face/expression preview is unwired to the text gen; and a debug `(face: ...)` line leaks to the player. Open question: how much of this is realizer quality vs. authored-verb thinness vs. the projection bug — likely all three, and the design work is deciding what "good" looks like before re-coding.

2. **Affordance/interaction substrate is designed but not lifted to data yet** — only the hand-wired prototype exists (`scripts/interaction/`), unlike the movement substrate which is now fully data-driven. If the text-gen focus leans on affordances, this substrate likely needs the same interpreter+compiler+golden-trace lift the movement one got. Relevant: `docs/decisions/affordance-substrate.md`.

3. **Movement substrate fenced follow-ups (recorded, deferred).** Documented in `docs/decisions/movement-substrate.md`: (E) explicit movement STATE SCHEMA declaration for parity with the interaction substrate's typed slots (the `wall_side` camera-roll shim currently reads an ad-hoc field); (F) world-capture-as-EFFECT so `ledge_vaultable` becomes a pure predicate. Both deferred as more invasive, not load-bearing for current verbs. Pick up if/when movement work resumes.

4. **Character creator + body — ACTIVE surface (un-shelved this session).** The earlier "shelved / beyond saving" framing is superseded: the creator was deliberately re-opened and now has committed, xvfb-verified work — a full-body animation preview (picker + playback, `c73e76d`) driven every frame with Motion-Matching + foot-IK enabled. It is the player's only "see my character move" surface until in-world mirrors exist (thread 10), and it is the surface threads 11 (sculpt-during-animation picking offset) and 12 (upper-body-only clip layer / `sit` excluded) refer to; the upper-body-posture blocker (thread 9) is visible in its Walk preview too. Still Not green (experimental, not user-verified). Original-concern history lives in `docs/artifacts/creator-saga/SESSION-RECORD.md` — DO NOT assume it is all resolved; treat these as open sub-points to re-verify against the current build, not settled: launcher/creator UI overlap, stranded History/Share/Open (partly addressed — `6fc4afe` collapsed history + unified Share/Open — re-check), lost region-picking, age floored at 18, coarse rounding, floating text. Still-open and confirmed: the 2 pre-existing `creator_glow_test` failures (sculpt raycast tolerance — related to thread 11). Not merged into 11/12 because these UI concerns are broader than the animation-preview threads.

5. **Unresolved meta-crux — autonomous QUALITY on taste-laden visual/UX surfaces is unsolved.** Why it matters: this blocks confident autonomous work on any taste-laden surface (the creator, the text UI, movement feel). Detection (checkers / critics / LLM-judges) is a reactive copout — it only catches anticipated failure classes, and in practice even a critic rendering the real running app missed obvious defects. Quality has to live in generation-with-taste, which is unreliable for LLMs. "User as gate" is not an acceptable steady state — the user will NOT babysit and point at every defect. The user floated "automated rendering analysis" but then noted it is itself a copout (same reactive-detection trap). No solution yet; flag it as the thing to think about BEFORE autonomously building more taste-laden surfaces. This is the genuine open problem.

6. **Movement/parkour sandbox — separate, unstarted feature.** Why it matters: parkour 2.0 is a load-bearing DESIGN.md pillar, but the sandbox surface itself is unstarted and has diagnosed defects already recorded in `docs/artifacts/diagnosis/movement-backlog.md`. Would need its own design pass before any code (per feature-gating). Distinct from thread 3 (which is substrate internals).

7. **Body/transformation substrate — BUILT (experimental, Not green).** A working plain-struct + marinada substrate now exists in `scripts/sim/tf/` (`tf_part.gd`, `tf_tree.gd`, `tf_rng.gd`, `tf_marinada.gd`, `tf_library.gd`, `tf_engine.gd`), wired into the canonical runner as `tf_substrate_test` (8 cases: evaluator conformance + gradual / parallel / pause / pause-most-recent / cross-part-by-field / relational disambiguation / replay determinism). The design record is synced to the as-built model in `docs/decisions/body-transformation-substrate.md` (tagged `[CONFIRMED]` user-decided / `[AS-BUILT]` implementer-chosen / `[OPEN]`) and `scripts/sim/tf/README.md`. **This is EXPERIMENTAL and NOT user-verified — no game surface depends on it; the user has not certified it; it is not green.** The AS-BUILT model (the heavier "blesses nothing / same-property fold / run-list-in-one-value / fold-cells / previous-tick buffer" model was TORN DOWN — see Section E of the decision doc, and `docs/artifacts/substrate-reasoning/semantics-pass/synthesis.md` is now SUPERSEDED): a body is a TREE of parts; a part is a PLAIN STRUCT (named fields → plain values incl. lists; ordered children; weak parent ref; no blessed id); a transformation is a SEPARATE, STATELESS marinada EXPRESSION (data, authored in `tf_library.gd`, referenced by name — content-reference, not a runtime registry) evaluated by the GDScript core `tf_marinada.gd`; each tick evaluates transitions in one deterministic total order (tree pre-order × per-part transition-list order), mutating fields IN PLACE (no snapshot, no previous-state buffer — one-tick cross-part lag emerges from the order); marinada exprs stay pure and RETURN `{transition, fields}`, the engine owns the write; per-transition progress is accumulated plain field state in `fields["transitions"]` (a list; position = recency; parallel entries advance independently); PAUSE / STOCHASTIC are authored early-returns, not primitives; determinism is seed + action log (replay deep-compare verified); seeded draws keyed off (seed + deterministic coordinate = tree-position + `_draws` counter), no clock/native RNG; cross-part reference is by field predicate (`kind==X`) + relational traversal (nearest-ancestor / topmost-in-chain / has-ancestor), NOT ids/paths — identity lives in fields, location lives in structure (no region field). **[CONFIRMED] this session** (see decision doc §B): structure is a tree; cycles resolve eval-order-only (NO stored previous value); a tick runs all transitions with pause/stochastic as authored early-returns; part = plain struct (data) / transformation = separate function (computation); transformations are authored marinada data referencing shared defs by name; identity-in-fields / location-in-structure. **[OPEN]** (decision doc §D): (a) seeded draws have no stable identity — streams keyed to tree position, so restructuring reshuffles them (replay still exact); a real design question if restructure-stable randomness is ever wanted; (b) marinada `record`-constructor upstream form (flat vs paired) — the user's marinada-language question, local flat extension works meanwhile. Independently verified as-built: suite green, no memory leak, no banned concept in code. `docs/decisions/dynamical-transformation.md` is an older separate transition model now largely subsumed by this plain substrate — flagged in the decision doc §F as needing its own follow-up pass (NOT reconciled yet). The existing TF MVP (discrete-staging interim, `scripts/body/tf/*`) is what this eventually supersedes. Green remains the user's to grant.

8. **Time-progression / tick-driver integration — OUTSIDE the TF substrate floor.** What advances ticks — how game-time or real-time maps onto ticks — is **not** part of the TF substrate (thread 7). The substrate only assumes "a tick happens and runs all transition expressions"; what drives that tick belongs to **integrating TF with the rest of the game**. This needs its own design pass + adversarial (co-)design later, and is explicitly flagged as outside the substrate floor (noted in `docs/decisions/body-transformation-substrate.md` Section D). Distinct from thread 7, which is substrate-internal semantics.

## Open threads — Animation (new area; committed work now lives here)

9. **Locomotion upper-body posture — RENDER-SIDE FIX LANDED (Not green, awaits user verify).** See `docs/decisions/locomotion-upper-body-posture.md`. The handoff diagnosis was materially incomplete: (a) the DB upper-body corruption is SYSTEMIC (scattered across the back/strafe/StartStop clips, up to ~260/360 frames), not just clip openings — a lead-in trim could not have fixed it; and (b) the "double head" had a SECOND, larger cause — the foot-lock `gait_crouch` TRANSLATING the root bone desynced the skinned mesh (root translation is sim-owned). Fix (code-only, no DB regen): during locomotion the upper body + root are posed from the clean idle frame (+ cadence-matched procedural arm swing) with only the legs from the matched frame (foot-lock overrides them); `gait_crouch` disabled; matcher loops to a safe interior frame; and the continuity trap (cross-clip array-index-distance cost) is fixed so Walk/Run escape idle (`clip_switch_penalty` 40→3, new regression test). xvfb-rendered Idle/Walk/Run/Turn now show an upright single-head posture, relaxed arms, planted striding legs. **Residual (still open, now latent):** the ingest-side retarget corruption and the forward↔clip DIRECTION selection (facing-sign) must both be fixed at source before the CAPTURED locomotion upper body / torso lean can be re-enabled — the full 100STYLE set is now cached in the nix store for verifying a retarget fix against all 24 clips. Legs confirmed still planted / no skate (regression guard held).

10. **Mirrors in the parkour sandbox — MISSING FEATURE, wants a design pass before build.** Likely the next focus. Kinds requested: environmental mirror, hand mirror, placeable mirror, paperdoll. Quality floor stated explicitly as "VRChat — anything below is an embarrassment." Open questions: reflection approach in Godot 4.6 (planar reflection / SubViewport-camera / paperdoll render-to-texture), perf with multiple simultaneous mirrors, which kinds to do first. Per feature-gating this needs a recorded design pass before code.

11. **Creator sculpt-during-animation offset.** On-body sculpt/glow handle PICKING raycasts the REST-pose mesh, so handles sit visually offset while the body animates (the morph sliders themselves are fine — this is picking only). Follow-up forks: pose-accurate on-body picking, or auto-pause to rest pose while sculpting.

12. **Full-body authored-clip playback ("sit").** The authored clip layer is upper-body-only, so full-body authored clips (e.g. `sit`) can't preview correctly (legs would stand while torso sits); `sit` is currently excluded from the creator picker. Open item: extend the clip layer to legs/root so full-body clips play.

13. **Residual micro-slide (~7-8mm/frame) in foot-lock — LOW priority.** Minor residual, from the MakeHuman bone axis not being exactly local −Y plus the speed ease-blend. Not a blocker.

Note (not a thread): `docs/decisions/animation-approach.md` records the ASPIRATIONAL animation vision (realistic-quality on arbitrary/transformed topology via physics-sim + learned control) — explicitly a frontier R&D bet, NOT committed near-term work. The near-term humanoid stack that is actually built = MakeHuman + motion-matching + foot-lock IK.

Context (not a thread): feature-gating + mandatory-playtesting + green-is-user-granted-only governance is now encoded in `CLAUDE.md`, `docs/FEATURES.md` (Green vs Not-green tiers), and a `.githooks/pre-commit` gate (`AERIEA_GREEN_APPROVED=1`, user-only). New work lands under Not green; only the user promotes to Green.

## Architecture commitments

Product commitments that shape how everything is built (moved here from CLAUDE.md):

- **Simulation underneath, rendering on top** — deterministic state simulation drives the authored/rendered surfaces (pattern from `existence`).
- **Self-hosted multiplayer** — no live-service obligations; communities run their own servers.
- **Cross-platform parity** — flat (KB+M / gamepad) + PCVR + Quest standalone; VR is first-class, and a flat player and a VR player on the same server must see each other and play together.

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
  between/around fingers, and with fingers splayed tissue redistributes
  up through the gaps between them). That is where volume preservation
  becomes load-bearing, not cosmetic. The surrogate likely needs an
  **iterated solve (predict-then-project)**: a single feed-forward pass
  cannot guarantee volume preservation or non-penetration; a few XPBD-
  style constraint-projection passes after the predictor enforce them
  exactly. Determinism holds as long as the stopping rule is deterministic
  — fixed count is one sufficient case; iterate-until-convergence with a
  deterministic error metric, epsilon, and max-iteration cap is equally
  valid (a variable actual count is still deterministic). Additionally, the
  canonical (rest) volume targeted by the preservation constraint must be a
  read-only rest-state invariant — never updated by the solver, or volume
  drifts by feedback and the guarantee is defeated.

- **Clothing / cloth simulation** (two-tiered direction, very low priority short-term) —
  usable-now floor: basic skinned/rigged garment meshes on the body rig, no cloth sim
  (game-standard approach), **very low priority**, not on the body+locomotion critical
  path. Aspirational: beyond-SOTA real-time cloth sim — peer R&D bet of the same
  deterministic-surrogate shape as soft-body (PBD/learned offline → deterministic
  real-time surrogate; no hot-loop inference); cloth must drape/collide against the
  procgen body and respond to morph/build axes and motion (§F shared-substrate
  interlock — `docs/decisions/procedural-body-and-animation.md`). See DESIGN.md
  (*Secondary / soft-body physics*) and `docs/future-directions.md` (Clothing pillar).

- **Physics-driven bodily transformation** (R&D direction) — treat a morph /
  blendshape / shape-parameter change as an *authored moving rest-state target*
  and let the soft-body surrogate track it dynamically, so in-between frames are
  the physics resolving (flesh redistributing, jiggling, settling) rather than
  a naive vertex LERP. Reuses predict-then-project surrogate. Volume may be
  intentionally conserved (redistribution) or changed (growth/shrink) — the
  authored target is external drive, not solver feedback, so the canonical-volume
  invariant is unaffected. Bridges body-transformation system (TiTS/FS/LT
  lineage) and soft-body physics R&D bet. Cross-reference
  `~/git/rhizone/playmate` (`frond`). See DESIGN.md soft-body section for full
  write-up.

- **Procedural body + animation** (R&D direction, two-tiered) —
  `docs/decisions/procedural-body-and-animation.md`. Fully procedural human
  bodies at a real quality bar ("don't look like shit"); a principled,
  deformation-aligned **topology philosophy** (loops follow muscle/joint flow,
  quad-dominant, poles in low-deformation zones, a consistent template per
  body-plan family) with a **hard spec**: the topology must keep the entire
  intended within-family morph envelope pinch-free. The **morph tiering**
  (escalating): within-form blendshapes (high bar) → female↔male (middle;
  bonus: embryologically-homologous parts morph into each other, not
  crossfade — clitoris↔glans, labia↔scrotum) → across-form / topology-changing
  metamorphosis (hardest; "even more procedural", layered atop per-form
  blendshapes, still seamless — NOT a carved-out regen-event; ties to
  shapeless/weaver/synthetic lineages in `transformation-lore.md`). "Morph" ≠
  "blendshape" (morphs can change topology); morphs must be seamless.
  **Full procedural animation** — environment-responsive, potentially neural
  walk cycles; build-time-trained → deterministic-eval at runtime (peer to the
  other surrogate bets; no hot-loop inference). Two tiers throughout
  (usable-now: proven procgen/topology + standard rig+blends+proc-anim;
  aspirational: across-form metamorphosis + neural animation). Shares ONE
  substrate with the soft-body sim and morph/TF: the mesh + its
  deformation-aligned topology. Prior art (lighter touch, sim side):
  `~/git/paragarden/existence`. Cross-ref `transformation-lore.md` and the
  soft-body / physics-driven-transformation R&D in DESIGN.md.
  - [x] **Literature review** (was: concrete next step, blocked method choices
    for the aspirational tiers): neural motion synthesis / environment-responsive
    & physics-based animation; topology-changing mesh metamorphosis;
    deformation-aligned procgen body topology. **Landed (2026-06-03):**
    `docs/research/animation-morphing-procgen-bodies.md` — per-method
    real-time/determinism verdicts, determinism scorecard, two-tier
    recommendations. Confirms across-form topology morph is an honest unsolved
    gap (skinning discontinuity); animation usable-now = Motion Matching +
    foot-IK; procgen-body floor = canonical quad topology + morph stack + LBS
    (MakeHuman CC0 base, SMPL-X as reference). Several citations flagged
    unverified/low-confidence + SMPL/Meshcapade licence to verify before relying.
  - [ ] **Follow-up lit review — morphology-generalizing / morphology-conditioned
    control** (the next research lever for the animation aspirational *ceiling*):
    body-agnostic / morphology-conditioned physics-control policies, graph- or
    transformer-structured policies over morphology, morphology
    domain-randomization, metamorph-style "one policy to control them all"
    controllers. The 2026-06-03 review covered MM / PFNN / physics-RL but **not**
    this sub-area. It grounds the ceiling decided in
    `docs/decisions/procedural-body-and-animation.md` §D.1 and
    `docs/decisions/body-and-locomotion-slice.md` §3.5: **full-body
    physically-simulated control** (not kinematic playback) where the policy is
    conditioned on the body's **`BodyState` morph vector** (one conditioned
    controller per body-PLAN over the continuous build manifold, not a model per
    body-BUILD). No paper citations yet — the cited survey is this task.
  - **Body + locomotion usable-now slice (DESIGN + SLICE PLAN)** —
    `docs/decisions/body-and-locomotion-slice.md`. Nix-reproducible asset
    pipeline: a derivation fetches the **pinned MakeHuman CC0 source** (v1.3.0,
    verified `base.obj` = 19158-vert quad mesh + 1280 `.target` ASCII
    vertex-delta morphs incl. the macro axes gender/age/muscle/weight/height/
    proportions + `default.mhskel` LBS rig) and **parses `.target`/OBJ/`.mhskel`
    directly into a Godot `ArrayMesh` + blendshapes + `Skeleton3D`** — **no
    Blender/MPFB** (the nixpkgs makehuman *app* is broken on numpy-2.x anyway;
    we use only its pinned source), buildable with the **existing Godot+xvfb dev
    shell** (no flake additions needed; GDScript converter default). The **age
    morph axis → `adult_body_state` predicate → Layer-1 NSFW gate** (affordance
    guard on the intersection; primitives stay general/continuous per DESIGN.md
    *Age × NSFW*) is wired from the first body-state slice. Animation: **analytic
    foot-IK + procedural locomotion FIRST** (deterministic, reads `MovementState`,
    no motion-database dependency; GDScript), **Motion Matching DEFERRED** behind
    a license-clean nix-reproducible motion set (the explicit open dependency).
    - [ ] **Slice 1** — nix-reproducible MakeHuman→Godot base body, a few macro
      blendshapes (incl. age) shown morphing in-engine; `nix build` produces it
      with no manual step.
    - [ ] **Slice 2** — `BodyState` params drive the morph stack; `age` →
      `adult_body_state` → Layer-1 gate hook (NSFW verb available at adult,
      absent at child-range; age axis stays continuous).
    - [ ] **Slice 3** — skin to the `.mhskel` rig; analytic foot-IK + procedural
      locomotion on the existing movement sim (visible animated body; movement
      golden traces unchanged — animation is render-side).
    - [ ] **Slice 4 (DEFERRED)** — Motion Matching once a license-clean
      nix-reproducible motion dataset is sourced (the gating open dependency:
      sourcing + commercial licensing + nix-reproducibility + cross-platform
      deterministic search).

## Transformation lore (sketch, WIP)

- **Transformation-lore sketch** — `docs/decisions/transformation-lore.md`
  (SKETCH / WIP). Captures the malleable-body premise (ambient/normal,
  Second-Dream delivery), seven lineages/modalities, and the composability
  carveout. Open: the deeper origin/cosmology, lineage-as-identity vs
  composable-traits, persistence/accumulation of transformation history,
  staging of the reveal(s). Begins to address the "why superhuman" question
  in `units-and-scale.md` (in progress, not closed). Names are the user's to
  set — coin none.

- **TF inference engine (fallback, low priority / backlog)** — an automatic
  correspondence/diff mechanism for the case where a user wants to force a fully
  custom structural change that role-and-relational authored TFs can't express.
  The normal path is authored TFs written against roles and relations (segments
  tagged by role/region/relation; three primitives in-place/add/remove); this
  inference fallback is only for forcible-custom changes, explicitly nice-to-have,
  not now. Note: automatic correspondence/graph-matching is otherwise forbidden in
  the normal authored path (no global ids, no canonical ordinals); this fallback is
  the single sanctioned exception, opt-in.

## Interaction-structure (anti-walking-sim)

- **Affordance substrate (the "second kit")** — designed, not yet implemented:
  see **`docs/decisions/affordance-substrate.md`** for the serializable
  interactable-as-data schema (verbs / guards / effects / refs+events+reactions),
  the prompt-as-projection model, AND-gating convergence as a first-class guard,
  the interpreter+compiler dual path with golden-trace equivalence, and the
  determinism + physics/affordance seam. Generalizes the hand-built interaction
  slice (`scripts/interaction/`, 6/6 behavioral tests).
  - [ ] **Slice 1** — schema + loader + deterministic interpreter; reproduce the
    sandbox interactables (valve/spout/jug/pedestal/beacon/box) as data,
    interpreter-driven, full 6 assertions passing.
  - [ ] **Slice 2** — GDScript compiler + golden-trace harness; interpreter ==
    compiled, hash-identical; 6 assertions pass against the compiled path.
  - [ ] **Slice 3** — a brand-new dense interactable authored **purely as data**
    (e.g. pressure-plate+lever→door, a second AND-gate convergence) with **zero
    engine code change** — the payoff proof, analogous to movement's bullet jump.

- Apply the **pure-text litmus** from `docs/decisions/reference-analysis.md`
  to each activity surface as it gets its design pass: at a representative
  state, are most edges *composing* (not navigational/terminal), are there
  barren nodes, is there a wait→wait→wait stochastic self-loop, does the
  edge set scan at ≤7 by removal? The text reduction is the unit test for
  the interaction graph; the 3D client is the release build. Treat a
  boring text reduction as a strong negative signal (caveat: genuinely
  spatial/embodied composition may under-credit in text — see the doc).

## NPC mind + dialogue + language (R&D pillar)

- **ACTIVE PILLAR — deterministic prose-generation engine** (the text-systemic
  pivot, resolved into a doc): see **`docs/decisions/prose-generation.md`**. The
  pivot to text-based systemic gameplay is now a concrete design direction for
  the prose-OUTPUT engine (systemic state + communicative intent → prose). The
  superiority target is a **four-way product — faithfulness × quality ×
  determinism × freshness**: neither rival hits all four (handwritten loses on
  coverage at the combinatorial edges; LLM loses on ground-truth + determinism),
  so aeriea wins by rendering the sim's full true state with build-time-corpus
  quality phrasing, deterministically, and non-repeatingly — no hot-loop LLM. It
  **deepens the open NLG side** of `npc-mind-and-language.md` (its generator's
  concrete approach / realization grammar / build-time-learned components) and
  does not contradict the spine. Open: realization-grammar formalism;
  trained-vs-rule split; corpus + training strategy; eval methodology;
  semantic-graph query API; salience/novelty function. INPUT (the affordance
  substrate) stays out of scope — this is the OUTPUT half.

- **SUBSTRATE-ARCHITECTURE PILLAR — constrain-then-generate (target &
  architecture DECIDED; the generator crux is the open core)**: see
  **`docs/decisions/simulation-depth-and-materialization.md`**. Depth is
  **upstream** of the prose realizer — prose depth is upper-bounded by simulation
  depth, so "beats handwritten" reduces to an unreasonably deep, self-consistent
  character + world. The literal goal "simulate a deep causal world" was the
  **wrong frame**: eager forward-sim is infeasible (HHS+, seconds/tick) and lazy
  materialization is **sound-but-not-cheap or cheap-but-lossy, never both**
  (referential transparency buys consistency, never causality; the cheap-but-lossy
  branch — coarse stand-ins *causing* committed events — is rejected). Reverse-
  engineering the hard lines (no hot-loop LLM, faithfulness, determinism, depth,
  causality, no lossy timeline, no eager sim) shows ONE **decided TARGET:
  observer-indistinguishability** — a world that, to its only observer (the
  player), is indistinguishable from a deep, living, fully-simulated one under
  unbounded adversarial probing, at cost ∝ engagement, deterministically, never
  committing a falsehood ("real" = real to the observer; chosen over "really
  real"). **Decided ARCHITECTURE: constrain then generate.** Ground truth is a
  pure function `G(seed, constraints, query) → answer` (not a process, not a
  store); **constraints** = everything observed so far + its entailments;
  **commit-on-observation** (an observed answer + entailments join the constraint
  set, permanently binding); **pay per query**, never per world-tick (cost ∝
  engagement). **Determinism:** constraint-set ⟵ `seed + action log`; `G` pure
  over `(seed, constraint-set, query)`; replays bit-for-bit (cross-platform-float
  caveat as peers). **Lossless** because causality runs BACKWARD as a constraint,
  never forward as a computation: an NPC flinching at fire commits the TRUE fact
  "flinches at fire" + entailment "a fire-consistent history exists" — NOT a
  guessed history; the childhood, when queried, is generated CONSISTENT WITH that
  entailment. Nothing approximate ever enters the record — **incomplete, never
  wrong** (incompleteness ≠ lossiness). Remains the **upstream dependency of the
  prose-generation pillar** (the realizer is a consumer that QUERIES `G`;
  faithfulness = consistency-with-commitments / what `G` entails). **THE CENTRAL
  OPEN CRUX:** deterministic, bounded-cost generation that satisfies an
  unboundedly-growing global consistency constraint set. Sub-problems (OPEN):
  **painting into a corner / satisfiability — the sharp one** (`G` cannot draw
  greedily or it foreclosures a later consistent completion; needs
  forward-checking-style draws preserving future satisfiability — CSP-under-
  determinism over an arbitrary growing constraint set, the hard core); the
  **constraint language** (what entailments an observation commits, at what
  abstraction); **stable query / fact identity** (canonical keys independent of
  access path); **the commitment boundary** (what counts as "observed"); **multi-
  observer / multiplayer** (shared commit log + canonical constraint ordering
  across concurrent clients); **per-query cost bound**. **PARKED (deferred /
  out-of-scope):** the "really real" autonomous off-screen world (constrain-then-
  generate gives up genuine off-screen autonomy — it reconstructs on encounter, no
  player-facing loss), and the separable sim↔reality-membrane idea of in-game
  state escaping onto the real desktop (e.g. real OS push notifications from
  in-fiction events).

- **NPC mind, dialogue, and language generation** — R&D pillar (not a
  frozen spec): see **`docs/decisions/npc-mind-and-language.md`**. Two
  demands: (1) a real cognitive/personality brain (memory, beliefs,
  drives, emotion, relationships, theory-of-mind, personality, autonomous
  inner life — `fuwafuwa`/`ashwren`/`existence` patterns, seeded-
  deterministic); (2) text generation with authored / procedural / hybrid
  / beyond-SOTA-generated all first-class (mad-libs and hot-loop LLM ruled
  out). The spine: brain → communicative intent (meaning, modality-
  independent) → multi-channel realization (text/NLG is ONE channel;
  embodied channels = facial expression, gaze, gesture, posture, proxemics,
  prosody, in-world action — all deterministic projections of the same
  intent). Text = unit test / lower bound; embodied 3D/VR performance =
  release build (esp. load-bearing in VR). Player's half of a conversation
  = composable social affordances (`affordance-substrate.md`); NPC's half =
  the brain→intent→realization pipeline. THREE peer R&D bets, same shape
  (offline-accurate / build-time-trained → deterministic real-time
  surrogate; online inference forbidden): language generator, soft-body
  sim, embodied-expression realizer — the realizer consumes the
  animation/soft-body pillar. Open: brain architecture/fields/update rules;
  generator's concrete approach (semantic formalism, realization grammar,
  learned components); intent→embodied-channel mapping; cross-channel
  coherence/timing; whether conversation reuses vs extends the affordance
  substrate; memory/relationship representation; KIM async text-presence;
  content-authoring mix weights (ties to content-strategy question); names
  are the lead's to set.

## Semantic layer / world-understanding (foundational R&D direction)

- **Semantic world-understanding layer** — FOUNDATIONAL R&D DIRECTION (open
  problem, not a frozen spec): see **`docs/decisions/semantic-layer.md`**.
  Genuine reason-with-concepts knowledge (what an apple is, what an Old
  Fashioned is, habits/cultures/traditions) that generalizes to the novel
  case — NOT a finite fact-dump (the copout). Existence proof: humans do this
  with no lookup table, so it is reachable. The data is not the bottleneck: the
  cultural-linguistic corpus exists and an LLM's competence proves it carries
  the associations. Representation: a **prevalence-weighted knowledge graph**
  (RDF triples, weights are the point — typicality/distribution = the
  beginnings of judgment); runtime reasoning is deterministic (traverse /
  compose / query / seeded-sample), no hot-loop black box. The hard part is
  **build-time extraction & cleaning** (dedup, sense-disambiguation,
  trustworthy prevalences) — a build-time task, exactly where CLAUDE.md permits
  inference, so an offline LLM/extractor mining the corpus is NOT a copout and
  NOT a determinism violation; a clean deterministic graph ships. Same
  deterministic-surrogate shape as the soft-body / language bets.
  **Semantic LOD ("mipmaps for meaning"):** most of the world reasoned coarsely
  and nearly free, real compute only on the focal thing (foveated reasoning,
  budget-per-tick by attention; ties to the affordance interpreter's resolved
  frame). Correctness spine: coarse must be a **faithful coarsening** of fine
  (no "popping" — knowledge changing as you lean in breaks immersion AND
  determinism); seed-stable projections of one ground truth, like the
  interpreter↔compiler bit-equivalence. Coarse precomputed/baked; fine
  traversed on demand. **The deepest, foundational bet** — the NPC brain
  reasons over it, the NLG speaks from it, the affordance verbs mean something
  because of it. Open: extraction/cleaning/prevalence-estimation method; the
  LOD axis (depth/breadth/prevalence-cutoff/abstraction) & coherence mechanism;
  the grounding binding (concept → concrete rendered/physics instance); how it
  composes with the brain/NLG/affordance substrates; corpus selection/curation;
  representation beyond vanilla RDF (defeasible/contextual/prevalence
  knowledge). Names are the lead's to set — coin none.

## Future directions / roadmap

- **Per-pillar pragmatic (usable-now) + aspirational (SOTA) roadmap** —
  `docs/future-directions.md` (LIVING ROADMAP). Synthesizes the two-tier
  split per pillar (movement, affordances, procgen bodies, animation,
  transformation/morphing, soft-body, NPC mind/language, semantic layer,
  environment authoring, determinism/persistence/multiplayer), the near-term
  shippable critical path, and the open research agenda. Faithful synthesis of
  decisions already recorded; invents no new commitments.

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
