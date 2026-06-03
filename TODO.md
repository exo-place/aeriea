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
