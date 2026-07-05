# Animation Approach

## Purpose & status

**Aspirational design record for CHARACTER ANIMATION — a vision + findings, NOT a
commitment and NOT implemented.** This is an experimental research/reasoning artifact.
**Status: EXPERIMENTAL — Not green — no code yet.** Nothing in this document is built,
none of it is user-certified, and none of it should be read as a decision. It records
where the state of the art sits, what aeriea would need, and — most importantly — an
honest line between what is buildable now and what is a frontier bet.

The requirement this record is written against has two halves, and both are held to the
same bar:

1. **Realistic-quality human motion** that avoids the uncanny valley.
2. **Realistic-quality motion on transformed / exotic / variable-topology bodies** —
   extra limbs, two torsos, non-human plans.

The tempting escape hatch — "exotic bodies are stylized by nature, so hold them to a
lower bar" — was considered and **rejected as a copout**. A transformed body still has
weight, flesh, momentum, and ground contact; it still has to move like a real physical
thing. What it lacks is a *known-face referent* for its style, not a licence to look
fake. The exotic case is harder, not lower.

Every element below is tagged:

- **[ACHIEVABLE]** — buildable now with existing tools (a fact, a shipped technique, an
  adoptable component). Where the achievable claim is a bare fact it is tagged
  **[ACHIEVABLE-fact]**.
- **[ASPIRATIONAL]** — a frontier / R&D bet: converging in research, unshipped in games,
  not committed as a milestone.

### Relationship to the body / transformation substrate

Animation is a **different system** from the body/transformation substrate. The
substrate (`scripts/sim/tf/`, designed in
`docs/decisions/body-transformation-substrate.md`) is the deterministic seeded truth of
*what the body is* — a plain-struct tree of parts, changed by authored marinada
transformations. Animation is the layer that **renders the body the substrate
simulates**: it takes the current body state and produces believable motion of it.

The two must stay cleanly separated, and the direction of dependence is one-way:
animation reads the substrate; **animation never writes back into the substrate.** The
substrate is authoritative sim state (seed + action log); animation is presentation.
This separation is what lets animation use non-deterministic physics without breaking
the seeded-simulation north star (see Findings — determinism-by-layering).

---

## How shipping life-sims do it (baseline / context)

The commercially shipped life-sims — **The Sims 4**, **inZOI**, **Paralives** — all
converge on the same recipe:

- one **fixed shared skeleton** (constant bone topology for every character),
- **hand-authored clips** (animated in Blender/Maya — not mostly mocap),
- **morph targets** for shape,
- **bone scaling** for size,
- **runtime IK** to re-seat hands and feet after shape/scale distortion.

Body variety is expressed as *shape and scale on a constant skeleton*, which is exactly
what lets a single authored clip play believably on every body. The revealing tells:

- **inZOI locks character height entirely** — variable height was cut because it "would
  break interaction animations such as hugging, handshakes." (Their two-actor animations
  assume both actors are the fixed reference height.)
  <https://thegameswiki.com/inzoi/wiki/body-type-customization>
- **The Sims** applies in-game IK to reseat hands and feet after morph/scale, and
  two-actor interactions are staged with "jigs" / anchor points that both actors snap to.
- **Paralives** is the best small-team template: roughly **two custom rigs**, size stored
  **as scale data** rather than as distinct rigs, and **runtime additive IK constraints
  with weighted curves** to bridge cross-body contact. Their own framing: "variations
  help, but constraints bridge the gap."
  <https://paralives.wiki.gg/wiki/Procedural_Animation_Adaptations_Using_Rigging_Constraints>

**The load-bearing observation: all three assume fixed skeleton topology. None of them
animate variable topology.** Body variety is shape/scale, never a change in the number or
arrangement of bones. This is precisely the assumption aeriea's transforming bodies
break — which is why the shipped recipe is a *baseline*, not a template we can copy whole.

Additional context sources on the craft of believable motion in small teams / procedural
settings: Chris Hecker's Spore work (arbitrary-topology procedural animation)
<https://chrishecker.com>; and Overgrowth's indie animation approach (few hand-authored
poses + powered ragdoll)
<https://www.gdcvault.com/play/1020583/Animation-Bootcamp-An-Indie-Approach>.

---

## The uncanny valley in motion (the quality bar, decomposed)

What makes motion read as "fake" decomposes into four tells:

1. **Weight / balance** — the center of gravity stays over the base of support; the body
   looks like it has mass and is holding itself up against gravity.
2. **Ground contact** — feet plant and stay planted; no foot-skating, no floor
   penetration.
3. **Momentum / follow-through** — motion carries through and settles; nothing snaps or
   teleports between poses.
4. **Human style + micro-timing + secondary motion** — the *human-specific* way a person
   distributes a movement in time, plus secondary motion of flesh, hair, and cloth.

**KEY INSIGHT:** a physics simulation delivers **tells 1–3 for free on any body**,
because it solves Newtonian dynamics rather than replaying clips — balance, contact, and
momentum fall out of the simulation regardless of morphology. Only **tell 4 (human
*style*)** requires reference motion data. This is the crux that organizes every finding
below: the dynamics generalize across bodies; the *style* is the part that is tied to
having a human referent.

---

## Findings & decisions

- **[ACHIEVABLE-fact] Realistic human motion is data-driven at root.** As of 2024–2026
  there is **no zero-mocap path to non-uncanny human motion.** Even physics-RL
  controllers (AMP / ASE / PHC and kin) get their *naturalness* from a discriminator
  trained on mocap — the physics gives dynamics, the mocap gives style. Realistic human
  motion = physics (dynamics) + mocap (style). Any plan that hopes to hand-tune its way
  to human-quality style without reference data is betting against the entire field.

- **[ASPIRATIONAL] Do not split the system by body type; aim for ONE substrate: physics
  simulation + a learned/procedural control layer.** The important axis is *data vs
  physics*, and it is **orthogonal** to *human vs exotic*. A naive design would build a
  "human animation system" and an "exotic animation system" — but because aeriea's bodies
  *transform*, that seam would fall exactly on the transformation itself, i.e. exactly
  where it must not break. A single physics-based substrate instead gives real weight on
  any morphology (tells 1–3); a learned style layer supplies human style where the
  morphology overlaps a human body; and morphology-conditioned control extends toward
  genuinely novel body plans. One substrate, graded coverage — not two systems with a
  fault line at the transformation.

- **[ASPIRATIONAL / open frontier] Realistic-quality motion on arbitrary topology is
  UNSHIPPED.** No game currently does it. The research is converging (2024–2026):
  **X-Morph (2026)** retargets human mocap onto non-humanoid bodies via physics + RL at
  roughly 25 Hz; **morphology-conditioned policies** (MetaMorph and kin) show some
  zero-shot generalization across body plans. But this work lands at
  *robotics-locomotion* fidelity, **not character-animation quality.** The genuinely hard
  part is **style on an unreferenced body** — the dynamics on a novel morphology are
  tractable; making a two-torso, four-armed body move with the *intentional style* of a
  living creature, without any reference recording of such a creature, is the open
  problem. This is a serious **staged R&D bet, not something to buy off a shelf.**

- **[ACHIEVABLE] Determinism resolves by layering, not by constraining the animator.**
  Animation is **presentation, not authoritative sim state.** The substrate remains the
  deterministic seeded truth; physics-based animation **renders** that truth and stays
  cosmetic and fenced-out — it never feeds back into the sim — so replay from seed +
  action log still reproduces identical sim state. Within the animation layer:
  motion-matching's nearest-neighbor search is itself deterministic; neural inference
  would additionally need pinned fixed-order / fixed-precision execution to stay
  seed-reproducible, but since animation is cosmetic, exact frame-for-frame animation
  reproducibility is not a north-star requirement the way sim-state reproducibility is.

Sources for this section: X-Morph (2026, cross-morphology retargeting via physics+RL);
DReCon (Ubisoft — physics + motion-matching, notably low runtime cost); PHC / PULSE
(ZhengyiLuo/PHC — physics-based humanoid control); AMP / ASE (nv-tlabs/ASE — adversarial
motion priors); motion matching (Clavet / Ubisoft).

---

## Rights-clean mocap (NSFW-commercial constraint)

aeriea is NSFW-first and commercial, which sharply constrains which motion datasets can
be used. The constraint is not just "is it free" — it is "may its outputs ship in a
commercial, adult product, and may derived weights be distributed."

**Usable:**

- **CMU MoCap** — free; may ship in commercial products; may **not** resell the data
  itself.
- **100STYLE** — CC BY 4.0 (attribution; commercial OK).
- **Own capture** — a **Rokoko** suit (you own your captured data outright); or
  **DeepMotion** video→mocap on its paid tier, which grants a commercial license to the
  outputs.

**AVOID (non-commercial licences):**

- **AMASS** — non-commercial research only.
- **LAFAN1** — CC BY-NC-ND (non-commercial, no derivatives).
- Do **not** attempt to launder non-commercial data through trained weights — a model
  trained on non-commercial data does not become commercial-clean.

**Contractually blocked / unverified:**

- **Reallusion / ActorCore** content is contractually banned for NSFW use.
- **Mixamo** is unverified for NSFW — treat as **SFW-only** until confirmed otherwise.

Practical read: the clean core is **own capture + CMU + 100STYLE**, which is enough to
feed a human motion-matching core.

---

## Godot facts (verified this session)

- **Installed engine: Godot 4.6.2.stable** (`godot4` binary, per the flake and
  `tests/run.sh`).
- **[ACHIEVABLE] Godot 4.6 ships the full IK suite:** `TwoBoneIK3D`, `SplineIK3D` (good
  for tails), and `FABRIK3D` / `CCDIK3D` / `JacobianIK3D`, all built on
  `SkeletonModifier3D`. Two-bone and spline solvers are **deterministic** (fits the
  seeded-sim north star; pin iteration counts on the iterative solvers to keep them so).
  **`SkeletonIK3D` is deprecated — do not use it.**
  <https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/>
- **[ACHIEVABLE] `SpringBoneSimulator3D`** (Godot 4.5+) covers tails / soft-tissue /
  jiggle secondary motion — it is **one-way** and must never feed back into keyed bones.
- **[ACHIEVABLE] `SkeletonModifier3D`** is the clean hook for layering procedural / IK
  behavior on top of `AnimationMixer` output.
  <https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html>
- **[ASPIRATIONAL — cosmetic, fenced] Active ragdoll** via `RigidBody3D` +
  `Generic6DOFJoint3D` motors driving toward the animated pose is available, **but
  physics in Godot is generally NOT bit-deterministic** — keep any such motion strictly
  cosmetic and fenced out of sim state.
- **[ACHIEVABLE] `GuilhermeGSousa/godot-motion-matching`** — MIT-licensed,
  C++/GDExtension, Godot 4.4+, integrated with `AnimationTree`, in the Asset Library
  (#3822), and actively maintained. This is a **real adopt option for the human core**
  (requires clips with root motion and a root bone placed at foot level).
- **[ACHIEVABLE, with caveat] Rust / gdext for hot paths** (nearest-neighbor search,
  policy inference). Caveat: GDExtension can be *slower* if the workload is dominated by
  per-bone FFI calls — the win only materializes if a whole character's solve stays inside
  Rust behind **one** boundary crossing. **Measure before rewriting.**

Sources: <https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/>;
<https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html>;
godot-motion-matching (Asset Library #3822 / GitHub GuilhermeGSousa).

---

## The achievable vs aspirational split (the load-bearing section)

This is the section that matters most: it draws the line between what aeriea could build
now and what is a bet on the frontier. Both are recorded; only the first is a candidate
for near-term work, and even that is Not green until the user says so.

### [ACHIEVABLE — near-term, buildable]

A **human / near-human core built on motion matching**: adopt the MIT
`godot-motion-matching` plugin and feed it own capture + CMU / 100STYLE mocap. Motion
matching is a proven, small-team-scale technique that clears the uncanny valley for human
bodies. Layered on top:

- **Godot 4.6 built-in IK** (`TwoBoneIK3D` / `SplineIK3D` / FABRIK / CCDIK) for
  foot-planting and hand-reach re-seating.
- **`SpringBoneSimulator3D`** for secondary / jiggle motion (flesh, hair, tails).
- **Procedural IK / gait** for the cases where a stylized result is acceptable.

This combination is buildable now, is what shipping life-sims prove out, and is the
sensible first target *if* animation work is ever greenlit.

### [ASPIRATIONAL — R&D bet, explicitly NOT a near-term milestone]

**Physics simulation + learned control as the unifier** — the single substrate that
delivers realistic weight/contact/momentum on *arbitrary and transforming* topology, with
**morphology-conditioned policies** carrying style toward novel body plans. This is the
north star to grow *toward*, recorded here so the near-term achievable work can be shaped
to not foreclose it. It is **not** a milestone, not committed, and not to be scoped as
near-term. It is where the field is heading and where aeriea's transforming-body
requirement ultimately points.

---

## Reference targets (for later study)

Games / techniques:

- **Spore** — Chris Hecker, SIGGRAPH 2008; arbitrary-topology procedural animation
  (stylized quality). <https://chrishecker.com>
- **Overgrowth** — GDC 2014; few hand-authored poses + powered ragdoll.
  <https://www.gdcvault.com/play/1020583/Animation-Bootcamp-An-Indie-Approach>
- **Rain World** — GDC 2016; verlet / distance-constraint creature bodies.
- **IK Rig** — Bereznyak, GDC 2016; retargeting motion across differing rigs.
- **X-Morph** — 2026; cross-morphology human→non-humanoid retargeting (physics + RL).
- **DReCon / PHC / AMP / ASE** — physics-RL character control.

Open-source components (with licences):

- **Sopiro/Unity-Procedural-Animation** — MIT.
- **GuilhermeGSousa/godot-motion-matching** — MIT.
- **EA character-motion-vaes** — BSD-3.
- **orangeduck/Motion-Matching** — MIT code, but **bundled data is non-commercial**
  (retrain on clean data before commercial use).
- **active-ragdoll** — MIT / Apache.
- **monxa/GodotIK** — MIT.

Foundational primitive under most of the above: **Jakobsen 2001** — verlet particles +
distance constraints (the basis of Rain World-style bodies, cloth, and much procedural
soft-body motion).

---

*This record is aspirational. It commits nothing, builds nothing, and promotes nothing to
green. It exists so that if character animation is ever taken up, the ground it starts
from is already surveyed — with the achievable and the frontier honestly separated.*
