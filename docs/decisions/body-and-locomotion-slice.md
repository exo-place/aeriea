# Decision: Body + locomotion — usable-now slice (nix-reproducible asset pipeline)

Status: **DESIGN + SLICE PLAN — usable-now tier** (2026-06-03)

Scope: the *usable-now* slice that puts a **visible, animated, morphable human
body** on the existing movement sim, plus the **nix-reproducible asset pipeline**
that produces that body from pinned inputs with no manual download/processing
step. This doc is the spec; it contains **no implementation code**. The build is
staged in "Incremental slice plan" below, mirroring how the movement and
affordance substrates began (`movement-substrate.md`, `affordance-substrate.md`):
a design doc → a reviewable, independently-xvfb-verifiable slice plan.

This is the **procgen-body + animation pillar's usable-now floor** made concrete.
It commits **nothing aspirational** (generative bodies, neural animation,
topology-changing metamorphosis, soft-body) — those stay where
`procedural-body-and-animation.md`, `future-directions.md`, and
`research/animation-morphing-procgen-bodies.md` already place them, in the
aspirational tier. What this doc decides is the proven ground the body ships on.

Cross-links:
- `../research/animation-morphing-procgen-bodies.md` — the lit review. §C
  (procgen bodies: MakeHuman CC0, the SMPL-X = Daz = MetaHuman "one topology +
  morph stack + LBS" pattern), §A (animation: Motion Matching + foot-IK as the
  deterministic usable-now floor, Learned MM as the neural-deterministic
  upgrade), and the determinism scorecards.
- `procedural-body-and-animation.md` — the pillar (§A quality-first procgen, §B
  topology philosophy, §C morph tiering, §D animation, §F the one-substrate
  interlock).
- `movement-substrate.md` — the movement SIM (data-driven, deterministic,
  implemented through Slice 4). Locomotion **animation renders on top of it**;
  this doc designs that seam.
- `affordance-substrate.md` — the guard layer where the NSFW gate lives
  (§ guards). The age morph axis feeds that gate.
- `units-and-scale.md` — 1u = 1m; canonical body dims (1.8 m standing, eye
  1.75 m, capsule radius 0.35 m); the body-origin-at-feet VR open seam.
- `../../DESIGN.md`, *Age × NSFW: gate the configuration, not the primitives*
  (Layer 1, the hard structural gate) and *NSFW-first with SFW toggle*.

---

## Why this exists

The movement sim is built and deterministic (`movement-substrate.md`, Slice 4
done), but it drives an invisible capsule: `interpreted_player.gd` is a
`CharacterBody3D` + `CapsuleShape3D`, no mesh. The single non-negotiable goal is
100% immersion (DESIGN.md), VR is first-class (`units-and-scale.md`), and *"the
body has to read as real"* (DESIGN.md) — so the body is not optional polish, it
is load-bearing. This slice gives the player **a real-scale, morphable, animated
body** standing on the proven movement and affordance substrates.

Two constraints shape every decision here, both first-class:

1. **The asset pipeline must be fully nix-reproducible.** From **pinned inputs**,
   a derivation deterministically produces the Godot-ready body — base mesh +
   morph/blendshape stack + LBS rig — with **no manual download, no manual
   processing, no out-of-band tool run**. This is the same posture as the rest
   of the ecosystem (CLAUDE.md: *prefer data over code at every seam*;
   *validate against reality*; deterministic build artifacts). An asset you
   cannot rebuild from a pinned input by `nix build` is an asset you do not
   control.

2. **Determinism end to end.** The body's pose is a deterministic function of
   the movement sim's state (seed + action-log; `movement-substrate.md` §3). No
   per-query inference in the hot loop. The usable-now animation path is chosen
   precisely because it is deterministic by construction.

---

## 1. Body asset pipeline (nix-reproducible — first-class)

### 1.1 The chosen route — direct `.target`-ASCII parsing (not headless Blender)

**Decision: parse the MakeHuman CC0 base mesh (`base.obj`) and `.target` files
directly into a Godot `ArrayMesh` with morph blendshapes + an `.mhskel`-derived
`Skeleton3D`, in a Nix derivation. Do NOT route through headless Blender + MPFB.**

The lit review (research §C2, §Synthesis) names MakeHuman CC0 as the
license-clean Godot base and offers two conversion routes: (a) headless
Blender + MPFB → glTF/shapekeys, or (b) direct `.target`-ASCII parsing. Probing
the **pinned nixpkgs source** settled it decisively in favour of (b):

**What the pinned MakeHuman source actually contains** (verified 2026-06-03
against `nixpkgs#makehuman` v1.3.0's `fetchFromGitHub` source archive — see
§1.3 for the pin):

- `data/3dobjs/base.obj` — the CC0 base mesh: **19158 vertices, quad faces**
  (`f a b c d`), already the quad-dominant topology the topology philosophy
  wants (procedural-body-and-animation.md §B).
- `data/targets/**.target` — **1280** morph targets, each a **plain-ASCII
  sparse vertex-delta file**: lines of `<vertex_index> <dx> <dy> <dz>` (only the
  moved verts; a macro target moves ~19150 of the 19158). Verified header:
  *"This asset was explicitly released as CC0 in september 2020."*
- The **macro axes are present as targets** under
  `data/targets/macrodetails/`: **gender** (female/male), **age**
  (`baby`/`child`/`young`/`old`), **muscle** (min/avg/max), **weight**
  (min/avg/max), **height** (min/max), and **proportions**. Plus detail
  categories (`breast`, `buttocks`, `genitals`, `torso`, `hip`, `stomach`,
  `head`, `expression`, …) — the within-form morph envelope and the
  NSFW-relevant morphs.
- `data/rigs/default.mhskel` — the LBS rig, a **JSON** bone tree (head/tail/
  parent/rotation_plane per bone; includes e.g. `breast.L/R` parented to
  `spine02`). Trivially parseable; no binary format.

So the entire input is **plain text** (OBJ + ASCII deltas + JSON skeleton). The
conversion is a pure text→`ArrayMesh` transform:

1. Parse `base.obj` → vertices + quad faces. Triangulate quads
   deterministically (fixed diagonal, stable order) for the Godot render mesh;
   **retain the quad topology as the authoring/morph source of truth** (the
   topology philosophy's linchpin — every morph target shares this one vertex
   set; procedural-body-and-animation.md §B, §F; research §C4).
2. For each selected `.target`: read `(index, dx, dy, dz)` deltas → a Godot
   **blendshape** (`ARRAY_FORMAT` morph array = base positions + the sparse
   deltas scattered in). A blendshape is a same-topology displacement, which is
   exactly what a `.target` is — a 1:1 mapping, no remeshing, no correspondence
   problem (research §B1: same-topology blend is trivially deterministic).
3. Parse `default.mhskel` → a `Skeleton3D` bone hierarchy; bind skin weights.
   *(MakeHuman ships vertex→bone weighting alongside the rig; the slice plan
   gates rigged skinning to Slice 3, see §1.5.)*
4. Emit a committed/buildable Godot resource: a `.res`/`.tres` `ArrayMesh` (or a
   `.glb` if a glTF emitter is cleaner downstream) with the blendshapes and
   skeleton, plus a small generated **manifest** mapping axis name → blendshape
   index → source `.target` path. Deterministic byte-for-byte given the pinned
   input + a pinned converter.

**Why not headless Blender + MPFB.** Blender is in nixpkgs (5.1.1, verified) and
MPFB is the canonical MakeHuman→Blender route, so it is *feasible*. But it is the
**heavier and less reproducible** option for this slice, for concrete reasons:

- **Determinism risk.** Blender's glTF/shapekey export and its Python-driven mesh
  ops are a large surface with float-formatting, addon-version, and export-order
  variability. The direct parser's output is a pure function of two text files
  and a small converter we own — far easier to make byte-deterministic and to
  pin.
- **Cost / closure.** Adding Blender pulls a very large build closure and a
  GUI-grade dependency into the dev shell for what is, in the end, a text→mesh
  transform. The direct route adds **only** a small parser script (and its
  interpreter) to the build.
- **The format is documented and trivial** (research §C2 already flags this):
  `.target` is `index dx dy dz`. We do not need Blender to read four floats per
  line.

**Honest cost of the chosen route:** we hand-write the OBJ/`.target`/`.mhskel`
parser and the Godot-mesh emitter. That is bounded, testable code over a stable,
documented, CC0 format — and it is *ours*, pinned, with no GUI tool in the build
graph. The skinning-weight import (step 3) is the only fiddly part and is
deliberately deferred to a later slice (§1.5). **Blender/MPFB stays a documented
fallback** if the direct parser hits an asset it cannot read; it is not in the
critical path.

> **Note — the nixpkgs `makehuman` *app* is broken on current unstable** (numpy
> 2.x removed `np.fromstring`, which its `compile_targets.py` calls; the derivation
> fails at build). This does **not** affect us: we do not build or run the
> MakeHuman application. We fetch its **pinned source archive** (which is what
> carries the CC0 `base.obj` + `.target` + `.mhskel`) and parse it ourselves.
> The broken app is in fact a second reason to prefer the direct route over
> anything that drives the MakeHuman/MPFB toolchain.

### 1.2 The derivation shape

A new derivation (e.g. `nix/body-mesh.nix`, exposed as a flake `packages` output
and wired into the dev shell / an import step):

```
fetchFromGitHub (pinned MakeHuman source, §1.3)   ──┐
                                                    ├─► converter (our parser,
a pinned converter script + its interpreter        ─┘   pure text→ArrayMesh)
                                                         │
                                                         ▼
                              committed-or-buildable Godot body asset
                              (ArrayMesh + blendshapes + Skeleton3D + axis manifest)
```

- **Inputs are pinned**: the MakeHuman source rev+hash (§1.3) and the converter
  (in-repo, versioned). No network access at build beyond the pinned fetch
  (Nix fixed-output for the fetch; the convert step is pure).
- **Output is deterministic**: same pinned input + same converter → identical
  bytes. The output is treated like any other generated artifact (cf. the
  movement compiler's committed-and-regenerated codegen): **either committed and
  regenerated by `nix build`, or built on demand** — never hand-edited,
  header/manifest-stamped with the source rev so drift is detectable.
- **No manual step**: `nix build .#body-mesh` (or the import wiring) produces the
  asset from scratch. This is the whole point of the constraint.

### 1.3 The pin (verified)

The MakeHuman CC0 assets are fetched by a `fetchFromGitHub` identical in shape to
the one nixpkgs already uses (so the hashes are known-good and the pin is real,
not aspirational):

```
owner = "makehumancommunity";
repo  = "makehuman";
rev   = "v1.3.0";
hash  = "sha256-x0v/SkwtOl1lkVi2TRuIgx2Xgz4JcWD3He7NhU44Js4=";
# CC0 base.obj + .target + default.mhskel live under makehuman/data/ in this tree.
```

(The separate `makehuman-assets` repo, same owner, `v1.3.0`,
`sha256-Jd2A0PAHVdFMnDLq4Mu5wsK/E6A4QpKjUyv66ix1Gbo=`, carries the optional
clothes/hair/eyebrow proxies — **not** needed for the core body; left out of the
core pin, available later for cosmetic content.)

### 1.4 Flake additions implied

Minimal, by design (the direct route's payoff):

- **The pinned fetch** — added as a flake input *or* an in-derivation
  `fetchFromGitHub` (the latter keeps `flake.lock` unchanged for this task; a
  flake input is the cleaner long-term form and a follow-up can promote it).
- **An interpreter for the converter** — the converter is a small parser. If
  written in **GDScript**, no new dependency at all: run it headless under the
  existing `godot_4` + `xvfb-run` already in `flake.nix` (Godot can parse OBJ/
  text and emit an `ArrayMesh` resource), keeping the build inside tools the
  shell already has. If written in **Python/Rust**, add `python3` (stdlib only —
  no numpy needed; we are reading four floats per line) or use the existing Rust
  toolchain. **Preference: GDScript converter run under the existing Godot+xvfb**,
  so the flake gains *nothing* and the output is produced by the same engine that
  consumes it. (Decision recorded; the converter language is a Slice-1
  implementation choice, but the no-new-dependency GDScript path is the default.)
- **NOT added: Blender, MPFB, numpy.** Explicitly avoided per §1.1.

So the headline: **the nix-reproducible pipeline can be built with the dev shell
as it stands today** (Godot + xvfb), fetching one pinned CC0 source. That is the
cheapest possible form of the constraint, and it is the chosen one.

### 1.5 License honesty (load-bearing)

- **MakeHuman base mesh + `.target` deltas + skeleton are CC0** — verified: the
  target headers state explicit CC0 (September 2020), and `LICENSE.ASSETS.md` is
  CC0 1.0 Universal. Safe to bundle, ship, modify, and redistribute in the core
  product. **This is the cleanest license in the procgen-body survey**
  (research §C2).
- **Scope caveat (carried verbatim from the survey):** *core bundled* MakeHuman
  assets are CC0; **community-database** assets (the user-contributed clothes/
  hair/morphs hosted in the MakeHuman community DB) are **not uniformly CC0** —
  each carries its own license. The pipeline pins **only the CC0 core**; any
  community-DB asset is a separate, per-asset license decision and is **out of
  scope** for the core body.
- **SMPL family stays a design reference only, never a shipped asset.** SMPL/-X
  is MPI research / non-commercial; commercial use needs a separate Meshcapade
  license (research §C1, §Open questions). We use **SMPL-X's parameter structure
  as a reference** for how to organize the morph/shape space (research §C,
  §Synthesis) and **ship none of its meshes or weights**. MetaHuman is OUT
  (UE-only EULA). This avoids the licensing landmine entirely by construction.

---

## 2. Morph stack ↔ body-state ↔ NSFW gate

### 2.1 The body-state parameter (what the sim/affordance layer reads)

The morph axes are not just art knobs — they project to a small, serializable
**body-state** record that the simulation and the affordance layer read, exactly
in the spirit of *simulation underneath, rendering on top* (DESIGN.md;
existence-pattern). The body-state is **data** (like `MovementState` and the
interactable state maps), part of the seeded sim, and carries at least the macro
axes:

```
BodyState = {
  gender:      number,   # 0..1 (female↔male macro blend)
  age:         number,   # continuous age axis, see 2.2
  muscle:      number,   # 0..1
  weight:      number,   # 0..1
  height:      number,   # 0..1 (maps to real metres per units-and-scale.md)
  proportions: number,   # 0..1
  # ...detail axes (breast/buttocks/etc.) as the within-form envelope grows
}
```

The renderer turns `BodyState` into **blendshape weights** on the §1 mesh:
each macro axis drives the corresponding `.target`-derived blendshape(s). The
mapping `BodyState → blendshape weights` is a **pure deterministic projection**
— the same shape as the movement/affordance interpreter→render seam. The morph
space stays **continuous and orthogonal** (DESIGN.md, *Age × NSFW*: the morph
space must stay smooth; primitives are not crippled).

This is the §C "everything is a morph on one shared topology" pattern made
literal: one 19158-vertex quad mesh, every axis a blendshape on it, one rig
(research §C, §C4; procedural-body-and-animation.md §F — the one-substrate
interlock).

### 2.2 The age axis → the Layer-1 NSFW gate

The MakeHuman age axis is shipped as discrete anchors — `baby`, `child`,
`young`, `old` — which the system reads as a **continuous `age` parameter**
interpolating between the anchored age morphs (the axis *must* stay continuous,
because ordinary NPCs of every age legitimately exist; DESIGN.md, *Age × NSFW*).
The anchors are the source data; `age` is the smooth knob over them.

**Wire the age axis to the gate from the start.** DESIGN.md's Layer 1 is a
**hard structural gate** on the **intersection**: *child-range body-state × any
NSFW / intimate verb or system*, enforced at the **affordance substrate's guard
layer** (`affordance-substrate.md`), **non-optional, non-toggle**. The body-state
`age` parameter is precisely the *checkable body-state* that gate reads:

- The renderer/sim exposes a derived predicate from `BodyState.age` — e.g. an
  **`adult_body_state`** boolean (true iff `age` is at/above the adult
  threshold over the continuous axis). This is a pure function of body-state,
  deterministic, part of the sim.
- Every NSFW / intimate **verb in the affordance kit guards on `adult_body_state`**
  — as the affordance substrate's closed Guard vocabulary already supports
  (a guard reading a body-state field is the same shape as
  `state_cmp(scope, field, cmp, value)` in `affordance-substrate.md` §1). The
  guard's primitive is **general** — "gate the intersection" — not a special-case
  age check carved into the engine.

**Keep primitives general (per the committed rule).** The gate is **layered
policy over a general engine, not an amputation** (DESIGN.md, *Age × NSFW*):

- The **age morph axis stays complete and continuous** — baby/child/young/old all
  representable, because NPCs of every age legitimately exist and the morph space
  must stay smooth (crippling it would bleed discontinuities into every adjacent
  legitimate config; DESIGN.md).
- The **NSFW systems stay complete** — aeriea is NSFW-first.
- What is forbidden is the **combination**, enforced as a guard on the
  intersection. The guard is the *intersection* predicate, not a hole in either
  primitive (DESIGN.md, *Age × NSFW* — "gate the configuration, not the
  primitives"; "the engine is general; this is a robust enforced layer").
- The gate is **non-toggle** in the shipped/official artifact (DESIGN.md). The
  honest caveat from DESIGN.md is carried as-is: because the engine is general and
  the software is self-hostable, this rests on the gate's robustness and on the
  official artifact never producing the intersection — not on amputating
  primitives.

This is the **earliest possible wiring**: the moment the age morph exists
(Slice 1), the `age` parameter exists; the moment body-state drives morphs
(Slice 2), the `adult_body_state` predicate exists and the gate hook is in place,
*before* any NSFW verb is authored. The gate is not bolted on later — it is a
property of the body-state from the first slice that has body-state.

> Layer 2 (the mind/values curation line) is **not** a body-state gate and is
> out of scope here — it is content-judgment policy, not code (DESIGN.md,
> *Layer 2*). This doc wires only Layer 1, the hard, exact, body-state backstop.

---

## 3. Locomotion / animation layer

### 3.1 The seam: movement SIM drives body POSE

The movement substrate is the **simulation**; the animation layer is **rendering
on top of it**. The seam, stated minimally:

- The movement interpreter owns `MovementState` (velocity, position, active
  state, timers; `movement-substrate.md` §3). It is the source of truth for
  *where the body is and what it is doing*.
- The animation layer is a **pure read of `MovementState` → a body pose**
  (skeleton bone transforms). It is **render-side** — like the camera
  height/FOV/roll effects, it is **excluded from the sim hash**
  (`movement-substrate.md` §3 step 5, §6): animation never feeds back into the
  trajectory. The capsule physics stays the sim; the skinned mesh is a
  presentation of it.
- Inputs to the pose each frame: planar velocity + speed, grounded/airborne,
  active movement state (GROUND/AIR/SLIDE/WALL_RUN/…), slope normal, wish-dir.
  All already in `MovementState`. The pose is a deterministic function of these
  → it inherits the sim's determinism for free.

### 3.2 Tiering — foot-IK + procedural locomotion FIRST; Motion Matching LATER

**Decision: the usable-now slice ships analytic foot-IK + simple
procedural/curve locomotion that needs NO licensed motion database. Motion
Matching (and Learned MM) is a LATER, deferred sub-slice gated on sourcing a
license-clean, nix-reproducible motion dataset.**

This is the **fully-self-contained, deterministic, no-external-data path first**,
which the constraint demands and the lit review supports:

- **Analytic two-bone foot-IK** (research §A5) — standard, trivial,
  **analytic and deterministic**, free, no data dependency. Plants feet on the
  ground/slope, adapts to terrain, kills foot-skate. This is the single highest
  immersion-per-effort animation primitive and it needs **nothing external**.
- **Simple procedural / curve locomotion** — a small set of authored pose
  curves (idle, walk, run, crouch, air) blended by planar speed and movement
  state, with procedural lean/sway driven by acceleration and slope. This is the
  conventional, shippable floor named in procedural-body-and-animation.md §D
  ("standard rig + blends + proven procedural animation — IK, footplant, sway,
  look-at, blendspaces") and future-directions.md (Animation, usable-now). It is
  **authored data, not a mocap database** — no licensing, no external corpus, and
  it fits the seed+action-log because it is a deterministic function of
  `MovementState`.

**Motion Matching is deliberately NOT in the usable-now slice**, despite being
the lit review's "usable-now floor" for animation (research §A1). The honest
reason: **Motion Matching is only "usable-now" if you have a motion database**,
and a license-clean, nix-reproducible motion-capture dataset is **not free and
not yet sourced**. Pretending otherwise would violate "validate against reality."
So:

- **Slice 4 (deferred): Motion Matching**, once a license-clean,
  nix-reproducible motion set is sourced (see §3.4 open dependency). It is a
  drop-in *upgrade* of the pose layer — same seam (reads `MovementState`, writes
  pose), better fidelity. Environment-aware MM (research §A8) and Learned MM
  (research §A2, the neural-but-deterministic upgrade — build-time-trained →
  deterministic eval) are further in-tier upgrades, all still deterministic, all
  behind the same data dependency.
- The procedural-foot-IK floor **degrades gracefully**: if MM is unavailable
  (no licensed data, or a platform where the database is too heavy), the
  procedural path still produces a fully animated body. The floor is never a
  copout (DESIGN.md, *no copouts*) — it is the proven ground that ships.

### 3.3 GDScript vs gdext

**Decision: the usable-now animation/IK layer is GDScript.** Analytic two-bone
foot-IK is cheap (a handful of trig ops per leg per frame) and pose-curve
blending is a few lerps — GDScript is fine, and it keeps the slice inside the
existing toolchain with no gdext build step (the movement substrate made the same
GDScript-first call; `movement-substrate.md` §4). It also keeps hot-reload and
the xvfb test loop fast.

**Where gdext might matter later** (noted, not built): Motion Matching's
per-frame **database search** over a large motion set, and especially **Learned
MM's neural eval**, are the perf-sensitive paths — that is the natural gdext/Rust
target if and when Slice 4 lands and profiling shows GDScript search is the
bottleneck (DESIGN.md: "drop to Rust via gdext for hot paths"; same posture as
the movement compiler's deferred Rust backend). The asset *conversion* (§1)
could also move to Rust if the GDScript converter proves slow, but for a
one-time build step it almost certainly will not matter.

### 3.4 Determinism + the open dependency

- The procedural/foot-IK path is **deterministic by construction**: analytic IK +
  pose-curve blends are pure functions of `MovementState`. It fits seed +
  action-log with no extra work, and contributes nothing to the sim hash
  (render-side).
- **Open dependency — RESOLVED (2026-06-04).** The **mocap-data sourcing +
  licensing + nix-reproducibility** for Slice 4's Motion Matching is closed. A
  motion database must be (a) license-clean for commercial shipping, (b)
  **nix-reproducible** (pinned fetch + deterministic preprocessing into the MM
  feature database, same posture as §1), and (c) cross-platform bit-deterministic
  in its search. The chosen datasets:

  - **100STYLE** — Ian Mason, Sebastian Starke, Taku Komura; **Zenodo record
    8127870**, DOI `10.1145/3522618`, **CC BY 4.0**. `100STYLE.zip` is the raw
    60 fps BVH (1.47 GB; md5 `3cf627852fd8192024c04a8d0ef49583`; nix SRI
    `sha256-LDtAF/jiOX7mkEybn0NVHYtCbTndw1WNEh/unlXLLVg=`). Purpose-built stylized
    locomotion; the locomotion subset (`Neutral`/`StartStop`/`March` styles ×
    idle/walk/run/back/strafe/turn) is curated at build time. **Required
    attribution:** *"The 100STYLE Dataset - Ian Mason"*. This is the **shipping
    MM source** — ingested fully (BVH is ASCII).
  - **CMU Motion Capture Library** — liberal CMU license (copy / modify /
    redistribute / commercial OK; must NOT resell the raw data directly).
    **Pinned mirror:** HuggingFace `gbionics/cmu-fbx` @ commit
    `d18e9d3d14c08318eaa6c0602a6ead7fac40e58c` (2 548 FBX, `animations/<subj>_<mot>.fbx`).
    **Required attribution:** *"data from mocap.cs.cmu.edu, NSF EIA-0196217"*.
    **SOURCING + PINNING RESOLVED, but ingest DEFERRED-WITH-REASON:** the mirror
    ships Kaydara **binary** FBX, and Godot has **no runtime FBX parser** (FBX is
    imported via fbx2gltf at *editor* time only); a pure-GDScript binary-FBX
    parser for retargeting is disproportionate. CMU drops in at the *same BVH
    ingest seam* once a CMU **BVH** mirror or an editor-side FBX→BVH conversion
    lands (`tools/motion_ingest.gd` is dataset-agnostic at the BVH boundary).
    Walk/run/turn subjects to curate when it lands: 02, 07, 08, 09, 16, 35, 38, 69.

  - **DISQUALIFIED** (verified, do not use): **LAFAN1** (Ubisoft, CC-BY-**NC**-ND —
    NonCommercial + NoDerivatives), **Bandai-Namco** (CC-BY-**NC** — NonCommercial),
    **AMASS / ACCAD / SFU** and the SMPL/AMASS family (academic / research-only
    terms; commercial use needs separate licensing). NonCommercial / academic
    terms are incompatible with shipping aeriea.

  **Verification gaps (carry as open):** confirm the CMU live-FAQ wording (the
  "no reselling raw data" clause) at ship time; the CMU HF commit is pinned but
  its precise license text should be re-read when CMU ingest is implemented. The
  100STYLE pin (DOI + md5 + SRI) is fully verified against a live fetch
  (md5 matches Zenodo's published checksum).

  The pipeline is **nix-reproducible** (`nix/motion-assets.nix` → `nix build
  .#motion-assets`, pinned `fetchurl` → unzip → ingest → committed feature DB,
  byte-deterministic — fresh rebuilds are byte-identical to the committed
  `assets/body/locomotion_mm.res`) and the search is **deterministic by
  construction** (weighted-squared-distance argmin, lowest-index tie-break,
  fixed float path; `scripts/body/motion_matcher.gd`). Cross-link:
  `../research/animation-morphing-procgen-bodies.md` §A1 (MM), §A2 (Learned MM
  upgrade), §A8 (environment-aware), and the determinism scorecard.

### 3.5 The aspirational ceiling (deferred, R&D) — full-body physics-SIMULATED control

The rungs above are all **kinematic**: foot-IK and Motion Matching *pose* a
skeleton to match a target. They are the **usable-now floor** (foot-IK +
procedural locomotion, Slice 3) and the **usable-now-upgrade rung** (Motion
Matching / Environment-aware MM / Learned MM, Slice 4 — deferred behind the
license-clean motion-set dependency, §3.4). This subsection records the
**aspirational CEILING above both**, and it does **not** change Slices 3–4: the
ceiling is **full-body physically-SIMULATED control, not kinematic playback.**
Balance, contact, momentum, and recovery **emerge** because a learned controller
must satisfy a physics simulation — the **physics-RL family** the lit review
enumerates (DeepMimic → AMP → DReCon → MaskedMimic;
`../research/animation-morphing-procgen-bodies.md` §A6), realized as a
**build-time-trained, deterministic-eval surrogate** over a **bit-deterministic
fixed-step physics solver** (the **same deterministic-surrogate shape** and the
**same physics-determinism caveat** the research doc already records — research
§A6, §Open questions; the fixed-step solver is itself the open dependency). This
is **R&D / open**, not a slice — it is the procgen-body/animation pillar's
animation ceiling (`procedural-body-and-animation.md` §D.1).

**Generalization is the crux, on two axes treated differently:**

- **Body PLAN** (humanoid, taur / 6-limb, nonhuman) — a small **DISCRETE** set
  of plan-specific controllers is acceptable; separate models per plan are fine.
- **Body BUILD** (chest size, weight / BMI, height, proportions — the
  **CONTINUOUS** morph axes, i.e. the `BodyState` macro/detail axes of §2.1) —
  must **NOT** explode into per-config models. The approach is a
  **morphology-CONDITIONED controller**: the policy takes the body's morph /
  build parameters as **INPUT** and generalizes across the continuous build
  manifold (trained with **morphology randomization**), so **one conditioned
  controller per plan covers the whole build space** rather than one model per
  body. "We shouldn't need a million approximators" is satisfied by **amortizing
  over the parameter space** — the build axes are an input to one controller,
  not a key into a table of controllers.

**The interlock with the body system (the elegant part).** The controller's
conditioning vector is the **SAME parametric morph vector this slice's body
system already exposes** — the **`BodyState` morph parameters** of §2.1 (the
`procedural-body-and-animation.md` §F one-shared-substrate principle). The
**parametric body and the parametric controller share ONE morphology
parameterization**: the body system hands the controller its conditioning
directly. The same `BodyState` vector that drives the blendshape weights (the
§2.1 `BodyState → weights` projection) drives the policy's body-awareness — no
separate adapter, no re-encoding. A parametric body is automatically a body the
conditioned controller can already drive.

**The open research gap + the next lever (honest).** The lit review
(`../research/animation-morphing-procgen-bodies.md`) covered MM / PFNN /
physics-RL but **NOT** the **morphology-GENERALIZING control** sub-area
specifically — body-agnostic / morphology-conditioned policies (graph- or
transformer-structured policies over morphology, "one policy to control them
all"-style controllers, morphology domain-randomization, metamorph-style
approaches). That is a **distinct, real research literature** and the **concrete
next research lever** for this ceiling; a **targeted follow-up lit review is
needed** (flagged; no paper citations invented here — the cited survey is a
future task; tracked in TODO.md). It remains a **PEER deterministic-surrogate
bet** alongside soft-body, language, expression, and the semantic layer — same
shape, same no-copouts posture (DESIGN.md, *aeriea is a research program*).

---

## 4. Incremental slice plan

Each slice is independently **xvfb-verifiable** (the project's standing CI
discipline: `xvfb-run godot4` boots a real window so GDScript parse + the full
pipeline runs — `flake.nix` note; `movement-substrate.md` §6). Do not start a
slice until the prior slice verifies headlessly.

**Slice 1 — nix-reproducible MakeHuman → Godot base body with a few morph axes
(incl. age) as working blendshapes, shown in-engine.**
Build the §1 derivation: pinned MakeHuman CC0 fetch (§1.3) → converter → a Godot
`ArrayMesh` with the base mesh + a starter set of macro blendshapes
(**gender, age, muscle, weight, height** at minimum — age is non-negotiable, it
feeds §2). Show the body in a scene; expose a debug slider per axis driving the
blendshape weights live.
*Verify:* `nix build` produces the asset from the pinned input with **no manual
step**; the body renders under xvfb; each axis slider visibly morphs the mesh
(screenshot the age axis sweeping baby→old as the proof the morph stack works).
*Risks/open deps:* the converter's quad-triangulation + sparse-delta scatter must
be deterministic (test: rebuild → identical bytes); the GDScript-vs-Python
converter-language choice (§1.4 — default GDScript, no flake change). Headless-
Blender viability is **not** a risk here because we don't use it.

**Slice 2 — morph stack driven by `BodyState` params + the age→NSFW-gate hook.**
Introduce the `BodyState` record (§2.1) as serializable sim data; drive the
Slice-1 blendshapes from it via the pure `BodyState → weights` projection. Derive
the **`adult_body_state`** predicate from `BodyState.age` (§2.2) and **wire the
Layer-1 gate hook**: a body-state guard primitive in the affordance kit that
NSFW/intimate verbs will guard on (the guard exists and is exercised by a test
verb even before real NSFW content is authored — the gate precedes the content).
*Verify:* setting `BodyState` morphs the body deterministically (golden-style:
same `BodyState` → same mesh); a test "adult-only" verb is **available** at
adult `age` and **absent** at child-range `age`, proving the intersection gate
fires from body-state, non-toggle. The age morph axis remains fully continuous
(no crippling — assert the child morph still renders for ordinary use).
*Risks/open deps:* keeping the morph space continuous while the gate reads a
threshold (the gate is a guard *over* the smooth axis, not a notch cut into it —
§2.2).

**Slice 3 — analytic foot-IK + procedural locomotion on the movement sim (the
player has a visible, animated body).**
Skin the §1 mesh to the `.mhskel`-derived `Skeleton3D` (the deferred §1.5
skin-weight import lands here), attach it to `interpreted_player.gd`, and drive
the pose from `MovementState` via the §3 layer: pose-curve blends by speed/state
+ analytic two-bone foot-IK on the ground/slope. **GDScript** (§3.3).
*Verify:* under xvfb, the body animates coherently while running/sliding/
wall-running the existing movement test level (feet plant, no skate, lean on
accel); the **movement behavioral suite + golden traces still pass unchanged**
(animation is render-side, excluded from the sim hash — `movement-substrate.md`
§6; this is the regression guard that the pose layer didn't leak into the sim).
*Risks/open deps:* skin-weight import fidelity (the one fiddly part of §1, now
due); the body-origin-at-feet VR seam (`units-and-scale.md`) becomes relevant
once a real skeleton is attached — note it, don't necessarily solve it here.

**Slice 4 (LANDED 2026-06-04, 100STYLE) — Motion Matching, on the now-resolved
license-clean nix-reproducible motion set (§3.4).**
The procedural pose layer is *augmented* by Motion Matching (research §A1),
reading the same `MovementState`, writing the same pose — a fidelity upgrade
behind the same Slice-3 seam. Implementation:

- **Reproducible fetch + ingest:** `nix/motion-assets.nix` fetches the pinned
  100STYLE archive (§3.4), curates the locomotion subset, and runs
  `tools/motion_ingest.gd` headless: BVH parse → retarget onto the 163-bone
  MakeHuman rig → per-frame MM feature DB. Output: the committed, compact (~2.9 MB),
  byte-deterministic `assets/body/locomotion_mm.res` (`MotionDB` resource;
  `scripts/body/motion_db.gd`) — runtime/end-users need neither the raw dataset
  nor nix. A trimmed CC BY excerpt (`vendor/100style-cc-by/`, 4 Neutral clips)
  enables fetch-free dev regen, mirroring the vendored MakeHuman CC0 subset.
- **Deterministic runtime search:** `scripts/body/motion_matcher.gd` —
  per-N-ticks argmin over the feature DB for the frame best matching the
  `MovementState`-derived goal (desired local-frame velocity + turn rate), with a
  fixed float path and lowest-index tie-break. No stochastic / online inference;
  fits seed+action-log. `scripts/body/body_rig.gd` drives the pose from the
  matched frames at the same seam; absent DB ⇒ graceful degradation to the
  Slice-3 procedural cycle.

*Verified:* MM DB built **nix-reproducibly** from the pinned 100STYLE (fresh
rebuilds byte-identical to committed); search deterministic (same query → same
frame, repeat + cross-matcher identical); goal-responsive (idle/walk/run/turn
select distinct, appropriate frames — idle→idle, run faster than walk, turn
matches a more-turning frame); movement behavioral suite + golden traces
**unchanged / green** (MM is render-side, excluded from the sim hash);
`body_motion_matching_test` (21 asserts) wired into `tests/run.sh`; screenshots
under xvfb show upright, gait-distinct matched locomotion.

*HONEST scope (what's partial / deferred):*
- **CMU is deferred** (binary-FBX, no Godot runtime parser — §3.4). 100STYLE
  alone is fully shipped; the ingest seam is BVH-agnostic so CMU drops in later.
- **Retargeting quality:** the legs/torso read as plausible upright locomotion
  (the load-bearing gait), distinct per goal. Cosmetic artifacts remain — arms
  splay (BVH A-pose vs MakeHuman arm-rest mismatch; the per-clip frame-0 used as
  the retarget rest is not always a clean neutral) and a slight head/neck offset.
  These are retargeting-fidelity refinements (use the BVH HIERARCHY T-pose as the
  rest instead of frame 0; per-bone twist correction), not blockers.
- **Foot-IK over MM:** the Slice-3 two-bone solver + pelvis-drop were tuned for
  the procedural cycle and *fight* the MM pose; under MM, foot-IK is skipped (MM
  ground contact comes from the captured clips). Re-deriving foot-IK as a gentle
  additive ground-adaptation layer that respects the MM pose is the refinement.
- **Direction sign / weight tuning:** straight-forward goals can match a *back*
  clip (the retargeted facing frame has forward = −z; reconciling that with the
  facing-vs-trajectory weight balance is a tuning pass best done against on-screen
  motion). The search is already deterministic and speed/idle/turn responsive.

*In-tier upgrades (future):* Environment-aware MM (§A8), Learned MM (§A2,
neural-but-deterministic); move the per-frame search to gdext if profiling shows
GDScript is the bottleneck (§3.3).

### Risks (summary)

- **Converter determinism** (Slice 1): the text→`ArrayMesh` transform must be
  byte-deterministic and pinned, or the "nix-reproducible" claim is hollow. Test
  by rebuild-and-compare.
- **Keeping the morph space continuous under the gate** (Slice 2): the gate is a
  guard over the intersection, never a discontinuity carved into the age axis or
  the NSFW systems (DESIGN.md, *Age × NSFW* — gate the configuration, not the
  primitives).
- **Skin-weight import fidelity** (Slice 3): the deferred-from-§1 fiddly part;
  bad weights = bad deformation under the existing morph envelope.
- **Animation leaking into the sim** (Slice 3): the pose layer is render-side and
  must not feed back; the unchanged golden traces are the guard.
- **Motion-data dependency** (Slice 4): commercial licensing **and**
  nix-reproducibility **and** cross-platform deterministic search — the explicit
  open dependency that gates MM (§3.4). Flagged, not hand-waved.
- **Headless-Blender-in-nix** is **not** a project risk under the chosen route
  (§1.1) — we parse text directly; Blender/MPFB is only a documented fallback.

---

## Two-tier + no-copouts (carried)

**Usable-now floor, not a copout:** a real, morphable, animated, real-scale body
(MakeHuman CC0 + blendshape stack + LBS + foot-IK + procedural locomotion) on the
proven movement/affordance substrates, with the NSFW gate wired from the first
body-state slice. The aspirational tiers — generative bodies as a build-time
oracle, Motion Matching / Learned MM as the kinematic upgrade rung and
**full-body physics-simulated, morphology-conditioned control** as the animation
ceiling above it (§3.5; `procedural-body-and-animation.md` §D.1),
topology-changing metamorphosis, soft-body — stay exactly where
`procedural-body-and-animation.md`, `future-directions.md`, and the research doc
place them, in the aspirational tier, degrading gracefully to this floor. The forbidden copouts (scope reduction,
stylization-as-escape, redefining a hard requirement away) are not taken: the
body is real-scale and real-topology, the gate is the exact body-state
intersection, and the motion-data dependency is named, not wished away.

## Open threads (explicitly unresolved)

- ~~**Motion dataset sourcing + commercial licensing + nix-reproducibility**~~ —
  **RESOLVED 2026-06-04** (§3.4): 100STYLE (CC BY 4.0) shipped; CMU (liberal
  license) pinned but ingest-deferred (binary FBX). Remaining sub-threads:
  CMU BVH ingest; retargeting-fidelity polish (arm/head, frame-0-rest →
  T-pose-rest); foot-IK-over-MM as an additive layer; the forward/back sign +
  facing/trajectory weight tuning. All Slice-4 refinements, not gating.
- **Morphology-conditioned control lit review** — the morphology-generalizing
  control sub-area (§3.5; `procedural-body-and-animation.md` §D.1) is the next
  research lever for the physics-sim ceiling and was **not** covered by the
  existing lit review; a targeted follow-up review is needed (TODO.md). This is
  R&D, above the slice plan — it does not gate Slices 1–4.
- **Skin-weight import** from the MakeHuman rig (§1.5, due in Slice 3).
- **Converter language** — GDScript (no flake change, default) vs Python/Rust
  (§1.4); a Slice-1 implementation choice.
- **Body-origin-at-feet for VR** — the `units-and-scale.md` open seam becomes
  live once a real skeleton is attached (Slice 3).
- **The within-form morph envelope's full axis set** — Slice 1 ships the macro
  axes; the detail axes (breast/buttocks/genitals/proportions/etc.) and the
  pinch-free-envelope spec (procedural-body-and-animation.md §B) grow on the same
  one-topology mesh in later passes.
- **glTF vs `.tres` ArrayMesh** as the converter's output format (§1.1 step 4) —
  a Slice-1 implementation detail.
- **Promoting the MakeHuman pin to a flake input** vs in-derivation
  `fetchFromGitHub` (§1.4) — left as in-derivation for now to keep `flake.lock`
  untouched; a clean follow-up.
