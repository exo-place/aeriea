# Literature review — character animation, topology-changing morphing, procgen bodies

Status: **LITERATURE REVIEW — snapshot, dated (2026-06-03).** Informs the
R&D direction in `../decisions/procedural-body-and-animation.md` (the "E.
Literature review needed" item lands here). This is a dated research
snapshot, not a frozen plan; citations and confidence flags are carried
verbatim from three research briefs. Several citations are flagged
unverified / low-confidence below — those flags are load-bearing and must
not be silently upgraded.

---

## What this surveys, and the lenses applied

Three families needed for the procedural-body/animation pillar:

- **(A)** Procedural / learned / physics-based character animation — the D
  tier of the decision doc (full procedural animation, env-responsive,
  potentially neural walk cycles).
- **(B)** Topology-changing mesh morphing / metamorphosis — the C
  across-form tier (limb-count / body-plan change, biped↔taur).
- **(C)** Procedural / parametric human body generation + deformation
  topology — the A (quality-first procgen) and B (topology philosophy)
  parts.

Each method is read through three lenses, all from CLAUDE.md / the decision
doc:

1. **Real-time feasibility** — does it run in the per-frame hot loop, or is
   it offline-grade?
2. **Determinism** — the hard invariant. The acceptable shape is
   *build-time-trained → deterministic-eval at runtime*; online / per-query
   / stochastic-in-hot-loop inference is forbidden. A method is "OK" only if
   it is deterministic at eval (fixed weights, fixed inputs, pinned
   float-order) or can be baked offline to a deterministic replayable
   artifact.
3. **The two-tier split** — *usable-now* (proven, shippable, built fast,
   degrades gracefully) vs *aspirational-SOTA* (the open research bet).

---

## A. Procedural / learned / physics-based character animation

Two-tier split is clean here: **usable-now = Motion Matching + foot-IK**
(naturally deterministic); **aspirational = physics-RL + neural generative**
(determinism is the hard part).

### A1. Motion Matching (usable-now floor)

Data-driven; searches a motion database each frame for the best-matching
pose given current state + future goal. No clips authored as transitions.

- **For Honor / Simon Clavet, GDC 2016** (GDC Vault) — the production
  introduction of Motion Matching.
- **UE5.4+ PoseSearch plugin** — engine-native MM.

Maturity: shipping production tech. Real-time: sub-millisecond per search.
**Determinism: deterministic by construction** — a database lookup, no
learned weights, no sampling. *Caveat:* "deterministic by construction"
still requires pinning float-ordering, tie-break rules, and cross-platform
behavior to get bit-identical results (CLAUDE.md cross-platform parity).

### A2. Learned Motion Matching (the neural-but-deterministic upgrade)

Compresses the MM database into neural networks (a decompressor +
stepper + projector) — same MM behavior, much smaller memory, fixed
weights.

- **Holden, Kanoun, Perepichka, Popa — Learned Motion Matching, ACM TOG /
  SIGGRAPH 2020.** Code: `github.com/orangeduck/Motion-Matching`. Writeup:
  `theorangeduck.com/page/learned-motion-matching`.

Maturity: published + open reference implementation. Real-time: yes.
**Determinism: fixed-weight deterministic** — the *best neural + deterministic
fit* in this whole survey. This is the natural neural upgrade path off the
MM floor.

### A3. Phase-based neural synthesis

Networks conditioned on a learned motion phase; environment / scene aware.

- **PFNN — Phase-Functioned Neural Networks (Holden, Komura, Saito, TOG /
  SIGGRAPH 2017)** — `https://dl.acm.org/doi/10.1145/3072959.3073663`;
  terrain / obstacle aware.
- **Neural State Machine (Starke, Zhang, Komura, Saito, TOG / SIGGRAPH Asia
  2019)** — character–scene interactions;
  `https://www.research.ed.ac.uk/en/publications/neural-state-machine-for-character-scene-interactions/`.
- **Local Motion Phases (Starke et al., TOG / SIGGRAPH 2020)** —
  `https://dl.acm.org/doi/abs/10.1145/3386569.3392450`.

Maturity: published, influential. Real-time: yes. **Determinism: deterministic
at eval** given fixed weights/inputs — but **watch autoregressive drift**
(small per-frame errors accumulate; cross-platform float differences can
diverge a long rollout). Deterministic only with the same pinned numeric
path.

### A4. Motion VAEs

Generative latent model of motion; sample the latent to produce motion.

- **Ling, Zinno, Cheng, van de Panne — Character Controllers Using Motion
  VAEs, TOG / SIGGRAPH 2020** — `https://arxiv.org/abs/2103.14274`; code
  `github.com/electronicarts/character-motion-vaes`.

Maturity: published + EA reference code. Real-time: yes. **Determinism:
latent sampling is stochastic** — but can be fixed/seeded to recover
determinism (then it's effectively a deterministic decoder).

### A5. Foot-IK (usable-now, pairs with A1)

Two-bone analytic IK for foot planting / ground adaptation.

- Analytic two-bone IK; free; available in Unity / UE / **ozz-animation** —
  `https://guillaumeblanc.github.io/ozz-animation/samples/foot_ik/`.

Maturity: standard, trivial. Real-time: yes. **Determinism: analytic,
deterministic.** Pairs with Motion Matching as the usable-now tier.

### A6. Physics-based RL (aspirational ceiling + the production bridge)

Physically-simulated characters trained with RL to imitate / synthesize
motion. Highest fidelity and interactivity; determinism is hardest.

- **DeepMimic (Peng et al.)** — `github.com/xbpeng/DeepMimic`; **commonly
  cited as SIGGRAPH 2018 — YEAR UNVERIFIED, do not rely on it without
  checking.**
- **AMP — Adversarial Motion Priors (Peng, Ma, Abbeel, Levine, Kanazawa,
  TOG / SIGGRAPH 2021)** — arXiv 2104.02180.
- **MaskedMimic (NVIDIA + Peng, TOG / SIGGRAPH Asia 2024)** — arXiv
  2409.14393. The current **ceiling** for unified physics-based controllers.
- **DReCon (Bergamin, Clavet, Holden, Forbes, TOG / SIGGRAPH Asia 2019)** —
  `https://dl.acm.org/doi/10.1145/3355089.3356536`. Motion Matching as the
  kinematic target + an RL physics tracker — **the production bridge** from
  the MM floor to physics-RL.

Maturity: research → early production (DReCon is the bridge). Real-time:
the *controller* eval is cheap; the **physics solver** is the cost and the
determinism risk. **Determinism: the hardest case in this survey.** Needs a
**bit-deterministic fixed-step physics solver** plus a deterministic policy
(use the **mean action**, not a sampled one). Gated on that solver existing.

### A7. Diffusion motion models (build-time only)

Denoising-diffusion text-to-motion / motion generation.

- **MDM — Motion Diffusion Model (Tevet et al.)** — arXiv 2209.14916.
- **EMDM (ECCV 2024).**
- **StableMoFusion** — arXiv 2405.05691.

Maturity: active research. Real-time: **no** — expensive iterative
denoising. **Determinism: stochastic** (seed + DDIM gives reproducibility,
but it's not hot-loop-able). **Verdict: build-time only** — generate /
author motion offline, bake to clips or into the MM database; never in the
loop. *Confidence on diffusion specifics: medium.*

### A8. Environment-aware Motion Matching

MM extended with explicit obstacle awareness in the search.

- **Ponton, Andrews, Andújar, Pelechano — Environment-aware Motion Matching,
  TOG 2025** — arXiv 2510.22632; ~0.8 ms per search with obstacle
  avoidance.

Maturity: very recent (2025). Real-time: yes (~0.8 ms). **Determinism:
deterministic** (still a search). A direct upgrade to the MM floor that
buys environment responsiveness without leaving the deterministic regime.

### Determinism scorecard — animation family

| Method | Real-time | Determinism | Tier |
|---|---|---|---|
| Motion Matching (A1) | sub-ms | deterministic by construction (pin float-order / tie-break / cross-platform) | usable-now floor |
| Foot-IK two-bone (A5) | yes | analytic, deterministic | usable-now floor |
| Environment-aware MM (A8) | ~0.8 ms | deterministic (search) | usable-now upgrade |
| Learned Motion Matching (A2) | yes | fixed-weight deterministic | **neural-but-deterministic upgrade (best fit)** |
| PFNN / NSM / Local Motion Phases (A3) | yes | deterministic eval; **watch autoregressive drift** | neural upgrade (with care) |
| Motion VAEs (A4) | yes | stochastic; fix/seed latent to recover | neural (seed required) |
| Physics-RL: DeepMimic / AMP / MaskedMimic / DReCon (A6) | controller cheap, **solver is the cost/risk** | hardest — needs bit-deterministic fixed-step physics + mean action | aspirational (gated on solver) |
| Diffusion: MDM / EMDM / StableMoFusion (A7) | no (iterative denoise) | stochastic (seed + DDIM) | **build-time only** |

---

## B. Topology-changing mesh morphing / metamorphosis

**BLUF: real-time seamless topology-changing metamorphosis is NOT solved
and NOT shippable.** The literature splits into same-topology
correspondence+blend (trivially deterministic, but can't change topology)
and topology-changing implicit / neural methods (offline-grade, bakeable).
The under-discussed hard part is the *skinning interplay* — which is the
actual blocker for a live skinned character.

### B1. Classical same-topology correspondence + blend (no genus change)

Establish a correspondence between two meshes, remesh to a compatible
connectivity, then interpolate. **Once compatible, interpolation is a
blendshape** — trivially deterministic and real-time — but it **cannot
change topology.**

- **Kanai, Suzuki, Kimura — harmonic-map morphing, PG 1997 / Visual
  Computer 1998** — `https://graphics.c.u-tokyo.ac.jp/archives/pg97.pdf`.
- **Lee, Dobkin, Sweldens, Schröder — Multiresolution Mesh Morphing,
  SIGGRAPH 1999.**
- **Kraevoy & Sheffer — Cross-parameterization and compatible remeshing,
  TOG / SIGGRAPH 2004** — `https://dl.acm.org/doi/10.1145/1015706.1015811`.
- **Alexa — survey (Computer Graphics Forum 2002).**

Maturity: classical, well-understood. Real-time: yes (post-compatibility).
**Determinism: trivially deterministic** — it reduces to a blendshape.
Limit: **same topology only.**

### B2. Topology-changing — implicit / level-set (offline-grade)

Represent shapes as implicit functions / level sets and interpolate the
*field*; re-extract the surface each frame. Topology change is free because
no explicit mesh is carried.

- **Turk & O'Brien — Shape Transformation Using Variational Implicit
  Functions, SIGGRAPH 1999** —
  `https://faculty.cc.gatech.edu/~turk/my_papers/schange.pdf`.
- **Breen & Whitaker — level-set metamorphosis, IEEE TVCG 2001.**
- **DeCarlo & Gallier — Topological Evolution of Surfaces, GI 1996.**
- Spherical genus-*n*-to-*m* parameterization (background).
- **Kravtsov et al. — skeleton-driven controlled metamorphosis, CGF 2014.**

Key trick: **avoid pinching by never carrying an explicit mesh** —
re-extract via marching cubes each frame. Result is **fluid / blobby and
hard to control anatomically**; **offline-grade**, but **bakeable to a
deterministic sequence**. Real-time: no. Determinism: bakeable.

### B2b. Topology-adaptive explicit

- **Mandad et al. — arXiv 2012.05536.**

### B3. Neural implicit morphing (offline-grade; SOTA is here)

- **DeepSDF (Park et al., CVPR 2019)** — latent interpolation between SDFs.
- **4Deform (Sang et al., CVPR 2025)** — arXiv 2502.20208; **free
  topology-changing interpolation via a neural velocity field + level set —
  SOTA, but no real-time reported.**
- **Volume Preserving Neural Shape Morphing (Buonomo et al., CGF 2025)** —
  **note: trends OPPOSITE to what we need — it *preserves* topology.**
- **Neural Implicit Morphing of Faces (Schardong, Novello, CVPRW 2024).**
- **Functional maps (Ovsjanikov 2012)** — **MEDIUM confidence, background
  only, unfetched.** Do not lean on it.

Maturity: research, SOTA = 4Deform. Real-time: **no** (none report it).
**Determinism: a NN is deterministic given fixed weights/inputs, BUT
GPU-FP / backend-dependent AND needs per-frame marching cubes → use
OFFLINE bake only.**

### Real-time feasibility (topology-changing morph)

| Family | Topology change | Real-time | Determinism | Use |
|---|---|---|---|---|
| Same-topology correspondence+blend (B1) | **no** | yes | trivially deterministic (= blendshape) | within-form floor |
| Implicit / level-set (B2) | yes | no (per-frame marching cubes) | bakeable to deterministic sequence | offline bake |
| Neural implicit / 4Deform (B3) | yes | no (no real-time reported) | det. given fixed weights but GPU-FP-dependent + needs marching cubes | offline bake only |

### B4. The skinning interplay — the actual blocker (under-discussed)

This is the part most write-ups skip and the reason live topology morph is
genuinely unsolved for a *skinned* character:

- **Blendshapes are same-topology only** — same vertex set, moved (GPU Gems
  3 ch. 3,
  `https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-3-directx-10-blend-shapes-breaking-limits`).
- **A new limb needs new bones + new weights**, which **breaks the fixed
  vertex→bone binding** skinning depends on.
- **Engines side-step this with modular skeletal-mesh SWAP, not morph**
  (Unreal, *Working with Modular Characters*,
  `https://dev.epicgames.com/documentation/en-us/unreal-engine/working-with-modular-characters`).
- **There is NO production method that morphs topology while maintaining
  continuous skinning.** This is the core blocker.

### Two-tier (topology-changing morph)

- **Tier 1 / usable-now:** superset-mesh blendshapes (within-topology) +
  modular mesh-swap-with-crossfade + pre-baked offline morph sequences for
  hero transformations (deterministic replay of a baked sequence).
- **Tier 2 / aspirational:** true live topology metamorphosis — **unsolved**;
  the implicit / level-set / 4Deform methods are the offline building blocks.

---

## C. Procedural / parametric human body generation + deformation topology

### C1. Parametric / deterministic models (the usable, game-ready path)

These are vertex-based, LBS-skinnable, morphable, deterministic — the
"everything is a morph on one shared topology" pattern.

- **SCAPE (Anguelov et al., TOG / SIGGRAPH 2005)** —
  `https://dl.acm.org/doi/10.1145/1073204.1073207`; triangle-deformation
  model, **superseded** by SMPL.
- **SMPL (Loper, Mahmood, Romero, Pons-Moll, Black, TOG / SIGGRAPH Asia
  2015)** — `https://dl.acm.org/doi/10.1145/2816795.2818013`,
  `https://smpl.is.tue.mpg.de/`; **LBS, vertex-based, engine-compatible,
  ~6890 verts.**
- **SMPL-X (Pavlakos et al., CVPR 2019)** — arXiv 1904.05866,
  `https://smpl-x.is.tue.mpg.de/`, `github.com/vchoutas/smplx`; adds hands
  (MANO) + face (FLAME), **~10475 verts, unified topology.**
- **STAR (Osman, Bolkart, Black, ECCV 2020)** — arXiv 2008.08535;
  sparse-local correctives, SMPL drop-in.
- **SUPR (Osman et al., ECCV 2022)** — `github.com/ahmedosman/SUPR`;
  federated, part-based.

**LICENSE CAVEAT — load-bearing:** the SMPL family is **MPI
research / non-commercial**; commercial use needs a **separate license
(Meshcapade)**. **Verify with Meshcapade / MPI before relying on it.**

Maturity: SMPL/-X are de-facto standard. Real-time: yes (LBS). Determinism:
**deterministic, morphable, game-ready.**

### C2. Production parametric authoring tools

- **MakeHuman** — AGPL source but **CC0 mesh exports — the cleanest license**;
  quad topology; indie-quality; MPFB Blender plugin;
  `http://www.makehumancommunity.org/content/license_explanation.html`.
- **"Anny" (NAVER)** — **LOW confidence, unvalidated.** Do not rely on.
- **Daz Genesis** — commercial EULA; **fixed unified topology + a morph
  stack on one rig** — proof that "everything is a morph on one topology"
  *scales* to a full content ecosystem; `http://docs.daz3d.com/`.
- **MetaHuman (Epic)** — AAA photoreal, but **UE-ONLY EULA**
  (`https://www.unrealengine.com/eula/mhc`) — **disqualified for a Godot
  project.**

### C3. Generative / stochastic body models

- **imGHUM (Alldieck et al., ICCV 2021)** — arXiv 2108.10842; implicit SDF
  generative human.
- **gDNA (Chen et al., CVPR 2022)** — arXiv 2201.04123;
  `github.com/xuchen-ethz/gdna`.
- **Diffusion / text-to-avatar** — AvatarStudio (arXiv 2311.17917),
  UltrAvatar (2401.11078), Instant3DHuman (2406.07516), SimAvatar
  (2412.09545). **MEDIUM confidence; arXiv IDs need re-verification; one
  returned ID "2604.23629" is INVALID — do NOT cite it.**

Maturity: research. Real-time: no (generation is offline). **Determinism:
sampled, NOT semantically controllable, candy-wrapper artifacts, not clean
topology.** Verdict: build-time content oracle only.

### Determinism table (procgen bodies)

| Family | Real-time eval | Determinism | Topology | Use |
|---|---|---|---|---|
| Parametric (SMPL/-X, STAR, SUPR; MakeHuman, Daz) | yes (LBS) | deterministic, morphable | one shared unified topology | game-ready floor |
| Generative (imGHUM, gDNA, diffusion avatars) | no | sampled, not semantically controllable | candy-wrapper, not clean | build-time oracle only |

### C4. Topology craft-knowledge (CRAFT, not academic — flag as such)

The B-section topology philosophy in the decision doc is **craft knowledge**,
not peer-reviewed results. Carry it as such:

- **Quad-dominant.**
- **Loops follow muscle / joint flow.**
- **Concentrate + extend loops past joints** (so bending zones have density).
- **Poles in low-deformation areas** — no 6+ poles, keep poles out of bend
  zones.
- **Align loops to the rotation axis.**
- **Concentric face loops around mouth / eyes** (Osipa, *Stop Staring*,
  Wiley, ISBN 9780470609903).
- References: `topologyguides.com/modeling-for-animation`,
  `cgcookie.com/posts/the-art-of-good-topology-blender`.

**Blendshape correspondence requires identical topology across all shapes**
(the Daz example; the same principle SMPL exploits). This is *why* the
decision doc's "one shared topology per body-plan family" is the linchpin:
F↔M morphs and embryological-homology morphs (clitoris↔glans, labia↔scrotum)
can only live as blendshapes if every target shares one topology.

---

## Synthesis / recommendations for aeriea

Mapped onto the decision doc's two tiers. Each area gets a usable-now floor,
a neural-but-deterministic upgrade where one exists, and an aspirational
ceiling with its determinism gate.

### Animation (D tier)

- **Usable-now:** **Motion Matching + procedural foot-IK** — deterministic,
  shipping tech, sub-ms. Upgrade in-tier to **Environment-aware Motion
  Matching** (~0.8 ms, still deterministic) for terrain/obstacle response
  without leaving the deterministic regime.
- **Neural-but-deterministic upgrade:** **Learned Motion Matching** —
  fixed-weight deterministic, the best neural+deterministic fit; the natural
  step off the MM floor (build-time-trained → deterministic eval, exactly
  the sanctioned shape).
- **Aspirational:** **physics-RL** — **DReCon** is the production bridge
  (MM target + RL physics tracker); **MaskedMimic** is the ceiling.
  **Gated on a bit-deterministic fixed-step physics solver** + mean-action
  policy. This is the hardest determinism case in the survey.
- **Diffusion: build-time only** — author/generate motion offline, bake to
  clips or into the MM database; never in the hot loop.

### Topology-changing morph (C across-form tier) — HONEST GAP

**Seamless real-time *skinned* topology-changing morph is unsolved.** The
core blocker is the **skinning discontinuity**: blendshapes are
same-topology only, a new limb needs new bones+weights which breaks the
fixed vertex→bone binding, and **no production method morphs topology while
maintaining continuous skinning** (B4).

- **Usable-now floor:** superset-mesh blendshapes (within-topology) +
  modular mesh-swap-with-crossfade + **pre-baked offline morph sequences for
  hero transformations** (deterministic replay of a baked artifact).
- **Aspirational:** true live topology metamorphosis — the implicit /
  level-set / **4Deform** methods are the offline building blocks; none
  report real-time.

**Reconciling with the decision doc's "morphs must be seamless including
topology, no copout" stance:** that *specific* capability — seamless,
real-time, *with continuous skinning* topology metamorphosis — is **genuinely
unsolved** in the literature. It therefore sits in the **aspirational tier**,
correctly. The baked-offline-deterministic-sequence + modular-swap floor is
the **honest usable-now floor, not a copout** — the copout the decision doc
forbids is *redefining* across-form change as "not a morph" or as a discrete
regen-event. Treating it as a real morph whose *real-time-skinned* form is an
open research bet (while the baked form ships now) honors the no-copout
stance: the requirement is kept, its hardest form is correctly placed in the
aspirational tier rather than waved away.

### Procgen bodies (A + B parts)

- **Usable-now:** **one canonical quad topology + a morph / blendshape stack
  + LBS** — the pattern that **SMPL-X = Daz = MetaHuman** all share (one
  unified topology, everything is a morph on it, one rig). This *is* the
  decision doc's "one shared topology per body-plan family."
  - **License-clean Godot path:** **MakeHuman CC0 exports as the base mesh**
    (cleanest license) + **SMPL-X's parameter structure as a design
    reference** for the morph/shape space.
  - **MetaHuman is OUT** (UE-only EULA). **Raw SMPL family needs a
    commercial license** — **verify with Meshcapade / MPI** before any
    reliance.
- **Aspirational:** generative models (**imGHUM / gDNA / diffusion avatars**)
  as a **build-time content oracle** — generate candidate bodies offline,
  then **bake / retopologize onto the canonical topology** so the shipping
  asset stays deterministic and morph-compatible. Generative output is never
  shipped raw (candy-wrapper artifacts, no clean topology, not semantically
  controllable).
- **Topology best-practices carry forward (craft, C4):** quad-dominant;
  loops follow muscle/joint flow; poles out of bend zones; concentric face
  loops; and the linchpin — **shared topology ⇒ blendshape correspondence ⇒
  how F↔M and embryological-homology morphs all live on one topology.**

---

## Open questions / what to verify before relying on this

Unverified-citation flags and license needs, carried forward verbatim:

- **DeepMimic year (SIGGRAPH 2018) is UNVERIFIED** — confirm before citing.
- **Diffusion-motion specifics (A7) are MEDIUM confidence.**
- **Functional maps (Ovsjanikov 2012)** — MEDIUM confidence, background
  only, **unfetched**; do not lean on it.
- **"Anny" (NAVER)** — **LOW confidence, unvalidated**; do not rely on.
- **Generative-avatar arXiv IDs need re-verification**, and the returned ID
  **"2604.23629" is INVALID — do not cite it.**
- **SMPL family license** — research / non-commercial; **commercial needs a
  separate license (Meshcapade); verify with Meshcapade / MPI.**
- **MetaHuman is disqualified** for Godot (UE-only EULA) — confirmed
  constraint, not a verification item.
- **MM-family "deterministic by construction"** still needs **float-order /
  tie-break / cross-platform pinning** to be bit-deterministic — verify on
  target platforms.
- **Physics-RL determinism** is gated on a **bit-deterministic fixed-step
  physics solver** existing — that solver is itself an open dependency.

---

*Snapshot date: 2026-06-03. Synthesized from three research briefs (A:
character animation; B: topology-changing morphing; C: procgen bodies +
topology). Re-verify flagged citations before they become load-bearing.*
