# Procedural body + animation (mesh, morph, transformation, animation)

Status: **R&D DIRECTION — open; two-tiered (usable-now + aspirational-SOTA)**
(2026-06-03)

Scope: a faithful capture of an R&D direction developed in design
conversation, covering (a) fully procedural human bodies at a real quality
bar, (b) a principled topology philosophy for the procgen meshes, (c) the
escalating tiers of *morphing* those bodies (within-form, female↔male,
across-form / topology-changing), (d) full procedural / environment-
responsive animation, and (e) the literature the team genuinely needs to
read for the aspirational tiers. It records only what was decided; it
invents no specific mechanisms beyond what was stated and coins no names.
Every genuinely open piece is marked open.

This is the **two-tier** pillar applied to the body/animation surface: a
*usable-now tier* (proven, shippable tech, built fast, good-enough) and an
*aspirational-SOTA tier* (the open research bet). It must degrade
gracefully from aspirational to usable — see DESIGN.md, *aeriea is a
research program* (the two-tier framing) and *the animation/fidelity bet*.
The aspirational tiers here are **peer to the other deterministic-surrogate
bets** (soft-body, language, embodied performance, semantic layer): hard
accuracy paid for offline / at build time, lowered to a deterministic
real-time surrogate, with online / per-query inference forbidden in the hot
loop (CLAUDE.md: LLM/inference as a build-time oracle; determinism a hard
invariant).

---

## A. Procedural human bodies — quality-first

Fully procedurally generated human bodies that **don't look like shit** —
not the usual uncanny procgen. Quality is the bar, stated up front: the
procgen path only counts if the output is genuinely good, not merely
parametrically valid. (The usual failure mode — recognizably-generated,
uncanny, off — is the thing this refuses, the same way the rest of the
design refuses copouts.)

## B. Topology design philosophy (a stated requirement)

The procgen meshes need a clear, **principled topology philosophy**: where
the edge loops go, and *why*. This is a requirement, not an afterthought.

- **Loops follow deformation / muscle / joint flow** — clean bending at the
  joints, expression at the face; loops laid out so the mesh deforms the way
  the underlying anatomy moves.
- **Quad-dominant**, with **poles parked in low-deformation zones** so the
  poles don't sit where the mesh has to bend or emote.
- **A consistent topology template per body-plan family** — one shared
  topology per body plan, used by everything downstream so that morphs,
  skinning / animation, and the soft-body sim all rely on the *same*
  topology. The consistent topology is the common ground (see *F. The
  interlock*).

**Hard spec (from "morphs must be seamless").** The topology must keep the
**entire intended within-family morph envelope pinch-free** — every
proportion / sex / weight / muscle extreme in the family must deform
cleanly, with no pinching, under all of them. This is a spec the topology
must *satisfy*, not a hope it might. The topology is correct only if the
whole morph envelope it is meant to support is pinch-free.

## C. The morph tiering (escalating difficulty)

A correction recorded precisely so it is not lost: **"morph" ≠
"blendshape".** Blendshapes are topology-*preserving* (same vertices, moved).
Morphing in general is *not* topology-preserving — topology-changing mesh
metamorphosis is a real technique, not a non-thing. **Morphs must be
seamless — that is a requirement, not a target.** Do **not** reintroduce
the copout that a cross-topology change "isn't a morph" or is a discrete
regen-event carved out of the morph system; it is a morph, and it must be
seamless like the rest.

The tiers, in escalating difficulty:

- **Within-form / same-base-mesh (blendshape-able)** — *high bar.*
  Deformations and body-part size transformations within one base mesh must
  be **excellent**. These are the topology-preserving morphs (blendshapes)
  the topology template (B) is required to keep pinch-free across the whole
  envelope.

- **Female ↔ male — *middle difficulty.*** Morphing between the female and
  male forms of a body plan.
  - **Bonus / aspiration: embryological homology.** Parts that are
    **embryologically homologous** — that develop from the same fetal
    structure (e.g. clitoris ↔ glans, labia ↔ scrotum) — should **morph
    into each other**, not crossfade. Anatomically faithful, continuous, and
    NSFW-first-relevant. This is an aspiration / bonus on top of the F↔M
    tier, not a required floor.

- **Across-form / topology change (limb count, finger counts, body plans —
  e.g. biped ↔ taur)** — *the hardest tier.* Because **each form is itself
  blendshape-able**, the across-form layer must be **"even more
  procedural"** — generative **topology-changing metamorphosis**
  (correspondence between the two topologies + compatible remeshing +
  pinch-free interpolation under the soft-body sim), **layered atop the
  per-form blendshapes**. It must still be **seamless** — no copout, **not**
  carved out as a discrete regen-event. This is the hard, literature-backed,
  **unsolved-at-realtime-quality** problem.
  - **Diegetic tie-in:** the shapeless / weaver / synthetic lineages in
    `transformation-lore.md` **are** topology change in the fiction
    (scavenger / synthetic = topology change in that doc's physics/capability
    mapping; shapeless = continuous reshape; weaver = grown rest-targets).
    The fiction and the hard technical tier coincide.

## D. Full procedural animation

**Procedural, environment-responsive animation — not canned clips.**
Potentially **neural walk cycles**: motion synthesized rather than played
back. Consistent with the determinism rule, any neural/learned component is
**build-time-trained → deterministic-eval at runtime** — a **peer to the
other surrogate bets**, with **no hot-loop / online inference** (CLAUDE.md;
DESIGN.md *aeriea is a research program*; cf. the primary-motion ML bet in
*the animation/fidelity bet*).

- **Usable-now tier:** a standard rig + blends + proven procedural animation
  (the conventional, shippable path — IK, footplant, sway, look-at,
  blendspaces).
- **Aspirational tier:** neural / environment-responsive synthesis (neural
  walk cycles, motion that reacts to terrain and context), trained offline,
  deterministic at runtime.

## E. Literature review needed (a concrete next action)

Genuinely flagged as a real next step: the team needs to **read the
literature** for the aspirational-SOTA tiers before committing methods. At
minimum:

- **Neural motion synthesis / environment-responsive & physics-based
  animation** (the D aspirational tier).
- **Topology-changing mesh metamorphosis** (the C across-form tier).
- **Deformation-aligned procgen body topology** (the B topology philosophy
  — where loops go and why, pinch-free morph envelopes).

This is a literature-review item, not a solved plan.

**Update (2026-06-03): the literature review landed** —
`../research/animation-morphing-procgen-bodies.md` (a dated snapshot
covering all three areas: procedural / learned / physics-based animation;
topology-changing mesh metamorphosis; parametric procgen bodies +
deformation topology). It carries per-method maturity / real-time /
determinism verdicts, a determinism scorecard, and two-tier recommendations
mapped onto this doc. Headline findings: animation usable-now = Motion
Matching + foot-IK (deterministic), neural-but-deterministic upgrade =
Learned Motion Matching, physics-RL aspirational (gated on a
bit-deterministic fixed-step solver); the across-form (C) topology-changing
morph tier is confirmed an **honest gap** — seamless real-time *skinned*
topology metamorphosis is genuinely unsolved (skinning discontinuity is the
blocker), so it sits correctly in the aspirational tier with a
baked-offline-deterministic + modular-swap usable-now floor; procgen bodies
usable-now = one canonical quad topology + morph stack + LBS (the SMPL-X =
Daz = MetaHuman pattern), with MakeHuman CC0 exports as the license-clean
Godot base. Citation/licence caveats are flagged in the doc.

## F. The interlock (one shared substrate)

Procgen-mesh generation, morph / transformation, the soft-body deformation
sim, and animation all share **one substrate: the mesh + its
deformation-aligned topology.** A **consistent topology** is the common
ground that lets them compose — the same topology that animation skins to,
that the soft-body sim deforms, and that morphs (within-form, F↔M, and
across-form) operate on. Get the topology right (B) and the four systems
have a shared surface to build on; get it wrong and they fight each other.

Cross-references:
- `transformation-lore.md` — morph as an *authored moving rest-state target*
  the soft-body surrogate tracks (the *Physics / capability mapping*
  section); morph/rest-target framing.
- DESIGN.md, *Secondary / soft-body physics* and the *physics-driven bodily
  transformation* R&D paragraph — the soft-body deformation sim this mesh /
  topology feeds, and the predict-then-project surrogate a transformation
  drives via the rest target.

## G. Prior art

`~/git/paragarden/existence` (~67k LOC working code) is the team's working
prior art for the **simulation-underneath-rendering** pattern. It is more
relevant to the semantic / sim side than to the mesh itself — note it with
a **lighter touch** here — but it is the standing prior art for the sim side
of this pillar, and worth consulting where the deformation/animation work
touches the underlying simulation.

---

## Two-tier + no-copouts (throughout)

Both postures apply across every part of this doc. **No-copouts:** quality
is the bar (A); morphs must be seamless (C); across-form is a real morph,
not a carved-out regen-event (C). **Two-tier:** each part has a usable-now
floor and an aspirational-SOTA frontier, degrading gracefully between them
(B's proven topology work and conventional rig/anim are usable-now; the
across-form metamorphosis and neural animation are aspirational).

## Open threads (explicitly unresolved)

- **The topology template specifics** — the actual loop layout per body-plan
  family; what the per-family templates are.
- **The cross-topology metamorphosis method** — the correspondence +
  remeshing + interpolation approach for the across-form tier (pending the
  literature review, E).
- **The neural-animation approach** — concrete method for environment-
  responsive / neural-walk-cycle synthesis (pending E).
- **The F↔M homology mapping detail** — the actual map of which structures
  morph into which (clitoris↔glans, labia↔scrotum named; the rest TBD).
- **What the usable-now tier concretely is for each part** — the proven,
  shippable floor for procgen bodies, topology, each morph tier, and
  animation, spelled out per part.
- **Names** are the lead's to set — this doc coins none.
