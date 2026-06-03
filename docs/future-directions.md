# Future directions — pragmatic (usable-now) and aspirational (SOTA) paths

Status: **LIVING ROADMAP** (2026-06-03)

Scope: a per-pillar synthesis of the two-tier framing already decided across
the design docs — for each pillar, the **usable-now (pragmatic)** path that is
proven and shippable, and the **aspirational (SOTA / research)** path that is
the open research bet. This doc **invents no new commitments or mechanisms**.
It pulls the usable-now-vs-aspirational splits already recorded; where a split
isn't yet recorded for a pillar it states the pragmatic path conservatively
from what is proven and marks the aspirational side **open**. Research-grade
items are marked aspirational/open and not overclaimed.

Sources synthesized: `../DESIGN.md` (*aeriea is a research program* — the
two-tier framing; *the animation/fidelity bet*; *Secondary / soft-body
physics*; *Variety of power fantasies*; *Architecture commitments*),
`decisions/movement-substrate.md`, `decisions/affordance-substrate.md`,
`decisions/npc-mind-and-language.md`, `decisions/semantic-layer.md`,
`decisions/transformation-lore.md`, `decisions/procedural-body-and-animation.md`,
`decisions/reference-analysis.md`, `decisions/units-and-scale.md`,
`research/animation-morphing-procgen-bodies.md`, and `../TODO.md`.

---

## 1. Framing — both halves at once

aeriea is **both** a rapidly-prototyped, actually-usable game **and** a
multi-year research program. Stated alone, either framing is lopsided
(DESIGN.md, *aeriea is a research program (the honest framing)*):

> "aeriea must SIMULTANEOUSLY be a rapidly-prototyped, actually-usable game —
> not only an aspirational SOTA research program. … every pillar is
> two-tiered: a **usable-now tier** (proven, shippable tech that's good-enough,
> built fast) AND an **aspirational-SOTA tier** (the open research bet). The
> plan is to **ship a real game rapidly on the usable-now tier while the SOTA
> tiers mature**, each pillar **degrading gracefully** from aspirational to
> usable."

The principle for this doc:

- **Every pillar degrades gracefully** from its aspirational form to its
  usable-now form. The usable-now floor is never a copout — it is the proven
  ground the game ships on.
- **The aspirational tiers share one shape.** The four/five beyond-SOTA bets
  (soft-body / physics-driven transformation, language generation, embodied
  expression, the semantic layer, and the procedural-body/animation pillar)
  are **peer, currently-unsolved, of the same deterministic-surrogate shape**:
  hard accuracy is paid for *offline / at build time*, lowered to a
  **deterministic real-time surrogate**, with **online / per-query inference
  forbidden in the hot loop** (DESIGN.md; CLAUDE.md: *the LLM is an oracle at
  the leaves, never the control loop*; determinism is a hard invariant).
- **Movement and interaction are not bets** — they stand on proven composable-
  data substrates and are engineering on solid ground (DESIGN.md). The bulk of
  the *fidelity* goal lives in the bets; the bulk of the *shippable game* lives
  in the proven tiers.

The "no copouts" meta-commitment (DESIGN.md, *Meta-commitments*) constrains the
usable-now tier too: phased fidelity is acceptable, scope reduction and
stylization-as-escape-from-realism are not.

---

## 2. Per-pillar: pragmatic vs aspirational

### Movement — `decisions/movement-substrate.md`

Status: **data-driven substrate implemented through Slice 4** (TODO.md,
*Movement abilities*). This pillar is **proven ground, not a bet**.

**Usable-now (pragmatic).**
- The remaining backlog verbs authored **as pure data** the same way bullet
  jump was (drop `movement/verbs/<verb>.kit.json`, enable in the manifest, no
  engine edit): air burst, charge, wormhole, teleport, aim/ADS, aim glide,
  wall cling/latch (TODO.md).
- **Named presets** as manifest selections (e.g. a "Warframe" preset bundling
  bullet jump + wall jump + wall cling + aim glide) — no new architecture, the
  composition seam already exists (TODO.md).
- Each verb still needs its own loop/momentum-interaction and NSFW–SFW parity
  design pass (TODO.md).
- The interpreter↔compiler dual path with golden-trace bit-equivalence stays
  the determinism contract (movement-substrate.md).

**Aspirational (SOTA / research).**
- A few backlog verbs (teleport / wormhole / charge) may exercise primitives
  the current vocabulary lacks (instantaneous position set, collision-cast).
  Adding such a leaf is the **one sanctioned engine change**, reviewed against
  "collapse asymmetries to primitives" (TODO.md). This is incremental, not
  research-grade — there is no open research bet recorded for movement itself.
- The aspirational coupling shows up *downstream*: physics-responsive
  locomotion (env-responsive / physics-RL animation) lives in the **Animation**
  pillar, not here.

### Interaction / affordances — `decisions/affordance-substrate.md`, `decisions/reference-analysis.md`

Status: **designed; the hand-built slice (`scripts/interaction/`, 6/6 tests)
proves the structure; substrate Slices 1–3 planned** (TODO.md).

**Usable-now (pragmatic).**
- **Slice 1** — schema + loader + deterministic interpreter; reproduce the
  valve→spout→jug→pedestal→beacon and box-stack chains as data (affordance-
  substrate.md; TODO.md).
- **Slice 2** — GDScript compiler + golden-trace harness; interpreter ==
  compiled, hash-identical (TODO.md).
- **Slice 3** — a brand-new dense interactable authored **purely as data**
  (e.g. pressure-plate + lever → door, a second AND-gate convergence) with
  zero engine code change — the payoff proof, analogous to movement's bullet
  jump (TODO.md).
- Apply the **pure-text litmus** from reference-analysis.md to each activity
  surface as it gets its design pass (composing edges, no barren nodes, no
  wait→wait→wait stochastic self-loop, ≤7 edges by removal).

**Aspirational (SOTA / research).**
- Full **composable-world affordance density** across the whole activity
  surface (DESIGN.md, *Activity surfaces*) — many dense interaction graphs, all
  surviving the pure-text reduction. This is breadth of authoring on a proven
  substrate, not an unsolved-research bet.
- The **full-diegetic compositional depth** frontier (DESIGN.md, *Compositional
  power and the diegetic-integration axis*): expressing systemic/compositional
  power *entirely* through in-fiction objects with zero exposed logic graph —
  explicitly noted as "largely unsolved in the medium" and **open** (how far up
  the diegetic-integration axis aeriea can climb is an open question).

### Procedural bodies — `decisions/procedural-body-and-animation.md`, `research/animation-morphing-procgen-bodies.md` (§C)

Status: **R&D direction; literature review landed** (research doc, 2026-06-03).

**Usable-now (pragmatic).**
- **One canonical quad topology + a morph / blendshape stack + LBS** — the
  pattern SMPL-X = Daz = MetaHuman all share (one unified topology, everything
  is a morph on it, one rig). This *is* the decision doc's "one shared topology
  per body-plan family" (research §C; procedural-body-and-animation.md §A–B).
- **License-clean Godot path: MakeHuman CC0 exports as the base mesh**
  (cleanest license) + **SMPL-X's parameter structure as a design reference**
  for the morph/shape space (research §C, §Synthesis).
- Topology craft carried forward: quad-dominant, loops follow muscle/joint
  flow, poles out of bend zones, concentric face loops; the linchpin — shared
  topology ⇒ blendshape correspondence (research §C4).
- Hard spec: the topology must keep the entire intended within-family morph
  envelope pinch-free (procedural-body-and-animation.md §B).

**Aspirational (SOTA / research).**
- Generative high-quality bodies (**imGHUM / gDNA / diffusion avatars**) as a
  **build-time content oracle**: generate candidates offline, then bake /
  retopologize onto the canonical topology so the shipping asset stays
  deterministic and morph-compatible. Generative output is **never shipped
  raw** — candy-wrapper artifacts, no clean topology, not semantically
  controllable (research §C3, §Synthesis).

> Caveat carried verbatim: **SMPL family is research / non-commercial —
> commercial use needs a separate license (Meshcapade); verify with
> Meshcapade / MPI before relying on it. MetaHuman is OUT (UE-only EULA).**
> (research §C1–C2, §Open questions.)

### Animation — `research/animation-morphing-procgen-bodies.md` (§A), `decisions/procedural-body-and-animation.md` (§D)

Status: **R&D direction; literature review landed.** Two-tier split is clean
(research §A).

**Usable-now (pragmatic).**
- **Motion Matching + procedural foot-IK** — deterministic, shipping
  production tech, sub-millisecond (research §A1, §A5).
- In-tier upgrade: **Environment-aware Motion Matching** (~0.8 ms, still
  deterministic) for terrain/obstacle response without leaving the
  deterministic regime (research §A8).
- **Learned Motion Matching** as the **neural-but-deterministic upgrade** —
  fixed-weight deterministic, the best neural+deterministic fit in the survey;
  the natural step off the MM floor (build-time-trained → deterministic eval —
  exactly the sanctioned shape) (research §A2).
- **Slice-planned floor:** `decisions/body-and-locomotion-slice.md` ships
  **analytic foot-IK + procedural locomotion first** (no motion-database
  dependency, deterministic, reads `MovementState`), with Motion Matching /
  Learned MM as a **deferred** upgrade gated on a license-clean,
  nix-reproducible motion set (the explicit open dependency).

**Aspirational (SOTA / research).**
- **Physics-RL / neural environment-responsive animation** — **DReCon** is the
  production bridge (MM target + RL physics tracker), **MaskedMimic** the
  ceiling. **Gated on a bit-deterministic fixed-step physics solver + a
  mean-action policy** — the hardest determinism case in the survey, and that
  solver is itself an open dependency (research §A6, §Open questions).
  - **The ceiling, stated precisely:** **full-body physically-SIMULATED control,
    not kinematic playback** (foot-IK / MM are the kinematic floor; balance,
    contact, momentum, recovery *emerge* from satisfying physics). Generalization
    is the crux on two axes: **body PLAN** (humanoid / taur / nonhuman) allows a
    small **discrete** set of plan-specific controllers, but **body BUILD** (the
    continuous chest/weight/height/proportion morph axes) must **not** explode
    into per-config models — use **one morphology-CONDITIONED controller per
    plan**, taking the body's morph parameters as input and trained with
    morphology randomization to amortize over the continuous build manifold. The
    **interlock:** that conditioning vector is the **same `BodyState` morph
    vector** the procgen-body system exposes — body and controller share one
    morphology parameterization (`decisions/procedural-body-and-animation.md`
    §D.1, §F; `decisions/body-and-locomotion-slice.md` §3.5). **Open / next
    lever:** the **morphology-generalizing-control** sub-area (body-agnostic /
    morphology-conditioned policies, metamorph-style) was **not** in the
    2026-06-03 lit review; a **targeted follow-up review is needed** (TODO.md).
- **Diffusion motion models: build-time only** — generate/author motion
  offline, bake to clips or into the MM database; never in the hot loop
  (research §A7).

### Transformation / morphing — `decisions/procedural-body-and-animation.md` (§C), `research/animation-morphing-procgen-bodies.md` (§B), `decisions/transformation-lore.md`

Status: **R&D direction; literature review confirms an honest unsolved gap.**

**Usable-now (pragmatic).**
- **Within-family blendshape morphs** (within-topology) — trivially
  deterministic, real-time (research §B1).
- **Female↔male** with embryological homology (clitoris↔glans, labia↔scrotum
  morph into each other, not crossfade) — lives as blendshapes precisely
  because every target shares one topology (research §C4;
  procedural-body-and-animation.md §C).
- **Modular mesh-swap-with-crossfade** for body-plan changes (the engine
  side-step; Unreal *Modular Characters*) (research §B4).
- **Pre-baked offline morph sequences for hero transformations** —
  deterministic replay of a baked artifact (research §B2, §Synthesis).

**Aspirational (SOTA / research) — the honest unsolved gap.**
- **Seamless real-time topology-changing metamorphosis *with continuous
  skinning*** is **genuinely unsolved** in the literature. The core blocker is
  the **skinning discontinuity**: blendshapes are same-topology only, a new
  limb needs new bones+weights which breaks the fixed vertex→bone binding, and
  **no production method morphs topology while maintaining continuous
  skinning** (research §B4, §Synthesis — HONEST GAP).
- The offline building blocks are the implicit / level-set / **4Deform**
  methods — none report real-time (research §B2–B3).
- This correctly sits in the aspirational tier; the baked-offline + modular-swap
  floor is the **honest usable-now floor, not a copout** (the forbidden copout
  is *redefining* across-form change as "not a morph" or a discrete
  regen-event) (research §Synthesis).
- Cross-cuts the **Secondary / soft-body** pillar: physics-driven
  transformation treats a morph target as an *authored moving rest-state* the
  surrogate tracks dynamically (TODO.md; DESIGN.md, *physics-driven bodily
  transformation*).

### Secondary / soft-body physics — DESIGN.md (*Secondary / soft-body physics*; *the animation/fidelity bet*), TODO.md (*Body / animation backlog*)

Status: **open R&D bet, multi-year horizon.**

**Usable-now (pragmatic).**
- **Jiggle-bones-tier floor** — spring-driven dynamic bones (VRChat-style
  dynamic bones; mass-spring + shape matching), the industry baseline for
  secondary motion (ears, tails, flesh). Explicitly **not sufficient** (no
  volume preservation, no self/world collision — reads as wobbly sticks) but it
  is the cheap, well-trodden floor (DESIGN.md; TODO.md).
- Specialized cheap solvers per phenomenon: **PBD for cloth**, purpose-built
  soft-body solvers for breast/glute/belly/fat/hair, GPU compute, hierarchical
  sim LOD (DESIGN.md, *the animation/fidelity bet*).

**Aspirational (SOTA / research).**
- **Volume-preserving, deterministic real-time surrogate** with proper self-
  and world-collision, evaluated dynamically (not canned). Two surrogate
  shapes: (a) **reduced-order / subspace deformable dynamics**; (b) **learned
  dynamics** trained against an offline accurate sim. Either must be
  **deterministic** (fixed weights / deterministic eval) to satisfy the
  seeded-sim invariant (DESIGN.md; TODO.md).
- **Fine-grained contact deformation** — fingers pressing into tissue, local
  bulging — and the harder rung, **full-hand cupping / squishing / grasping**
  (multiple contact regions, large-strain, visible volume redistribution
  between/around splayed fingers). Pushes toward **learned/hybrid surrogates**
  (global base + local contact enrichment), not pure modal reduction; likely
  requires an **iterated predict-then-project solve** (XPBD-style constraint
  projection) with a deterministic stopping rule and a read-only rest-volume
  invariant (DESIGN.md; TODO.md).
- Cross-reference `~/git/rhizone/playmate` (`frond`) during the refining stage.

### NPC mind / language / multi-modal expression — `decisions/npc-mind-and-language.md`

Status: **R&D pillar — not a frozen spec.** Three peer bets of the
deterministic-surrogate shape (language generator, soft-body sim,
embodied-expression realizer).

**Usable-now (pragmatic).**
- **Simulation underneath, rendering on top** applied to cognition: a
  simulation-driven NPC state (mood, beliefs, relationships, schedules) +
  **authored fragments** + **procedural recombination** — the proven HHS+ /
  Accidental Woman / Lilith's Throne pattern that delivers hundreds of hours
  *without LLMs*, deterministic (DESIGN.md, *Platform for depth*;
  npc-mind-and-language.md).
- The player's half of a conversation as **composable social affordances**
  (reuses/extends the affordance substrate) (npc-mind-and-language.md).
- **Text is the unit test / lower bound**; visemes + simulated-mood facial
  expression are table-stakes embodied channels available now (DESIGN.md,
  *Face tracking and visemes*).
- **LLM-compatible but not LLM-required** — build the substrate to stand on
  proven patterns; design interfaces so LLM-driven characters can slot in
  later; don't foreclose, don't depend on what isn't viable yet (DESIGN.md).

**Aspirational (SOTA / research).**
- A real cognitive/personality **brain**: persistent memory, beliefs, drives,
  emotion, relationships, theory-of-mind, personality, autonomous inner life
  (`fuwafuwa`/`ashwren`/`existence` patterns), seeded-deterministic
  (npc-mind-and-language.md).
- **Beyond-SOTA grammar-and-semantics language generation** — deterministic
  (build-time-trained → deterministic eval; mad-libs and hot-loop LLM both
  ruled out) (npc-mind-and-language.md; DESIGN.md bet (b)).
- **Embodied expression / performance** — one communicative intent rendered
  across multiple channels (facial expression, gaze, gesture, posture,
  proxemics, prosody, in-world action), all deterministic projections; the
  release build, load-bearing in VR. Consumes the animation/soft-body pillar
  (npc-mind-and-language.md; DESIGN.md bet (c)).
- Open: brain architecture/fields/update rules; the generator's concrete
  approach; intent→embodied-channel mapping; cross-channel coherence/timing
  (npc-mind-and-language.md; TODO.md).

### Semantic layer / world-understanding — `decisions/semantic-layer.md`

Status: **FOUNDATIONAL R&D DIRECTION — open problem.** The **deepest**
bet — the brain reasons over it, the NLG speaks from it, the affordance verbs
mean something because of it.

**Usable-now (pragmatic).**
- No usable-now split is recorded in the decision doc for this pillar, so —
  stated conservatively from what is proven — a **modest curated / parametric
  knowledge floor**: hand-authored facts and parametric data attached to the
  concepts the shippable activities actually need (the affordance verbs, the
  authored NPC fragments). This is the **finite fact-dump** the aspirational
  layer explicitly calls a *copout for understanding* (semantic-layer.md) — so
  it is an honest floor for shipping concrete content, **not** a stand-in for
  the layer's actual generalize-to-the-novel-case goal. *(Pragmatic floor
  stated conservatively; not a recorded commitment — see Open questions.)*

**Aspirational (SOTA / research).**
- A **build-time-extracted, prevalence-weighted knowledge graph** (RDF
  triples; the weights are the point — typicality/distribution as the
  beginnings of judgment) that **generalizes to the novel case**, with runtime
  reasoning fully deterministic (traverse / compose / query / seeded-sample;
  no hot-loop black box) (semantic-layer.md).
- The hard part is **build-time extraction & cleaning** (dedup,
  sense-disambiguation, trustworthy prevalences) — a build-time task, exactly
  where inference is sanctioned, so an offline extractor mining the corpus is
  **not a copout and not a determinism violation** (semantic-layer.md).
- **Semantic LOD ("mipmaps for meaning")** — coarse reasoning nearly free
  everywhere, real compute only on the focal thing; coarse must be a *faithful
  coarsening* of fine (no popping), seed-stable like the interpreter↔compiler
  equivalence (semantic-layer.md).

### Environment authoring — DESIGN.md (*Authoring your environment*; the 6th power fantasy)

Status: committed first-class power fantasy at parity with cosmetics; no
two-tier split is recorded in the docs, so the aspirational side is stated
conservatively / open.

**Usable-now (pragmatic).**
- **Space / decoration** and **soundscape / music curation** using the same
  verbs as cosmetics (browse, acquire, arrange, curate, express) — proven
  prior art: Warframe orbiter/dojo + Somachord, Palia house-building, Animal
  Crossing interiors, VRChat space personalization. A real economy (acquiring
  furniture/decor/tracks) (DESIGN.md). Conventional life-sim tech; shippable.
- Doubles as a **concrete persistence accumulator** (your home, your stuff,
  your soundscape accumulate without gear/stats/levels) (DESIGN.md).

**Aspirational (SOTA / research) — open.**
- The frontier is the same **full-diegetic compositional depth** axis as
  interaction: how far authoring can climb toward in-fiction composition with
  **zero exposed scripting surface** (the ProtoFlux immersion break is refused;
  full diegeticism is "largely unsolved in the medium") (DESIGN.md,
  *Compositional power and the diegetic-integration axis*). **Open** — an
  aspiration aligned with the thesis, not a solved commitment. *(No dedicated
  decision doc; aspirational side stated from DESIGN.md's diegetic-axis
  framing.)*

### Determinism / persistence / multiplayer — DESIGN.md (*Architecture commitments*), `decisions/units-and-scale.md` (cross-cutting)

Status: **cross-cutting foundation**, not a single pillar. Underwrites every
aspirational bet's "deterministic surrogate" shape.

**Usable-now (pragmatic).**
- **Seed + ordered action-log** as the save format; replay/sharing, timeline
  branching (lived-history as a tree), leaderboard substrate; reconnect via
  snapshot (DESIGN.md, *Deterministic seeded simulation*).
- **Self-hosted multiplayer** (Minecraft/Valheim/Zomboid shape) — no
  live-service obligations; mix-by-responsibility netcode (client-side
  prediction for own movement, server-authoritative shared state, deterministic
  lockstep for the seeded sim, eventually-consistent for cosmetics) (DESIGN.md,
  *Netcode*).
- **1 unit = 1 meter**, real human scale, real gravity — pinned because VR is
  first-class (units-and-scale.md).

**Aspirational (SOTA / research) — open.**
- **Cross-platform float determinism** is hard; commit to fixed-point for the
  sim layer, *or* accept replay validity bounded by runtime (Trackmania accepts
  the latter) (DESIGN.md). MM/physics-RL determinism specifically needs
  float-order / tie-break / cross-platform pinning and a bit-deterministic
  fixed-step physics solver (research §Open questions) — **open dependency**.
- **Single seed + action log in multiplayer** without hurting multiplayer —
  flagged, not solved (DESIGN.md, *Open questions*).

---

## 3. Near-term pragmatic critical path

Ordered, drawn only from what is proven/ready (no invented steps):

1. **Movement: remaining backlog verbs + presets as data** — air burst,
   charge, aim glide, wall cling, etc., each a `verbs/*.kit.json` enabled in a
   manifest; named presets as manifest selections. Substrate already done
   through Slice 4 (movement-substrate.md; TODO.md).
2. **Affordance Slice 1** — schema + loader + deterministic interpreter;
   reproduce the sandbox chains as data (affordance-substrate.md).
3. **Affordance Slice 2** — GDScript compiler + golden-trace equivalence.
4. **Affordance Slice 3** — a new dense interactable authored purely as data,
   zero engine change (the payoff proof).
5. **Body/locomotion usable-now slice** — **MakeHuman CC0 canonical-topology
   base + within-family blendshape morph stack + LBS**, animated with **analytic
   foot-IK + procedural locomotion** first (Motion Matching deferred behind a
   license-clean nix-reproducible motion set), with the age morph axis wired to
   the Layer-1 NSFW gate from the first body-state slice. Designed +
   slice-planned in **`decisions/body-and-locomotion-slice.md`** (the
   nix-reproducible asset pipeline parses MakeHuman CC0 `.target`/`base.obj`/
   `.mhskel` directly — no Blender, builds with the existing Godot+xvfb shell).
   License-verify SMPL/Meshcapade before any reliance (we ship none of it).
6. **Apply the pure-text litmus** to each activity surface as it gets its
   design pass (reference-analysis.md).

These ship a real, embodied, interactive game on proven tech while the bets
mature.

---

## 4. Aspirational research agenda

The open beyond-SOTA bets — each a **multi-year, deterministic-surrogate-shaped**
problem (offline-accurate / build-time-trained → deterministic real-time
surrogate; no hot-loop inference):

- **(a) Physically-accurate real-time soft-body / contact deformation /
  physics-driven transformation** — `DESIGN.md` (*Secondary / soft-body
  physics*), TODO.md. Literature: none dedicated yet; surrogate shapes
  (reduced-order vs learned, predict-then-project) recorded in DESIGN.md/TODO.md.
- **(b) Deterministic beyond-SOTA grammar-and-semantics language generation** —
  `decisions/npc-mind-and-language.md`.
- **(c) Embodied expression / performance** (intent → expression / gaze /
  gesture / posture / proxemics / prosody / action) — `decisions/npc-mind-and-language.md`;
  consumes the animation/soft-body pillar.
- **(d) The semantic world-understanding layer** — `decisions/semantic-layer.md`.
  The **deepest, foundational** bet; underlies (b), (c), and the affordance
  verbs' meaning.
- **(e) Procedural-body / animation aspirational tiers** —
  `decisions/procedural-body-and-animation.md`, with the literature review
  status in `research/animation-morphing-procgen-bodies.md`: generative bodies
  as a build-time oracle; physics-RL / neural env-responsive animation (gated on
  a bit-deterministic fixed-step physics solver); and the **honest unsolved
  gap** of seamless real-time topology-changing metamorphosis with continuous
  skinning.

Lit-review status (research/animation-morphing-procgen-bodies.md, 2026-06-03):
animation and procgen-body usable-now tiers are well-grounded in shipping tech;
topology-changing morph is confirmed unsolved; several citations are flagged
unverified/low-confidence and the SMPL/Meshcapade license is to verify before
relying — those flags are load-bearing and must not be silently upgraded.

---

## 5. Honest notes / open questions (carried, not resolved)

- **Semantic-layer usable-now floor is not a recorded commitment** — stated
  conservatively here as a curated/parametric floor; the decision doc records
  only the aspirational layer and explicitly calls the finite fact-dump a
  copout-for-understanding. Treat the floor as a shipping expedient for concrete
  content, not as the layer (semantic-layer.md).
- **Environment-authoring aspirational tier has no dedicated doc** — its
  frontier is folded into the diegetic-integration axis; **how far full
  diegeticism is reachable, and for which systems, is open** (DESIGN.md).
- **Physics-RL animation and soft-body are gated on a bit-deterministic
  fixed-step physics solver** that does not yet exist — an open dependency
  shared across bets (research §Open questions).
- **Cross-platform float determinism** and **single seed + action log in
  multiplayer** remain flagged-not-solved (DESIGN.md, *Open questions*).
- **Seamless real-time topology-changing skinned metamorphosis is genuinely
  unsolved** — placed in the aspirational tier; the baked + modular-swap floor
  ships now (research §Synthesis).
- **Content authoring strategy** (procedural / AI-assisted / hand-authored /
  community — likely all four, weights TBD), **persistence model** detail,
  **sources-of-change priority**, and **per-activity design** remain open
  (DESIGN.md, *Open questions*; TODO.md).
- **The list grows** — power fantasies, activities, and bets are recorded as
  commitments land; this roadmap does not freeze the catalogue (DESIGN.md,
  *Meta-commitments*).
